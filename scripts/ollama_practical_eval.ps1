# AgentOS Ollama practical model evaluation runner.
# Runs installed Ollama models on real AgentOS workflow tasks and records raw outputs.

param(
    [string]$AgentOSRoot = "E:\AgentOS",
    [string]$OutputDir = "",
    [int]$TimeoutSec = 180,
    [int]$NumPredict = 450,
    [string[]]$ModelFilter = @(),
    [switch]$DisableThinking
)

$ErrorActionPreference = "Stop"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Utf8NoBom([string]$Path, [string]$Value) {
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Value, $Utf8NoBom)
}

function New-SafeName([string]$Text) {
    return ([regex]::Replace($Text, '[^A-Za-z0-9_.-]+', '_')).Trim('_')
}

function Invoke-OllamaGenerate([string]$Model, [string]$Prompt, [int]$TimeoutSec, [int]$NumPredict, [bool]$DisableThinking) {
    $payload = @{
        model = $Model
        prompt = $Prompt
        stream = $false
        options = @{
            temperature = 0.1
            num_predict = $NumPredict
            num_ctx = 4096
        }
    }
    if ($DisableThinking) {
        $payload["think"] = $false
    }
    $body = $payload | ConvertTo-Json -Depth 8

    $started = Get-Date
    try {
        $response = Invoke-RestMethod `
            -Uri "http://localhost:11434/api/generate" `
            -Method Post `
            -ContentType "application/json; charset=utf-8" `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) `
            -TimeoutSec $TimeoutSec
        $finished = Get-Date
        return [ordered]@{
            ok = $true
            error = ""
            started_at = $started.ToString("o")
            finished_at = $finished.ToString("o")
            elapsed_seconds = [math]::Round(($finished - $started).TotalSeconds, 2)
            response = [string]$response.response
            raw = ($response | ConvertTo-Json -Depth 12)
        }
    } catch {
        $finished = Get-Date
        return [ordered]@{
            ok = $false
            error = $_.Exception.Message
            started_at = $started.ToString("o")
            finished_at = $finished.ToString("o")
            elapsed_seconds = [math]::Round(($finished - $started).TotalSeconds, 2)
            response = ""
            raw = ""
        }
    }
}

if (-not $OutputDir) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $OutputDir = Join-Path $AgentOSRoot "data\ollama_eval\$stamp"
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$tags = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 10
$models = @($tags.models | ForEach-Object { $_.name })
if (-not $models -or $models.Count -eq 0) {
    throw "No Ollama models found via http://localhost:11434/api/tags"
}
if ($ModelFilter -and $ModelFilter.Count -gt 0) {
    $wanted = @{}
    foreach ($m in $ModelFilter) { $wanted[$m] = $true }
    $models = @($models | Where-Object { $wanted.ContainsKey($_) })
    if (-not $models -or $models.Count -eq 0) {
        throw "No Ollama models matched ModelFilter: $($ModelFilter -join ', ')"
    }
}

$inventory = $tags | ConvertTo-Json -Depth 12
Write-Utf8NoBom (Join-Path $OutputDir "MODEL_INVENTORY.json") $inventory

$tasks = @(
    [ordered]@{
        id = "01_route_intake"
        title = "Route Josh message into AgentOS action"
        prompt = @'
You are an AgentOS cheap router. Return ONLY compact JSON, no markdown.

Classify this Telegram message:
"可以，把這個 Threads 網址丟給 Codex 先建立工單，不要讀網址內容，等我核准再外部讀取。https://www.threads.com/@demo/post/abc"

Required JSON keys:
intent_type, route_to, needs_josh_approval, external_access_allowed, next_action, confidence

Rules:
- If it asks to create a local work order only, external_access_allowed=false.
- If URL content must be read, needs_josh_approval=true.
- route_to must be one of Hermes, Codex, Claude, Ollama.
'@
    },
    [ordered]@{
        id = "02_url_intake_result"
        title = "Produce URL intake RESULT.md fields"
        prompt = @'
You are processing an AgentOS URL_INTAKE task. Do not fetch the URL.

URL:
https://www.threads.com/@laxima.tech/post/DaAZHSGFCk_

Raw Josh message:
https://www.threads.com/@laxima.tech/post/DaAZHSGFCk_

Return a RESULT.md style answer with these exact fields:
codex_execution_status: completed
source_not_verified: true
external_access_required: true|false
josh_approval_required: true|false
recommended_next_action: ...
claude_review_needed: true|false
risk_level: low|medium|high

Then add short sections: Classification, Boundary.
'@
    },
    [ordered]@{
        id = "03_report_audit"
        title = "Detect overclaim in Hermes report"
        prompt = @'
You are an AgentOS evidence auditor. Read this report and find overclaims.

Report:
"NotebookLM remote sync is verified and production ready. I uploaded all files successfully. Evidence path: not_applicable. verification_commands: none. cleanup_executed=false."

Return:
1. verdict: pass/fail
2. overclaims: bullet list
3. corrected_status_labels: key=value lines
4. one sentence recommendation

Be strict. Do not invent evidence.
'@
    },
    [ordered]@{
        id = "04_telegram_format"
        title = "Format noisy update for Telegram copy-paste"
        prompt = @'
Rewrite this into a concise Telegram-safe status update. No table. No nested code blocks. Use key=value lines where possible.

Messy input:
"Great news!!! We totally completed the thing, probably. Codex maybe ran? Claude looked at stuff. There might be dirty files but it's basically production ready 🚀🚀. Also external URL may or may not have been read."

Required:
- Must distinguish claimed vs verified.
- Must include production_ready=false unless evidence proves otherwise.
- Must say external_url_read=false.
'@
    },
    [ordered]@{
        id = "05_script_patch_plan"
        title = "Simple script patch reasoning"
        prompt = @'
You are reviewing this PowerShell pseudo-code:

$result = Invoke-Thing
Write-Output "status=success"

Problem: Invoke-Thing may fail but the script still prints success if errors are non-terminating.

Return a minimal patch plan in 5 bullets or fewer. Include exact PowerShell concepts to use. Do not write a full script.
'@
    }
)

$summaryRows = New-Object System.Collections.Generic.List[object]

foreach ($model in $models) {
    $modelDir = Join-Path $OutputDir (New-SafeName $model)
    New-Item -ItemType Directory -Force -Path $modelDir | Out-Null
    foreach ($task in $tasks) {
        $taskId = $task.id
        $promptPath = Join-Path $modelDir "$taskId.prompt.txt"
        $responsePath = Join-Path $modelDir "$taskId.response.md"
        $metaPath = Join-Path $modelDir "$taskId.meta.json"
        Write-Utf8NoBom $promptPath $task.prompt
        $result = Invoke-OllamaGenerate -Model $model -Prompt $task.prompt -TimeoutSec $TimeoutSec -NumPredict $NumPredict -DisableThinking ([bool]$DisableThinking)
        Write-Utf8NoBom $responsePath $result.response
        Write-Utf8NoBom $metaPath ($result | ConvertTo-Json -Depth 8)
        $summaryRows.Add([ordered]@{
            model = $model
            task_id = $taskId
            ok = $result.ok
            elapsed_seconds = $result.elapsed_seconds
            response_chars = $result.response.Length
            error = $result.error
            response_path = $responsePath
        })
        Write-Output ("model={0} task={1} ok={2} elapsed={3}s" -f $model, $taskId, $result.ok, $result.elapsed_seconds)
    }
}

$summaryJson = $summaryRows | ConvertTo-Json -Depth 8
Write-Utf8NoBom (Join-Path $OutputDir "RUN_SUMMARY.json") $summaryJson

$readme = @"
# Ollama Practical Evaluation Run

created_at: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz")
output_dir: $OutputDir
models_tested: $($models -join ", ")
tasks_per_model: $($tasks.Count)
timeout_sec: $TimeoutSec
num_predict: $NumPredict
disable_thinking: $([bool]$DisableThinking)

This run records raw prompts, raw model responses, and per-call metadata.
"@
Write-Utf8NoBom (Join-Path $OutputDir "README.md") $readme

Write-Output "output_dir=$OutputDir"
Write-Output "models_tested=$($models.Count)"
Write-Output "tasks_per_model=$($tasks.Count)"

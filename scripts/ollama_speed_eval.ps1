# AgentOS Ollama speed evaluation runner.
# Measures practical latency/throughput on simple AgentOS-style worker tasks.

param(
    [string]$AgentOSRoot = "E:\AgentOS",
    [string]$OutputDir = "",
    [int]$TimeoutSec = 180,
    [int]$NumPredict = 350,
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
        $evalSeconds = 0
        if ($response.eval_duration -and $response.eval_duration -gt 0) {
            $evalSeconds = [double]$response.eval_duration / 1000000000.0
        }
        $tokensPerSecond = 0
        if ($evalSeconds -gt 0 -and $response.eval_count) {
            $tokensPerSecond = [math]::Round(([double]$response.eval_count / $evalSeconds), 2)
        }
        return [ordered]@{
            ok = $true
            error = ""
            started_at = $started.ToString("o")
            finished_at = $finished.ToString("o")
            wall_seconds = [math]::Round(($finished - $started).TotalSeconds, 2)
            load_seconds = if ($response.load_duration) { [math]::Round(([double]$response.load_duration / 1000000000.0), 2) } else { 0 }
            prompt_eval_count = [int]$response.prompt_eval_count
            prompt_eval_seconds = if ($response.prompt_eval_duration) { [math]::Round(([double]$response.prompt_eval_duration / 1000000000.0), 2) } else { 0 }
            eval_count = [int]$response.eval_count
            eval_seconds = [math]::Round($evalSeconds, 2)
            tokens_per_second = $tokensPerSecond
            response_chars = ([string]$response.response).Length
            response = [string]$response.response
            done_reason = [string]$response.done_reason
            raw = ($response | ConvertTo-Json -Depth 12)
        }
    } catch {
        $finished = Get-Date
        return [ordered]@{
            ok = $false
            error = $_.Exception.Message
            started_at = $started.ToString("o")
            finished_at = $finished.ToString("o")
            wall_seconds = [math]::Round(($finished - $started).TotalSeconds, 2)
            load_seconds = 0
            prompt_eval_count = 0
            prompt_eval_seconds = 0
            eval_count = 0
            eval_seconds = 0
            tokens_per_second = 0
            response_chars = 0
            response = ""
            done_reason = ""
            raw = ""
        }
    }
}

if (-not $OutputDir) {
    $OutputDir = Join-Path $AgentOSRoot ("data\ollama_eval\speed-{0}" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$tags = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 10
$models = @($tags.models | ForEach-Object { $_.name })
if (-not $models -or $models.Count -eq 0) {
    throw "No Ollama models found via local API."
}

Write-Utf8NoBom (Join-Path $OutputDir "MODEL_INVENTORY.json") ($tags | ConvertTo-Json -Depth 12)

$tasks = @(
    [ordered]@{
        id = "01_tiny_format"
        label = "Tiny format"
        prompt = "Convert to key=value only, no markdown: task done, verified by codex false, production ready false, external url read false."
    },
    [ordered]@{
        id = "02_url_classify"
        label = "URL classify"
        prompt = "Classify this URL intake in compact JSON only: https://www.threads.com/@demo/post/abc . Keys: domain, task_type, external_access_required, josh_approval_required, route_to."
    },
    [ordered]@{
        id = "03_task_draft"
        label = "Task draft"
        prompt = @'
Create a short AgentOS TASK.md draft for this work:
Goal: normalize 5 messy Telegram reports into key=value status.
Constraints: no external access, no cleanup, no customer messages.
Output: RESULT.md.
Keep it under 180 words.
'@
    },
    [ordered]@{
        id = "04_long_organize"
        label = "Long text organize"
        prompt = @'
Condense these notes into 8 bullets and preserve caveats:
Hermes Lite receives Telegram messages. Typed dispatch should avoid Gemini. URL intake should create a routing artifact, create a Codex task packet, then Codex worker writes RESULT.md. External URL reading still requires Josh approval. Ollama models are cheap but not final authority. Qwen thinking models require think=false. Claude is reviewer. Codex is executor. Cursor owns PROJECT_ANALYSIS.md and RECOMMENDATIONS.md. Do not edit Cursor-owned files. Evidence must be written to disk. Do not overclaim production ready.
'@
    },
    [ordered]@{
        id = "05_batch_items"
        label = "Batch classify"
        prompt = @'
Classify each item as format, draft, audit, risky, or skip. Return one line per item.
1. Turn messy report into key=value.
2. Decide whether to delete old evidence folders.
3. Draft TASK.md from fixed template.
4. Detect unsupported production_ready=true.
5. Send customer a proposal.
6. Summarize 20 pasted notes.
7. Decide whether to read an external URL.
8. Convert list into Markdown bullets.
9. Patch PowerShell error handling.
10. Approve API spending.
'@
    }
)

$rows = New-Object System.Collections.Generic.List[object]

foreach ($model in $models) {
    $modelDir = Join-Path $OutputDir (New-SafeName $model)
    New-Item -ItemType Directory -Force -Path $modelDir | Out-Null
    foreach ($task in $tasks) {
        $promptPath = Join-Path $modelDir "$($task.id).prompt.txt"
        $responsePath = Join-Path $modelDir "$($task.id).response.md"
        $metaPath = Join-Path $modelDir "$($task.id).meta.json"
        Write-Utf8NoBom $promptPath $task.prompt
        $result = Invoke-OllamaGenerate -Model $model -Prompt $task.prompt -TimeoutSec $TimeoutSec -NumPredict $NumPredict -DisableThinking ([bool]$DisableThinking)
        Write-Utf8NoBom $responsePath $result.response
        Write-Utf8NoBom $metaPath ($result | ConvertTo-Json -Depth 8)
        $rows.Add([ordered]@{
            model = $model
            task_id = $task.id
            label = $task.label
            ok = $result.ok
            wall_seconds = $result.wall_seconds
            load_seconds = $result.load_seconds
            eval_count = $result.eval_count
            eval_seconds = $result.eval_seconds
            tokens_per_second = $result.tokens_per_second
            response_chars = $result.response_chars
            done_reason = $result.done_reason
            error = $result.error
            response_path = $responsePath
        })
        Write-Output ("model={0} task={1} ok={2} wall={3}s tps={4}" -f $model, $task.id, $result.ok, $result.wall_seconds, $result.tokens_per_second)
    }
}

Write-Utf8NoBom (Join-Path $OutputDir "SPEED_RESULTS.json") ($rows | ConvertTo-Json -Depth 8)

$readme = @"
# Ollama Speed Evaluation

created_at: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz")
disable_thinking: $([bool]$DisableThinking)
num_predict: $NumPredict
timeout_sec: $TimeoutSec
models_tested: $($models -join ", ")
tasks_per_model: $($tasks.Count)
"@
Write-Utf8NoBom (Join-Path $OutputDir "README.md") $readme

Write-Output "output_dir=$OutputDir"
Write-Output "models_tested=$($models.Count)"
Write-Output "tasks_per_model=$($tasks.Count)"

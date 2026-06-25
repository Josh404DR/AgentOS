# AgentOS URL intake Codex worker
# Consumes a URL intake TASK.md and asks Codex CLI to produce RESULT.md.
# The Codex task is intentionally local-only: no URL fetching, browsing,
# scraping, authentication, submissions, cleanup, or external services.

param(
    [Parameter(Mandatory = $true)]
    [string]$TaskPath,

    [string]$AgentOSRoot = "E:\AgentOS",

    [int]$TimeoutSeconds = 180
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

function Get-TaskField([string]$Content, [string]$FieldName) {
    $pattern = "(?m)^" + [regex]::Escape($FieldName) + ":\s*(.*)$"
    $match = [regex]::Match($Content, $pattern)
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return ""
}

function Get-Section([string]$Content, [string]$Header) {
    $pattern = "(?ms)^##\s+" + [regex]::Escape($Header) + "\s*\r?\n(.*?)(?=^##\s+|\z)"
    $match = [regex]::Match($Content, $pattern)
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return ""
}

function Quote-ProcessArg([string]$Arg) {
    if ($null -eq $Arg) { return '""' }
    return '"' + ($Arg -replace '\\', '\\' -replace '"', '\"') + '"'
}

if (-not (Test-Path -LiteralPath $TaskPath)) {
    throw "TaskPath not found: $TaskPath"
}

$taskFullPath = (Resolve-Path -LiteralPath $TaskPath).Path
if (-not $taskFullPath.StartsWith((Resolve-Path -LiteralPath $AgentOSRoot).Path, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "TaskPath must be inside AgentOSRoot: $taskFullPath"
}

$taskContent = Get-Content -Raw -LiteralPath $taskFullPath
$dispatchId = Get-TaskField $taskContent "dispatch_id"
if (-not $dispatchId) { $dispatchId = "unknown" }

$taskDir = Split-Path -Parent $taskFullPath
$outputsDir = Join-Path $taskDir "OUTPUTS"
$resultPath = Join-Path $outputsDir "RESULT.md"
$statusPath = Join-Path $outputsDir "WORKER_STATUS.md"
$consolePath = Join-Path $outputsDir "CODEX_CONSOLE.log"
$promptPath = Join-Path $outputsDir "CODEX_PROMPT.md"

$urls = Get-Section $taskContent "URL(s)"
$rawMessage = Get-Section $taskContent "Raw Telegram Message"
$createdAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"

Write-Utf8NoBom $statusPath @"
# URL Intake Worker Status

dispatch_id: $dispatchId
started_at: $createdAt
codex_execution_status: processing
source_not_verified: true
models_invoked: codex_cli
external_services_invoked: false
live_external_action_executed: false
task_path: $taskFullPath
result_path: $resultPath
"@

$codexPrompt = @"
You are Codex acting as AgentOS URL Intake Worker.

Read this local task content and produce the final RESULT.md content only.

Hard boundaries:
- Do not fetch, browse, scrape, open, summarize, or authenticate against the URL.
- Do not use network or external services.
- Do not modify files yourself; the worker script writes your final answer to RESULT.md.
- Use only the URL string and raw Telegram message.
- Keep the answer concise and evidence-based.

Required output format:

# URL Intake Codex Result

dispatch_id: $dispatchId
codex_execution_status: completed
source_not_verified: true
external_access_required: true|false
josh_approval_required: true|false
recommended_next_action: ...
claude_review_needed: true|false
risk_level: low|medium|high
models_invoked: codex_cli
external_services_invoked: false
live_external_action_executed: false

## Classification

- domain: ...
- apparent_source_type: ...
- likely_task_type: ...

## Reasoning

Briefly explain what can be inferred from the URL string only.

## Boundary

State clearly that the webpage content has not been read.

Local TASK.md content:

---
$taskContent
---
"@

Write-Utf8NoBom $promptPath $codexPrompt

$codex = Get-Command codex -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $codex) {
    Write-Utf8NoBom $statusPath @"
# URL Intake Worker Status

dispatch_id: $dispatchId
finished_at: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz")
codex_execution_status: blocked
blocked_reason: codex_cli_not_found
source_not_verified: true
models_invoked: false
external_services_invoked: false
live_external_action_executed: false
task_path: $taskFullPath
result_path: $resultPath
"@
    throw "codex CLI not found"
}

$psi = New-Object System.Diagnostics.ProcessStartInfo
$codexPath = $codex.Source
if (-not $codexPath) { $codexPath = $codex.Path }
if (-not $codexPath) { $codexPath = $codex.Definition }
if (-not $codexPath) { throw "codex CLI path not found" }

$psi.FileName = "cmd.exe"
$psi.WorkingDirectory = $AgentOSRoot
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
$psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
$null = $psi.EnvironmentVariables.Remove("OPENAI_API_KEY")
$null = $psi.EnvironmentVariables.Remove("CODEX_API_KEY")
$argsForCodex = @(
    "/d",
    "/c",
    "codex",
    "-a",
    "never",
    "exec",
    "-C",
    $AgentOSRoot,
    "--sandbox",
    "read-only",
    "--output-last-message",
    $resultPath,
    "-"
)
$psi.Arguments = ($argsForCodex | ForEach-Object { Quote-ProcessArg $_ }) -join " "

$proc = New-Object System.Diagnostics.Process
$proc.StartInfo = $psi
[void]$proc.Start()
$proc.StandardInput.Write($codexPrompt)
$proc.StandardInput.Close()

$stdoutTask = $proc.StandardOutput.ReadToEndAsync()
$stderrTask = $proc.StandardError.ReadToEndAsync()
if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
    try { $proc.Kill($true) } catch {}
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    Write-Utf8NoBom $consolePath (($stdout + "`n" + $stderr).Trim())
    Write-Utf8NoBom $statusPath @"
# URL Intake Worker Status

dispatch_id: $dispatchId
finished_at: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz")
codex_execution_status: blocked
blocked_reason: codex_timeout
source_not_verified: true
models_invoked: codex_cli
external_services_invoked: false
live_external_action_executed: false
task_path: $taskFullPath
result_path: $resultPath
"@
    throw "codex CLI timed out after $TimeoutSeconds seconds"
}

$stdout = $stdoutTask.GetAwaiter().GetResult()
$stderr = $stderrTask.GetAwaiter().GetResult()
Write-Utf8NoBom $consolePath (($stdout + "`n" + $stderr).Trim())

if ($proc.ExitCode -ne 0) {
    Write-Utf8NoBom $statusPath @"
# URL Intake Worker Status

dispatch_id: $dispatchId
finished_at: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz")
codex_execution_status: blocked
blocked_reason: codex_exit_$($proc.ExitCode)
source_not_verified: true
models_invoked: codex_cli
external_services_invoked: false
live_external_action_executed: false
task_path: $taskFullPath
result_path: $resultPath
console_path: $consolePath
"@
    throw "codex CLI failed with exit code $($proc.ExitCode)"
}

if (-not (Test-Path -LiteralPath $resultPath)) {
    Write-Utf8NoBom $statusPath @"
# URL Intake Worker Status

dispatch_id: $dispatchId
finished_at: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz")
codex_execution_status: blocked
blocked_reason: result_missing
source_not_verified: true
models_invoked: codex_cli
external_services_invoked: false
live_external_action_executed: false
task_path: $taskFullPath
result_path: $resultPath
"@
    throw "Codex did not create result: $resultPath"
}

$result = Get-Content -Raw -LiteralPath $resultPath
$required = @(
    "codex_execution_status: completed",
    "source_not_verified: true",
    "recommended_next_action:",
    "external_services_invoked: false",
    "live_external_action_executed: false"
)
foreach ($needle in $required) {
    if ($result -notmatch [regex]::Escape($needle)) {
        Write-Utf8NoBom $statusPath @"
# URL Intake Worker Status

dispatch_id: $dispatchId
finished_at: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz")
codex_execution_status: blocked
blocked_reason: result_missing_required_field
missing_field: $needle
source_not_verified: true
models_invoked: codex_cli
external_services_invoked: false
live_external_action_executed: false
task_path: $taskFullPath
result_path: $resultPath
"@
        throw "Codex result missing required field: $needle"
    }
}

Write-Utf8NoBom $statusPath @"
# URL Intake Worker Status

dispatch_id: $dispatchId
finished_at: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz")
codex_execution_status: completed
source_not_verified: true
models_invoked: codex_cli
external_services_invoked: false
live_external_action_executed: false
task_path: $taskFullPath
result_path: $resultPath
console_path: $consolePath
"@

Write-Output "codex_execution_status=completed"
Write-Output "dispatch_id=$dispatchId"
Write-Output "task_path=$taskFullPath"
Write-Output "result_path=$resultPath"
Write-Output "status_path=$statusPath"
Write-Output "source_not_verified=true"
Write-Output "models_invoked=codex_cli"
Write-Output "external_services_invoked=false"
Write-Output "live_external_action_executed=false"

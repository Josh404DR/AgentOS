[CmdletBinding()]
param([string]$AgentOSRoot = "E:\AgentOS")

$ErrorActionPreference = "Stop"
$worker = Join-Path $AgentOSRoot "scripts\local_file_task_worker.ps1"
$fake = Join-Path $AgentOSRoot "tests\fixtures\fake_dispatcher_resilience.ps1"
$suffix = "$PID-$(Get-Date -Format 'HHmmssfff')"
$dispatchId = "ci-hermes-root-failover-$suffix"
$taskDir = Join-Path $AgentOSRoot "data\codex_tasks\$dispatchId"
$failures = [Collections.Generic.List[string]]::new()

$output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $worker `
    -MessageText "Update one documentation line in docs\README.md." `
    -DispatchId $dispatchId -AgentOSRoot $AgentOSRoot `
    -RunQueueInline -QueueDispatcherPath $fake 2>&1
$exitCode = $LASTEXITCODE
$outputText = $output -join "`n"

if ($exitCode -ne 0) { $failures.Add("Hermes local worker exited $exitCode") }
if ($outputText -notmatch '(?m)^local_file_task_status=completed_locally$') {
    $failures.Add("local worker did not report completed_locally")
}
if ($outputText -notmatch '(?m)^queue_start_status=inline_completed$') {
    $failures.Add("inline resilient queue did not complete")
}

$taskPath = Join-Path $taskDir "TASK.md"
$resultPath = Join-Path $taskDir "OUTPUTS\RESULT.md"
$attemptPath = Join-Path $taskDir "OUTPUTS\DISPATCH_ATTEMPTS.jsonl"
if (-not (Test-Path -LiteralPath $taskPath -PathType Leaf)) {
    $failures.Add("root TASK.md was not created")
} else {
    $taskText = Get-Content -Raw -LiteralPath $taskPath -Encoding UTF8
    if ($taskText -notmatch '(?m)^route_to:\s*Codex\s*$') {
        $failures.Add("root task did not fall back from Claude to Codex")
    }
    if ($taskText -notmatch '(?m)^task_status:\s*completed\s*$') {
        $failures.Add("root task was not completed by the queue")
    }
}
if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf) -or
    (Get-Content -Raw -LiteralPath $resultPath -Encoding UTF8) -notmatch 'status:\s*completed') {
    $failures.Add("root result was not completed")
}
$attempts = if (Test-Path -LiteralPath $attemptPath -PathType Leaf) {
    @(Get-Content -LiteralPath $attemptPath -Encoding UTF8)
} else { @() }
if ($attempts.Count -ne 2) {
    $failures.Add("expected two bounded Claude attempts before fallback, got $($attempts.Count)")
}

if ($failures.Count) {
    $failures | ForEach-Object { Write-Error $_ }
    Write-Output $outputText
    exit 1
}

Write-Output "hermes_root_queue_e2e_status=passed"
Write-Output "root_task_processed_by_queue=true"
Write-Output "bounded_retry_then_fallback=true"
Write-Output "root_single_point_removed=true"
Write-Output "dispatch_id=$dispatchId"

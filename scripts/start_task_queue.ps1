[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RootDispatchId,
    [string]$AgentOSRoot = "E:\AgentOS",
    [switch]$ValidateOnly
)

$ErrorActionPreference = "Stop"
$Utf8NoBom = [Text.UTF8Encoding]::new($false)
$safeId = [regex]::Replace($RootDispatchId, '[^A-Za-z0-9_.-]+', '-').Trim('-')
$taskPath = Join-Path $AgentOSRoot (Join-Path "data\codex_tasks" (Join-Path $safeId "TASK.md"))
$runner = Join-Path $AgentOSRoot "scripts\task_queue_runner.ps1"
$stateDir = Join-Path $AgentOSRoot "data\queue_runs"
$statePath = Join-Path $stateDir "$safeId.json"
$stdoutPath = Join-Path $stateDir "$safeId.stdout.log"
$stderrPath = Join-Path $stateDir "$safeId.stderr.log"

if (-not (Test-Path -LiteralPath $taskPath -PathType Leaf)) {
    throw "Queue root TASK.md not found: $taskPath"
}
if (-not (Test-Path -LiteralPath $runner -PathType Leaf)) {
    throw "Queue runner not found: $runner"
}

New-Item -ItemType Directory -Force -Path $stateDir | Out-Null

if ($ValidateOnly) {
    Write-Output "queue_starter_validation=passed"
    Write-Output "queue_root_dispatch_id=$safeId"
    Write-Output "task_path=$taskPath"
    Write-Output "runner_path=$runner"
    exit 0
}

if (Test-Path -LiteralPath $statePath -PathType Leaf) {
    try {
        $existing = Get-Content -Raw -LiteralPath $statePath -Encoding UTF8 |
            ConvertFrom-Json
        $process = Get-Process -Id ([int]$existing.process_id) -ErrorAction SilentlyContinue
        $startedAt = try { [datetime]$existing.started_at } catch { [datetime]::MinValue }
        $isSameRun = $process -and
            $existing.status -eq "running" -and
            $process.ProcessName -eq "powershell" -and
            $process.StartTime -ge $startedAt.AddSeconds(-5)
        if ($isSameRun) {
            Write-Output "queue_start_status=already_running"
            Write-Output "queue_root_dispatch_id=$safeId"
            Write-Output "queue_process_id=$($process.Id)"
            Write-Output "queue_state_path=$statePath"
            exit 0
        }
    } catch {
        # A malformed or stale state file is retained and replaced by a new
        # current-state record. Evidence remains in the queue log files.
    }
}

$process = Start-Process `
    -FilePath "powershell.exe" `
    -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $runner,
        "-RootDispatchId", $safeId,
        "-AgentOSRoot", $AgentOSRoot
    ) `
    -WorkingDirectory $AgentOSRoot `
    -WindowStyle Hidden `
    -RedirectStandardOutput $stdoutPath `
    -RedirectStandardError $stderrPath `
    -PassThru

$state = [ordered]@{
    root_dispatch_id = $safeId
    process_id = $process.Id
    started_at = (Get-Date).ToString("o")
    status = "running"
    stdout_path = $stdoutPath
    stderr_path = $stderrPath
}
[IO.File]::WriteAllText(
    $statePath,
    ($state | ConvertTo-Json -Depth 5) + [Environment]::NewLine,
    $Utf8NoBom
)

Write-Output "queue_start_status=started"
Write-Output "queue_root_dispatch_id=$safeId"
Write-Output "queue_process_id=$($process.Id)"
Write-Output "queue_state_path=$statePath"
Write-Output "queue_stdout_path=$stdoutPath"
Write-Output "queue_stderr_path=$stderrPath"

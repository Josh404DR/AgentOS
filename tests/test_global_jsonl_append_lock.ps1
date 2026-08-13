[CmdletBinding()]
param([string]$AgentOSRoot = "E:\AgentOS")

$ErrorActionPreference = "Stop"
$helperPath = Join-Path $AgentOSRoot "scripts\lib\global_jsonl_lock.ps1"
$testRoot = Join-Path ([IO.Path]::GetTempPath()) "agentos-global-jsonl-lock-$PID-$([Guid]::NewGuid().ToString('N'))"
$targetPath = Join-Path $testRoot "FAULT_INJECTION.jsonl"
$workerPath = Join-Path $testRoot "append_worker.ps1"
$holderPath = Join-Path $testRoot "mutex_holder.ps1"
$processCount = 5
$writesPerProcess = 25
$utf8 = [Text.UTF8Encoding]::new($false)

New-Item -ItemType Directory -Path $testRoot -Force | Out-Null

$workerScript = @'
param($HelperPath, $TargetPath, $WorkerId, $WriteCount)
$ErrorActionPreference = "Stop"
. $HelperPath
$utf8 = [Text.UTF8Encoding]::new($false)
for ($sequence = 0; $sequence -lt [int]$WriteCount; $sequence++) {
    $line = ([ordered]@{
        worker_id = [int]$WorkerId
        sequence = $sequence
        payload = ("x" * 2048)
    } | ConvertTo-Json -Compress) + [Environment]::NewLine
    Invoke-GlobalJsonlLockedAppend -LiteralPath $TargetPath -PendingContent $line -AppendAction {
        [IO.File]::AppendAllText($TargetPath, $line, $utf8)
    }
}
'@
[IO.File]::WriteAllText($workerPath, $workerScript, $utf8)

$processes = @()
for ($workerId = 0; $workerId -lt $processCount; $workerId++) {
    $processes += Start-Process -FilePath "powershell.exe" -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$workerPath`"",
        "-HelperPath", "`"$helperPath`"",
        "-TargetPath", "`"$targetPath`"",
        "-WorkerId", $workerId,
        "-WriteCount", $writesPerProcess
    ) -WindowStyle Hidden -PassThru
}

$processes | Wait-Process -Timeout 60
$failedProcesses = @($processes | Where-Object { $_.ExitCode -ne 0 })
if ($failedProcesses.Count -gt 0) {
    throw "parallel append worker failure: exit_codes=$($failedProcesses.ExitCode -join ',')"
}

$lines = @(Get-Content -LiteralPath $targetPath -Encoding UTF8)
$expectedCount = $processCount * $writesPerProcess
if ($lines.Count -ne $expectedCount) {
    throw "line count mismatch: expected=$expectedCount actual=$($lines.Count)"
}

$parsedCount = 0
foreach ($line in $lines) {
    try {
        $null = $line | ConvertFrom-Json
        $parsedCount++
    } catch {
        throw "invalid JSON at line $($parsedCount + 1): $($_.Exception.Message)"
    }
}

$holderScript = @'
param($HelperPath, $TargetPath, $ReadyPath)
$ErrorActionPreference = "Stop"
. $HelperPath
$mutexName = Get-GlobalJsonlMutexName -LiteralPath $TargetPath
$mutex = [Threading.Mutex]::new($false, $mutexName)
$acquired = $mutex.WaitOne(5000)
if (-not $acquired) { throw "holder could not acquire mutex" }
[IO.File]::WriteAllText($ReadyPath, "ready")
try { Start-Sleep -Seconds 5 } finally { $mutex.ReleaseMutex(); $mutex.Dispose() }
'@
[IO.File]::WriteAllText($holderPath, $holderScript, $utf8)
$timeoutTarget = Join-Path $testRoot "LOCK_TIMEOUT.jsonl"
$readyPath = Join-Path $testRoot "holder.ready"
$holder = Start-Process -FilePath "powershell.exe" -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", "`"$holderPath`"",
    "-HelperPath", "`"$helperPath`"",
    "-TargetPath", "`"$timeoutTarget`"",
    "-ReadyPath", "`"$readyPath`""
) -WindowStyle Hidden -PassThru

$readyDeadline = [DateTime]::UtcNow.AddSeconds(10)
while (-not (Test-Path -LiteralPath $readyPath) -and [DateTime]::UtcNow -lt $readyDeadline) {
    Start-Sleep -Milliseconds 50
}
if (-not (Test-Path -LiteralPath $readyPath)) {
    throw "mutex holder did not signal readiness"
}

. $helperPath
$timeoutLine = '{"fault":"lock_timeout"}' + [Environment]::NewLine
$timeoutObserved = $false
try {
    Invoke-GlobalJsonlLockedAppend -LiteralPath $timeoutTarget -PendingContent $timeoutLine -TimeoutMilliseconds 100 -RetryCount 2 -RetryDelayMilliseconds 25 -AppendAction {
        [IO.File]::AppendAllText($timeoutTarget, $timeoutLine, $utf8)
    }
} catch {
    if ($_.Exception.Message -match "lock_timeout" -and $_.Exception.Message -match "pending_path=") {
        $timeoutObserved = $true
    } else {
        throw
    }
}
if (-not $timeoutObserved) {
    throw "lock timeout did not produce an explicit error"
}

$pendingFiles = @(Get-ChildItem -LiteralPath $testRoot -Filter "LOCK_TIMEOUT.jsonl.pending-*.jsonl")
if ($pendingFiles.Count -ne 1) {
    throw "expected one pending side queue file, got $($pendingFiles.Count)"
}
if (([IO.File]::ReadAllText($pendingFiles[0].FullName, $utf8)) -ne $timeoutLine) {
    throw "pending side queue content mismatch"
}
if (Test-Path -LiteralPath $timeoutTarget) {
    throw "timed-out append unexpectedly reached the target"
}

$holder | Wait-Process -Timeout 15
if ($holder.ExitCode -ne 0) {
    throw "mutex holder failed with exit code $($holder.ExitCode)"
}

Write-Output "global_jsonl_append_lock_status=passed"
Write-Output "parallel_processes=$processCount"
Write-Output "writes_per_process=$writesPerProcess"
Write-Output "expected_lines=$expectedCount"
Write-Output "actual_lines=$($lines.Count)"
Write-Output "json_lines_parsed=$parsedCount"
Write-Output "sharing_violations=0"
Write-Output "lock_timeout_observed=$timeoutObserved"
Write-Output "pending_side_queue_files=$($pendingFiles.Count)"

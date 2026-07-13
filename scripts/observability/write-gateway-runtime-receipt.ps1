[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ReceiptId,
    [Parameter(Mandatory=$true)][string]$RuntimeId,
    [Parameter(Mandatory=$true)][string]$ProfileLockPath,
    [string]$AgentOSRoot
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($AgentOSRoot)) {
    $AgentOSRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}
$root = (Resolve-Path -LiteralPath $AgentOSRoot).Path
$resolvedLockPath = [Environment]::ExpandEnvironmentVariables($ProfileLockPath)
if (-not (Test-Path -LiteralPath $resolvedLockPath -PathType Leaf)) {
    throw "Gateway profile lock not found: $resolvedLockPath"
}

$lock = [IO.File]::ReadAllText($resolvedLockPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
$lockPid = [int]$lock.pid
$native = Get-CimInstance Win32_Process -Filter "ProcessId=$lockPid" -ErrorAction Stop
if (-not $native -or [string]$native.CommandLine -notmatch 'gateway\s+run') {
    throw "Profile lock PID $lockPid is not a live Hermes gateway process."
}
$managed = Get-Process -Id $lockPid -ErrorAction Stop

# PID-reuse guard: recorded lock start_time must match the live process start
# time (15s tolerance). Command-line matching alone cannot distinguish a
# recycled PID or the other gateway profile.
$lockStartRaw = $lock.start_time
$lockStartUtc = $null
$epoch = 0.0
if ($null -ne $lockStartRaw -and "$lockStartRaw" -ne "") {
    if ([double]::TryParse("$lockStartRaw", [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$epoch)) {
        if ($epoch -ge 100000000000) {
            $lockStartUtc = [DateTimeOffset]::FromUnixTimeMilliseconds([long]$epoch).UtcDateTime
        } elseif ($epoch -gt 946684800) {
            $lockStartUtc = [DateTimeOffset]::FromUnixTimeMilliseconds([long]($epoch * 1000)).UtcDateTime
        }
    } else {
        try { $lockStartUtc = ([DateTimeOffset]::Parse("$lockStartRaw", [Globalization.CultureInfo]::InvariantCulture)).UtcDateTime } catch { $lockStartUtc = $null }
    }
}
if ($null -eq $lockStartUtc) {
    throw "Profile lock start_time missing or unparseable ('$lockStartRaw'); refusing receipt (possible stale/foreign lock)."
}
$startDriftSeconds = [math]::Round([math]::Abs(($managed.StartTime.ToUniversalTime() - $lockStartUtc).TotalSeconds), 1)
if ($startDriftSeconds -gt 15) {
    throw "Profile lock start_time drift ${startDriftSeconds}s exceeds 15s tolerance (possible PID reuse); refusing receipt."
}
$owner = Invoke-CimMethod -InputObject $native -MethodName GetOwner -ErrorAction SilentlyContinue
$identity = if ($owner -and $owner.ReturnValue -eq 0 -and $owner.User) {
    if ($owner.Domain) { "$($owner.Domain)\$($owner.User)" } else { [string]$owner.User }
} else {
    [Security.Principal.WindowsIdentity]::GetCurrent().Name
}

$receipt = [ordered]@{
    runtime_id = $RuntimeId
    status = "running"
    process_id = $lockPid
    executable_path = [string]$native.ExecutablePath
    command_match = "gateway run"
    started_at = $managed.StartTime.ToString("o")
    identity = $identity
    profile_lock_path = $resolvedLockPath
    lock_start_time = $lock.start_time
    start_time_drift_seconds = $startDriftSeconds
    receipt_source = "profile_lock"
    reconciled_at = (Get-Date).ToString("o")
}

$receiptDir = Join-Path $root "data\runtime_receipts"
New-Item -ItemType Directory -Force -Path $receiptDir | Out-Null
$receiptPath = Join-Path $receiptDir "$ReceiptId.json"
$tempPath = "$receiptPath.tmp-$PID"
[IO.File]::WriteAllText($tempPath, ($receipt | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
Move-Item -LiteralPath $tempPath -Destination $receiptPath -Force

Write-Output "runtime_receipt_status=PASS"
Write-Output "runtime_id=$RuntimeId"
Write-Output "process_id=$lockPid"
Write-Output "receipt_path=$receiptPath"

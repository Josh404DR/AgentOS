[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RuntimeId,
    [Parameter(Mandatory)][ValidateSet("start", "stop", "restart")][string]$Action,
    [string]$DispatchId,
    [string]$AgentOSRoot,
    [switch]$ValidateOnly
)
$ErrorActionPreference = "Stop"
if (-not $AgentOSRoot) { $AgentOSRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
$root = (Resolve-Path -LiteralPath $AgentOSRoot).Path
$registry = [IO.File]::ReadAllText((Join-Path $root "config\runtime_registry.json"), [Text.Encoding]::UTF8) | ConvertFrom-Json
$matches = @($registry.runtimes | Where-Object runtime_id -eq $RuntimeId)
if ($matches.Count -ne 1) { throw "Runtime must resolve exactly once: $RuntimeId" }
$runtime = $matches[0]
if (-not $runtime.control -or -not $runtime.control.enabled) { throw "Runtime control is disabled: $RuntimeId" }
$mode = [string]$runtime.control.mode

if ($ValidateOnly) {
    if ($mode -eq "scheduled_task" -and ([string]$runtime.start_source.ref -match '[*?]')) { throw "Scheduled control requires an exact task name." }
    if ($mode -eq "script" -and -not (Test-Path (Join-Path $root ([string]$runtime.start_source.script -replace '/', '\')))) { throw "Control script missing." }
    if ($mode -eq "process_receipt" -and -not $runtime.control.receipt_id) { throw "Process receipt control requires receipt_id." }
    if ($mode -notin @("scheduled_task", "process_receipt", "script", "queue")) { throw "Unsupported control mode: $mode" }
    "runtime_control_validation=PASS"; "runtime_id=$RuntimeId"; "mode=$mode"; exit 0
}

function Invoke-RegisteredScript([object[]]$Arguments) {
    $script = Join-Path $root ([string]$runtime.start_source.script -replace '/', '\')
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Registered script failed: exit $LASTEXITCODE" }
}

function Stop-QueueRun {
    if (-not $DispatchId) { throw "DispatchId is required for queue control." }
    $safeId = [regex]::Replace($DispatchId, '[^A-Za-z0-9_.-]+', '-').Trim('-')
    $statePath = Join-Path $root "data\queue_runs\$safeId.json"
    if (-not (Test-Path $statePath)) { throw "Queue state receipt missing: $statePath" }
    $state = [IO.File]::ReadAllText($statePath, [Text.Encoding]::UTF8) | ConvertFrom-Json
    $pidValue = [int]$state.process_id
    $native = Get-CimInstance Win32_Process -Filter "ProcessId=$pidValue" -ErrorAction Stop
    $managed = Get-Process -Id $pidValue -ErrorAction Stop
    $expected = (Join-Path $root "scripts\task_queue_runner.ps1").ToLowerInvariant()
    if ($native.Name -notlike "powershell*" -or $native.CommandLine.ToLowerInvariant() -notlike "*$expected*") { throw "Queue process identity mismatch." }
    if ([math]::Abs(($managed.StartTime - [datetime]$state.started_at).TotalSeconds) -gt 5) { throw "Queue process start time mismatch." }
    Stop-Process -Id $pidValue -ErrorAction Stop
}

function Stop-ReceiptProcess {
    $receiptPath = Join-Path $root "data\runtime_receipts\$($runtime.control.receipt_id).json"
    if (-not (Test-Path $receiptPath)) { throw "Runtime receipt missing: $receiptPath" }
    $receipt = [IO.File]::ReadAllText($receiptPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
    $pidValue = [int]$receipt.process_id
    $native = Get-CimInstance Win32_Process -Filter "ProcessId=$pidValue" -ErrorAction Stop
    $managed = Get-Process -Id $pidValue -ErrorAction Stop
    if ([IO.Path]::GetFullPath($native.ExecutablePath) -ne [IO.Path]::GetFullPath([string]$receipt.executable_path)) { throw "Runtime executable path mismatch." }
    if ($native.CommandLine -notmatch '(?i)gateway\s+run') { throw "Runtime command line mismatch." }
    if ([math]::Abs(($managed.StartTime - [datetime]$receipt.started_at).TotalSeconds) -gt 5) { throw "Runtime process start time mismatch." }
    Stop-Process -Id $pidValue -ErrorAction Stop
}

if ($mode -eq "scheduled_task") {
    $task = Get-ScheduledTask -TaskName ([string]$runtime.start_source.ref) -ErrorAction Stop
    if ($Action -in @("stop", "restart")) { Stop-ScheduledTask -InputObject $task -ErrorAction Stop }
    if ($Action -in @("start", "restart")) { Start-ScheduledTask -InputObject $task -ErrorAction Stop }
} elseif ($mode -eq "process_receipt") {
    if ($Action -in @("stop", "restart")) { Stop-ReceiptProcess }
    if ($Action -in @("start", "restart")) {
        $arguments = @($runtime.control.start_args)
        if ($runtime.control.pass_agentos_root) { $arguments += @("-AgentOSRoot", $root) }
        Invoke-RegisteredScript $arguments
    }
} elseif ($mode -eq "script") {
    if ($Action -in @("stop", "restart")) { Invoke-RegisteredScript @($runtime.control.stop_args) }
    if ($Action -in @("start", "restart")) { Invoke-RegisteredScript @($runtime.control.start_args) }
} elseif ($mode -eq "queue") {
    if ($Action -in @("stop", "restart")) { Stop-QueueRun }
    if ($Action -in @("start", "restart")) {
        if (-not $DispatchId) { throw "DispatchId is required for queue control." }
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "scripts\start_task_queue.ps1") -RootDispatchId $DispatchId -AgentOSRoot $root
        if ($LASTEXITCODE -ne 0) { throw "Queue starter failed: exit $LASTEXITCODE" }
    }
}
"runtime_control_status=PASS"; "runtime_id=$RuntimeId"; "action=$Action"

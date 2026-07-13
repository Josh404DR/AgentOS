[CmdletBinding()]
param([string]$AgentOSRoot = "E:\AgentOS")

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $AgentOSRoot).Path
$collector = Join-Path $root "scripts\observability\collect-runtime-status.ps1"
$receiptDir = Join-Path $root "data\runtime_receipts"
$targets = @(
    @{ RuntimeId = "hermes-main-gateway"; ReceiptId = "hermes-gateway"; LockPath = "$env:LOCALAPPDATA\hermes\gateway.lock" },
    @{ RuntimeId = "hermes-lite-gateway"; ReceiptId = "hermes-lite-gateway"; LockPath = "$env:LOCALAPPDATA\hermes-lite\gateway.lock" }
)

foreach ($target in $targets) {
    $lock = [IO.File]::ReadAllText($target.LockPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
    if (-not (Get-Process -Id ([int]$lock.pid) -ErrorAction SilentlyContinue)) {
        throw "$($target.RuntimeId) lock owner is not alive."
    }
    $stale = [ordered]@{
        runtime_id = $target.RuntimeId
        status = "running"
        process_id = 999999
        started_at = "2000-01-01T00:00:00Z"
        identity = "fixture"
    }
    [IO.File]::WriteAllText(
        (Join-Path $receiptDir "$($target.ReceiptId).json"),
        ($stale | ConvertTo-Json),
        [Text.UTF8Encoding]::new($false)
    )
}

& $collector -AgentOSRoot $root | Out-Null
$status = [IO.File]::ReadAllText((Join-Path $root "data\observability\runtime_status.json"), [Text.Encoding]::UTF8) | ConvertFrom-Json
foreach ($target in $targets) {
    $lock = [IO.File]::ReadAllText($target.LockPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
    $receipt = [IO.File]::ReadAllText((Join-Path $receiptDir "$($target.ReceiptId).json"), [Text.Encoding]::UTF8) | ConvertFrom-Json
    $runtime = @($status.runtimes | Where-Object runtime_id -eq $target.RuntimeId)
    if ($runtime.Count -ne 1 -or $runtime[0].state -ne "running") {
        throw "$($target.RuntimeId) was not reconciled to running."
    }
    if ([int]$receipt.process_id -ne [int]$lock.pid) {
        throw "$($target.RuntimeId) receipt PID does not match the profile lock owner."
    }
    Write-Output "PASS: $($target.RuntimeId) pid=$($lock.pid) state=$($runtime[0].state)"
}
Write-Output "runtime_receipt_reconciliation=PASS"

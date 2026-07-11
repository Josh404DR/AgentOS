[CmdletBinding()]
param([string]$AgentOSRoot)
$ErrorActionPreference = "Stop"
if (-not $AgentOSRoot) { $AgentOSRoot = Split-Path -Parent $PSScriptRoot }
$root = (Resolve-Path $AgentOSRoot).Path
$fixture = Join-Path ([IO.Path]::GetTempPath()) ("agentos-control-" + [Guid]::NewGuid().ToString("N"))
$unrelated = $null
try {
    New-Item -ItemType Directory -Force -Path (Join-Path $fixture "config"), (Join-Path $fixture "data\queue_runs"), (Join-Path $fixture "data\runtime_receipts"), (Join-Path $fixture "scripts\runtimes") | Out-Null
    Copy-Item (Join-Path $root "scripts\runtimes\control-runtime.ps1") (Join-Path $fixture "scripts\runtimes\control-runtime.ps1")
    $registry = @{ schema_version = "fixture"; runtimes = @(@{
        runtime_id = "task-queue-runner"; control = @{ enabled = $true; mode = "queue" }
        start_source = @{ script = "scripts/task_queue_runner.ps1" }
    }, @{
        runtime_id = "hermes-main-gateway"; control = @{ enabled = $true; mode = "process_receipt"; receipt_id = "hermes-gateway" }
        start_source = @{ script = "scripts/start.ps1" }
    }) } | ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText((Join-Path $fixture "config\runtime_registry.json"), $registry, [Text.UTF8Encoding]::new($false))
    $unrelated = Start-Process -FilePath powershell.exe -ArgumentList @("-NoProfile", "-Command", "Start-Sleep -Seconds 30") -PassThru -WindowStyle Hidden
    $receipt = @{ process_id = $unrelated.Id; started_at = $unrelated.StartTime.ToString("o") } | ConvertTo-Json
    [IO.File]::WriteAllText((Join-Path $fixture "data\queue_runs\fixture.json"), $receipt, [Text.UTF8Encoding]::new($false))
    $runtimeReceipt = @{ process_id = $unrelated.Id; started_at = $unrelated.StartTime.ToString("o"); executable_path = $unrelated.Path } | ConvertTo-Json
    [IO.File]::WriteAllText((Join-Path $fixture "data\runtime_receipts\hermes-gateway.json"), $runtimeReceipt, [Text.UTF8Encoding]::new($false))

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $controlOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fixture "scripts\runtimes\control-runtime.ps1") -RuntimeId task-queue-runner -Action stop -DispatchId fixture -AgentOSRoot $fixture 2>&1
    $controlExit = $LASTEXITCODE
    $ErrorActionPreference = $previousPreference
    if ($controlExit -eq 0) { throw "Mismatched process receipt was accepted: $($controlOutput -join ' ')" }
    if (-not (Get-Process -Id $unrelated.Id -ErrorAction SilentlyContinue)) { throw "Unrelated process was terminated." }
    $ErrorActionPreference = "Continue"
    $runtimeOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fixture "scripts\runtimes\control-runtime.ps1") -RuntimeId hermes-main-gateway -Action stop -AgentOSRoot $fixture 2>&1
    $runtimeExit = $LASTEXITCODE
    $ErrorActionPreference = $previousPreference
    if ($runtimeExit -eq 0) { throw "Mismatched runtime receipt was accepted: $($runtimeOutput -join ' ')" }
    if (-not (Get-Process -Id $unrelated.Id -ErrorAction SilentlyContinue)) { throw "Unrelated process was terminated by runtime receipt control." }
    Write-Output "runtime_control_safety=PASS"
    Write-Output "unrelated_process_preserved=true"
} finally {
    if ($unrelated -and (Get-Process -Id $unrelated.Id -ErrorAction SilentlyContinue)) { Stop-Process -Id $unrelated.Id -Force }
    if (Test-Path $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}

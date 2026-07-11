[CmdletBinding()]
param([string]$AgentOSRoot)
$ErrorActionPreference = "Stop"
if (-not $AgentOSRoot) { $AgentOSRoot = Split-Path -Parent $PSScriptRoot }
$root = (Resolve-Path $AgentOSRoot).Path
$fixture = Join-Path ([IO.Path]::GetTempPath()) ("agentos-dashboard-stop-" + [Guid]::NewGuid().ToString("N"))
$listenerProcess = $null
try {
    New-Item -ItemType Directory -Force -Path (Join-Path $fixture "dashboard"), (Join-Path $fixture "data\runtime_receipts") | Out-Null
    Copy-Item (Join-Path $root "dashboard\start.ps1") (Join-Path $fixture "dashboard\start.ps1")
    $listenerScript = Join-Path $fixture "listener.ps1"
    [IO.File]::WriteAllText($listenerScript, '$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 8000); $listener.Start(); try { Start-Sleep -Seconds 60 } finally { $listener.Stop() }', [Text.UTF8Encoding]::new($false))
    $listenerProcess = Start-Process -FilePath powershell.exe -ArgumentList @("-NoProfile", "-File", $listenerScript) -PassThru -WindowStyle Hidden
    $deadline = (Get-Date).AddSeconds(10)
    while ((Get-Date) -lt $deadline -and -not (netstat -ano | Select-String ':8000\s+.*LISTENING')) { Start-Sleep -Milliseconds 200 }
    if (-not (netstat -ano | Select-String ':8000\s+.*LISTENING')) { throw "Fixture listener did not bind port 8000." }
    $receipt = [ordered]@{
        runtime_id = "dashboard-backend"
        status = "running"
        process_id = $listenerProcess.Id
        executable_path = $listenerProcess.Path
        command_match = "listener.ps1"
        port = 8000
        started_at = $listenerProcess.StartTime.ToString("o")
        identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    }
    $receiptPath = Join-Path $fixture "data\runtime_receipts\dashboard-backend.json"
    [IO.File]::WriteAllText($receiptPath, ($receipt | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fixture "dashboard\start.ps1") -Stop -BackendOnly
    if ($LASTEXITCODE -ne 0) { throw "Receipt-bound Dashboard stop failed." }
    $listenerProcess.Refresh()
    if (-not $listenerProcess.HasExited) { throw "Registered listener process was not stopped." }
    if (netstat -ano | Select-String ':8000\s+.*LISTENING') { throw "Registered listener did not release port 8000." }
    $preserved = [IO.File]::ReadAllText($receiptPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
    if ($preserved.status -ne "stopped" -or -not $preserved.stopped_at) { throw "Stopped receipt evidence was not preserved." }
    "dashboard_stop_receipt=PASS"
    "registered_process_stopped=true"
    "port_released=true"
    "receipt_preserved=true"
} finally {
    if ($listenerProcess -and -not $listenerProcess.HasExited) { Stop-Process -Id $listenerProcess.Id -Force -ErrorAction SilentlyContinue }
    if (Test-Path $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}

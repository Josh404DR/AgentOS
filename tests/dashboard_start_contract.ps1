[CmdletBinding()]
param([string]$AgentOSRoot)
$ErrorActionPreference = "Stop"
if (-not $AgentOSRoot) { $AgentOSRoot = Split-Path -Parent $PSScriptRoot }
$root = (Resolve-Path $AgentOSRoot).Path
$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 8000)
try {
    $listener.Start()
    $previous = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "dashboard\start.ps1") -BackendOnly -NoBrowser 2>&1
    $exitCode = $LASTEXITCODE; $ErrorActionPreference = $previous
    if ($exitCode -eq 0) { throw "Dashboard start accepted an unhealthy process occupying port 8000: $($output -join ' ')" }
    if (-not $listener.Server.IsBound) { throw "Dashboard start disturbed the unrelated listener." }
    $ErrorActionPreference = "Continue"
    $stopOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "dashboard\start.ps1") -Stop -BackendOnly 2>&1
    $stopExit = $LASTEXITCODE; $ErrorActionPreference = $previous
    if ($stopExit -eq 0) { throw "Dashboard stop accepted an unrelated listener without a receipt: $($stopOutput -join ' ')" }
    if (-not $listener.Server.IsBound) { throw "Dashboard stop disturbed the unrelated listener." }
    "dashboard_start_contract=PASS"; "unhealthy_port_rejected=true"; "scheduled_exit_nonzero=true"; "unrelated_stop_rejected=true"
} finally {
    $listener.Stop()
}
exit 0

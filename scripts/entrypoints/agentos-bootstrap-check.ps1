[CmdletBinding()]
param([string]$AgentOSRoot)
$ErrorActionPreference = "Stop"
if (-not $AgentOSRoot) { $AgentOSRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
$root = (Resolve-Path $AgentOSRoot).Path
$checks = [ordered]@{
    git = [bool](Get-Command git.exe -ErrorAction SilentlyContinue)
    powershell = [bool](Get-Command powershell.exe -ErrorAction SilentlyContinue)
    python = [bool]((Get-Command py.exe -ErrorAction SilentlyContinue) -or (Get-Command python.exe -ErrorAction SilentlyContinue))
    node = [bool](Get-Command node.exe -ErrorAction SilentlyContinue)
    npm = [bool](Get-Command npm.cmd -ErrorAction SilentlyContinue)
    dashboard_backend_venv = Test-Path (Join-Path $root "dashboard\backend\.venv\Scripts\python.exe")
    dashboard_frontend_modules = Test-Path (Join-Path $root "dashboard\frontend\node_modules")
    local_env = Test-Path (Join-Path $root ".env")
}
foreach ($item in $checks.GetEnumerator()) { "bootstrap_$($item.Key)=$($item.Value.ToString().ToLowerInvariant())" }
$required = @("git", "powershell", "python", "node", "npm")
$missing = @($required | Where-Object { -not $checks[$_] })
if ($missing.Count) { "bootstrap_status=BLOCKED"; "missing_required=$($missing -join ',')"; exit 1 }
$localMissing = @($checks.GetEnumerator() | Where-Object { -not $_.Value -and $_.Key -notin $required } | ForEach-Object Key)
"bootstrap_status=PASS"; "setup_required=$($localMissing -join ',')"; "install_executed=false"

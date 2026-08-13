[CmdletBinding()]
param([string]$AgentOSRoot = "E:\AgentOS")

$ErrorActionPreference = 'Stop'
. (Join-Path $AgentOSRoot 'dashboard\dashboard_orphan_guard.ps1')
$backend = Join-Path $AgentOSRoot 'dashboard\backend\.venv\Scripts\python.exe'
$frontend = Join-Path $AgentOSRoot 'dashboard\frontend'
$validBackend = [pscustomobject]@{
    ExecutablePath = $backend
    CommandLine = "`"$backend`" -m uvicorn main:app --host 127.0.0.1 --port 8000"
}
$foreignBackend = [pscustomobject]@{
    ExecutablePath = 'C:\Python\python.exe'
    CommandLine = 'python -m uvicorn main:app --port 8000'
}
$validFrontend = [pscustomobject]@{
    ExecutablePath = 'C:\Program Files\nodejs\node.exe'
    CommandLine = "node `"$frontend\node_modules\next\dist\bin\next`" start"
}
$foreignFrontend = [pscustomobject]@{
    ExecutablePath = 'C:\Program Files\nodejs\node.exe'
    CommandLine = 'node C:\other\node_modules\next\dist\bin\next start'
}
if (-not (Test-DashboardWorkspaceProcess $validBackend backend $backend $frontend)) { throw 'valid backend rejected' }
if (Test-DashboardWorkspaceProcess $foreignBackend backend $backend $frontend) { throw 'foreign backend accepted' }
if (-not (Test-DashboardWorkspaceProcess $validFrontend frontend $backend $frontend)) { throw 'valid frontend rejected' }
if (Test-DashboardWorkspaceProcess $foreignFrontend frontend $backend $frontend) { throw 'foreign frontend accepted' }
$script:mockForeign = [pscustomobject]@{
    ProcessId = 4242
    ParentProcessId = 0
    Name = 'python.exe'
    ExecutablePath = 'C:\Foreign\python.exe'
    CommandLine = 'python -m uvicorn main:app --port 8000'
}
function Get-PortOwnerIds { param([int]$Port) return @(4242) }
function Get-CimInstance {
    param([string]$ClassName, [string]$Filter)
    if ($Filter) { return $script:mockForeign }
    return @($script:mockForeign)
}
function Get-Process { param([int]$Id) return [pscustomobject]@{ ProcessName='python'; StartTime=[datetime]'2026-07-21T00:00:00Z' } }
$rejected = $false
$orphanDiag = @()
try {
    Resolve-DashboardOrphanPort -Name dashboard-backend -Kind backend -Port 8000 `
        -ReceiptPath (Join-Path $env:TEMP 'missing-dashboard-receipt.json') `
        -BackendPython $backend -FrontendDir $frontend -Reclaim -InformationVariable orphanDiag
} catch {
    $rejected = $_.Exception.Message -match 'refusing reclaim'
}
if (-not $rejected) { throw 'foreign orphan reclaim did not fail closed' }
$diagnosticText = $orphanDiag -join "`n"
foreach ($marker in @('PID=4242', 'process=python', 'started_at=', 'Inspect manually:')) {
    if ($diagnosticText -notlike "*$marker*") { throw "simulated orphan diagnostic missing: $marker" }
}
$guardSource = Get-Content (Join-Path $AgentOSRoot 'dashboard\dashboard_orphan_guard.ps1') -Raw -Encoding UTF8
foreach ($marker in @('PID=$($item.ProcessId)', 'process=$($item.Name)', 'started_at=$($item.StartTime)', 'Inspect manually:', 'refusing reclaim')) {
    if ($guardSource -notlike "*$marker*") { throw "orphan diagnostic marker missing: $marker" }
}
Write-Output 'dashboard_orphan_guard=PASS'
Write-Output 'workspace_backend_only=true'
Write-Output 'workspace_frontend_only=true'
Write-Output 'diagnostics_and_refusal_present=true'
Write-Output 'foreign_reclaim_fail_closed=true'

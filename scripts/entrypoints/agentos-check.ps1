[CmdletBinding()]
param([switch]$RequireDashboard)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$smokeArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $root "scripts\agentos_ci_smoke.ps1"), "-AgentOSRoot", $root)
if ($RequireDashboard) { $smokeArgs += "-RequireDashboard" } else { $smokeArgs += "-NoDashboard" }

& powershell.exe @smokeArgs
if ($LASTEXITCODE -ne 0) { throw "AgentOS smoke gate failed." }
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "scripts\repository_hygiene_check.ps1") -AgentOSRoot $root
if ($LASTEXITCODE -ne 0) { throw "Repository hygiene gate failed." }

$frontend = Join-Path $root "dashboard\frontend"
if (-not (Test-Path (Join-Path $frontend "node_modules"))) {
    throw "Frontend dependencies are absent. Run dashboard\start.ps1 -Install before the local gate."
}
Push-Location $frontend
try {
    & npm.cmd run lint
    if ($LASTEXITCODE -ne 0) { throw "Frontend lint failed." }
    & npm.cmd run build -- --webpack
    if ($LASTEXITCODE -ne 0) { throw "Frontend production build failed." }
} finally {
    Pop-Location
}

$backend = Join-Path $root "dashboard\backend"
$python = Join-Path $backend ".venv\Scripts\python.exe"
if (-not (Test-Path -LiteralPath $python -PathType Leaf)) {
    throw "Backend virtual environment is absent. Run dashboard\start.ps1 -Install before the local gate."
}
& $python -m py_compile (Join-Path $backend "main.py")
if ($LASTEXITCODE -ne 0) { throw "Backend Python compilation failed." }
Push-Location $backend
try {
    & $python -c "import main"
    if ($LASTEXITCODE -ne 0) { throw "Backend import failed." }
} finally {
    Pop-Location
}

Write-Output "agentos_check_status=PASS"

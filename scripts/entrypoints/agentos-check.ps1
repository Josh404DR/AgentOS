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
if (Test-Path (Join-Path $frontend "node_modules")) {
    Push-Location $frontend
    try {
        & npm.cmd run lint
        if ($LASTEXITCODE -ne 0) { throw "Frontend lint failed." }
        & npm.cmd run build -- --webpack
        if ($LASTEXITCODE -ne 0) { throw "Frontend production build failed." }
    } finally {
        Pop-Location
    }
} else {
    Write-Warning "Frontend dependencies are absent; dashboard lint/build skipped. CI must run them."
}

Write-Output "agentos_check_status=PASS"

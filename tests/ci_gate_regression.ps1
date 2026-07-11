[CmdletBinding()]
param([string]$AgentOSRoot)
$ErrorActionPreference = "Stop"
if (-not $AgentOSRoot) { $AgentOSRoot = Split-Path -Parent $PSScriptRoot }
$root = (Resolve-Path $AgentOSRoot).Path
$fixture = Join-Path ([IO.Path]::GetTempPath()) ("agentos-gate-" + [Guid]::NewGuid().ToString("N"))
try {
    New-Item -ItemType Directory -Force -Path (Join-Path $fixture "config"), (Join-Path $fixture "tests") | Out-Null
    Copy-Item (Join-Path $root "tests\validate_script_registry.ps1") (Join-Path $fixture "tests\validate_script_registry.ps1")
    Copy-Item (Join-Path $root "config\script_registry.json") (Join-Path $fixture "config\script_registry.json")
    $registry = [IO.File]::ReadAllText((Join-Path $fixture "config\script_registry.json"), [Text.Encoding]::UTF8) | ConvertFrom-Json
    foreach ($entry in $registry.entries) {
        $path = Join-Path $fixture ([string]$entry.implementation_path -replace '/', '\')
        New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null
        [IO.File]::WriteAllText($path, "# fixture", [Text.UTF8Encoding]::new($false))
    }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fixture "tests\validate_script_registry.ps1") -AgentOSRoot $fixture | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Valid registry fixture did not pass." }

    $registry.entries[1].id = $registry.entries[0].id
    [IO.File]::WriteAllText((Join-Path $fixture "config\script_registry.json"), ($registry | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $badOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fixture "tests\validate_script_registry.ps1") -AgentOSRoot $fixture 2>&1
    $badExit = $LASTEXITCODE
    $ErrorActionPreference = $previousPreference
    if ($badExit -eq 0) { throw "Known-bad duplicate registry ID passed the gate: $($badOutput -join ' ')" }
    "ci_gate_regression=PASS"; "valid_fixture_passed=true"; "known_bad_fixture_rejected=true"
} finally {
    if (Test-Path $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}

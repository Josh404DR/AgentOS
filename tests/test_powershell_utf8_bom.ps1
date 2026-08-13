[CmdletBinding()]
param([string]$AgentOSRoot = "E:\AgentOS")

$ErrorActionPreference = 'Stop'
$checker = Join-Path $AgentOSRoot 'scripts\test_powershell_utf8_bom.ps1'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ("agentos-bom-fixture-" + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Force -Path $fixture | Out-Null
    [IO.File]::WriteAllText((Join-Path $fixture 'bad.ps1'), "Write-Output '中文'", [Text.UTF8Encoding]::new($false))
    $bad = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $checker -AgentOSRoot $fixture 2>&1
    if ($LASTEXITCODE -eq 0 -or ($bad -join "`n") -notmatch 'missing_utf8_bom=bad.ps1') {
        throw 'fault injection did not detect a non-ASCII PS1 without UTF-8 BOM'
    }
    $repo = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $checker -AgentOSRoot $AgentOSRoot 2>&1
    if ($LASTEXITCODE -ne 0) { throw ($repo -join "`n") }
    Write-Output 'powershell_utf8_bom_regression=PASS'
    Write-Output 'fault_injection_rejected=true'
    Write-Output 'repository_scan_passed=true'
} finally {
    if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}

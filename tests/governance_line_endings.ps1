[CmdletBinding()]
param([string]$AgentOSRoot)
$ErrorActionPreference = "Stop"
if (-not $AgentOSRoot) { $AgentOSRoot = Split-Path -Parent $PSScriptRoot }
$root = (Resolve-Path $AgentOSRoot).Path
$target = Join-Path $root "dashboard\frontend\app\page.tsx"
$statusPath = Join-Path $root "data\governance\governance_status.json"
$original = [IO.File]::ReadAllBytes($target)
$statusOriginal = if (Test-Path $statusPath) { [IO.File]::ReadAllBytes($statusPath) } else { $null }
try {
    $text = [IO.File]::ReadAllText($target, [Text.Encoding]::UTF8).Replace("`r`n", "`n").Replace("`r", "`n")
    [IO.File]::WriteAllText($target, $text.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "scripts\sync_shared_governance.ps1") -AgentOSRoot $root
    if ($LASTEXITCODE -ne 0 -or $output -notcontains "governance_status=aligned") { throw "CRLF-only conversion caused governance drift: $($output -join ' ')" }
    "governance_line_endings=PASS"; "crlf_lf_invariant=true"
} finally {
    [IO.File]::WriteAllBytes($target, $original)
    if ($null -ne $statusOriginal) { [IO.File]::WriteAllBytes($statusPath, $statusOriginal) }
}

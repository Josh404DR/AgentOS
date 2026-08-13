[CmdletBinding()]
param(
    [string]$AgentOSRoot = "E:\AgentOS",
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $AgentOSRoot).Path
$assertScript = Join-Path $root "scripts\assert_governance_ready.ps1"

if (-not (Test-Path -LiteralPath $assertScript -PathType Leaf)) {
    throw "Governance assertion script not found: $assertScript"
}

if (-not $OutputPath) {
    $OutputPath = Join-Path $root "docs\GOVERNANCE_STATUS_SNAPSHOT.md"
} elseif (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $root $OutputPath
}

$assertOutput = @(& $assertScript -AgentOSRoot $root)
if ($LASTEXITCODE -ne 0) {
    throw "Governance assertion failed with exit code $LASTEXITCODE.`n$($assertOutput -join [Environment]::NewLine)"
}

function Get-AssertionField {
    param([Parameter(Mandatory = $true)][string]$Name)

    $prefix = "$Name="
    $line = $assertOutput |
        Where-Object { $_ -is [string] -and $_.StartsWith($prefix, [System.StringComparison]::Ordinal) } |
        Select-Object -Last 1
    if (-not $line) {
        throw "Required field '$Name' was not emitted by assert_governance_ready.ps1."
    }
    return $line.Substring($prefix.Length)
}

$gate = Get-AssertionField -Name "governance_gate"
$status = Get-AssertionField -Name "governance_status"
$version = Get-AssertionField -Name "governance_version"
$hash = Get-AssertionField -Name "governance_hash"
$checkedAt = Get-AssertionField -Name "governance_checked_at"

$outputDirectory = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
    throw "Snapshot output directory does not exist: $outputDirectory"
}

$content = @'
# Governance Status Snapshot

> AUTO-GENERATED FILE. DO NOT EDIT MANUALLY.
> Generated from the governance check at: `{4}`

- Governance source: [`AGENTS.md`](../AGENTS.md)
- Status source: [`scripts/assert_governance_ready.ps1`](../scripts/assert_governance_ready.ps1)
- `governance_gate`: `{0}`
- `governance_version`: `{1}`
- `governance_status`: `{2}`
- `governance_hash`: `{3}`
- `governance_checked_at`: `{4}`

To refresh this file, run from the workspace root:

```powershell
.\scripts\write_governance_status_snapshot.ps1
```
'@ -f $gate, $version, $status, $hash, $checkedAt

Set-Content -LiteralPath $OutputPath -Value $content -Encoding UTF8
Write-Output "snapshot_path=$OutputPath"
$assertOutput | Write-Output

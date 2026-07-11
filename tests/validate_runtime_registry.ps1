[CmdletBinding()]
param([string]$AgentOSRoot)
$ErrorActionPreference = "Stop"
if (-not $AgentOSRoot) { $AgentOSRoot = Split-Path -Parent $PSScriptRoot }
$root = (Resolve-Path $AgentOSRoot).Path
$registry = [IO.File]::ReadAllText((Join-Path $root "config\runtime_registry.json"), [Text.Encoding]::UTF8) | ConvertFrom-Json
$items = @($registry.runtimes)
$duplicates = @($items | Group-Object runtime_id | Where-Object Count -ne 1)
if ($duplicates) { throw "Duplicate runtime IDs: $($duplicates.Name -join ',')" }
foreach ($item in $items) {
    if ($item.start_source.script) {
        $path = Join-Path $root ([string]$item.start_source.script -replace '/', '\')
        if (-not (Test-Path $path -PathType Leaf)) { throw "Missing runtime script: $($item.start_source.script)" }
    }
    if ($item.control.enabled) {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "scripts\runtimes\control-runtime.ps1") -RuntimeId $item.runtime_id -Action start -AgentOSRoot $root -ValidateOnly | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Invalid runtime control: $($item.runtime_id)" }
    }
}
"runtime_registry_status=PASS"; "runtime_count=$($items.Count)"; "controlled_count=$(@($items | Where-Object { $_.control.enabled }).Count)"

[CmdletBinding()]
param([string]$AgentOSRoot)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($AgentOSRoot)) {
    $AgentOSRoot = Split-Path -Parent $PSScriptRoot
}
$root = (Resolve-Path -LiteralPath $AgentOSRoot).Path
$registryPath = Join-Path $root "config\script_registry.json"
$registry = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json
$entries = @($registry.entries)
$errors = [Collections.Generic.List[string]]::new()

$ids = @($entries | Group-Object id | Where-Object Count -ne 1)
foreach ($group in $ids) { $errors.Add("duplicate id: $($group.Name)") }

$paths = @($entries | Group-Object implementation_path | Where-Object Count -ne 1)
foreach ($group in $paths) { $errors.Add("duplicate path: $($group.Name)") }

foreach ($entry in $entries) {
    $path = Join-Path $root ($entry.implementation_path -replace '/', '\')
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $errors.Add("missing registry path: $($entry.implementation_path)")
    }
}

$scriptsRoot = Join-Path $root "scripts"
$executables = @(Get-ChildItem -LiteralPath $scriptsRoot -Recurse -File |
    Where-Object Extension -in @(".ps1", ".py", ".js", ".mjs", ".bat", ".cmd") |
    ForEach-Object { "scripts/" + $_.FullName.Substring($scriptsRoot.Length + 1).Replace('\', '/') })
$toolExecutables = @(Get-ChildItem -LiteralPath (Join-Path $root "tools") -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object Extension -in @(".ps1", ".py", ".js", ".mjs", ".bat", ".cmd") |
    ForEach-Object { $_.FullName.Substring($root.Length + 1).Replace('\', '/') })
$executables += $toolExecutables
$registered = @($entries.implementation_path)
foreach ($path in $executables) {
    if ($path -notin $registered) { $errors.Add("unregistered executable: $path") }
}
foreach ($path in $registered) {
    if (($path -like "scripts/*" -or $path -like "tools/*") -and $path -notin $executables) { $errors.Add("registry path is not executable: $path") }
}

$readmePath = Join-Path $root "scripts\REGISTRY.md"
if (-not (Test-Path -LiteralPath $readmePath -PathType Leaf)) {
    $errors.Add("generated registry README is missing")
} else {
    $readme = [IO.File]::ReadAllText($readmePath, [Text.Encoding]::UTF8)
    if ($readme.Contains('$(@{')) { $errors.Add("generated registry README contains an unevaluated PowerShell expression") }
    foreach ($entry in $entries) {
        if ($readme -notmatch [regex]::Escape("``$($entry.id)``") -or
            $readme -notmatch [regex]::Escape("``$($entry.implementation_path)``")) {
            $errors.Add("generated registry README does not describe: $($entry.id)")
        }
    }
}

if ($errors.Count) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "script_registry_status=PASS"
Write-Output "entry_count=$($entries.Count)"

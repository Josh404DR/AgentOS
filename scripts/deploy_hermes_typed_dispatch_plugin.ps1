param(
    [string]$AgentOSRoot = "E:\AgentOS",
    [string]$HermesHome = (Join-Path $env:LOCALAPPDATA "hermes")
)

$ErrorActionPreference = "Stop"

$source = Join-Path $AgentOSRoot "integrations\hermes_plugins\agentos-typed-dispatch"
$target = Join-Path $HermesHome "plugins\agentos-typed-dispatch"

foreach ($name in @("__init__.py", "plugin.yaml")) {
    $sourceFile = Join-Path $source $name
    if (-not (Test-Path -LiteralPath $sourceFile)) {
        throw "Canonical plugin file not found: $sourceFile"
    }
}

New-Item -ItemType Directory -Force -Path $target | Out-Null
Copy-Item -LiteralPath (Join-Path $source "__init__.py") -Destination $target -Force
Copy-Item -LiteralPath (Join-Path $source "plugin.yaml") -Destination $target -Force

$cache = Join-Path $target "__pycache__"
if (Test-Path -LiteralPath $cache) {
    $resolvedTarget = (Resolve-Path -LiteralPath $target).Path
    $resolvedCache = (Resolve-Path -LiteralPath $cache).Path
    if (-not $resolvedCache.StartsWith(
        $resolvedTarget,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Unexpected plugin cache path: $resolvedCache"
    }
    Remove-Item -LiteralPath $resolvedCache -Recurse -Force
}

$sourceHash = (Get-FileHash -LiteralPath (Join-Path $source "__init__.py") -Algorithm SHA256).Hash
$targetHash = (Get-FileHash -LiteralPath (Join-Path $target "__init__.py") -Algorithm SHA256).Hash
if ($sourceHash -ne $targetHash) {
    throw "Plugin deployment hash mismatch."
}

Write-Output "plugin_deployment_status=completed"
Write-Output "hermes_home=$HermesHome"
Write-Output "plugin_path=$target"
Write-Output "plugin_hash=$targetHash"
Write-Output "gateway_restart_required=true"

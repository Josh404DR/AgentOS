param(
    [string]$AgentOSRoot = "E:\AgentOS",
    [string]$PythonPath
)

$ErrorActionPreference = "Stop"
$runtimeLoader = Join-Path $AgentOSRoot "scripts\lib\runtime_config.ps1"
. $runtimeLoader
$runtimeConfig = Get-AgentOSRuntimeConfig -AgentOSRoot $AgentOSRoot
if ([string]::IsNullOrWhiteSpace($PythonPath)) {
    $PythonPath = [string]$runtimeConfig.hermes.python
}
$scriptPath = Join-Path $AgentOSRoot "scripts\export_obsidian_view_nodes.py"
if (-not (Test-Path -LiteralPath $PythonPath -PathType Leaf)) {
    throw "Python runtime not found: $PythonPath"
}
if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw "Exporter not found: $scriptPath"
}
& $PythonPath $scriptPath --root $AgentOSRoot
if ($LASTEXITCODE -ne 0) {
    throw "Obsidian view-node export failed with exit code $LASTEXITCODE"
}

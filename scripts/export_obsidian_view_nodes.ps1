param(
    [string]$AgentOSRoot = "E:\AgentOS",
    [string]$PythonPath = "E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\.uv-python\cpython-3.13-windows-x86_64-none\python.exe"
)

$ErrorActionPreference = "Stop"
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

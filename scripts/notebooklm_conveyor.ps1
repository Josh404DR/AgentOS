param(
    [ValidateSet("DryRun", "Live")]
    [string]$Mode = "DryRun",
    [string]$NotebookId = "79ef4683-f7d2-43da-b8d3-7298858949e5",
    [string]$PythonPath = "C:\Users\brian\AppData\Local\Programs\Python\Python310\python.exe",
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [switch]$SkipExport
)

$ErrorActionPreference = "Stop"

$rootPath = (Resolve-Path $Root).Path
$exportDir = Join-Path $rootPath "exports\notebooklm_v1"
$logDir = Join-Path $rootPath "data\memory\sync_logs\conveyor"
$syncScript = Join-Path $rootPath "scripts\sync_notebooklm.py"

if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

if (-not $SkipExport) {
    & (Join-Path $rootPath "scripts\export_notebooklm_sources.ps1") -Root $rootPath -ExportDir $exportDir
}

if (-not (Test-Path $PythonPath)) {
    throw "PythonPath not found: $PythonPath"
}

$args = @(
    $syncScript,
    "--export-dir", $exportDir,
    "--notebook-id", $NotebookId,
    "--log-dir", $logDir,
    "--title-mode", "relpath-hash"
)

if ($Mode -eq "DryRun") {
    $args += "--dry-run"
}

& $PythonPath @args

$summaryPath = Join-Path $logDir ("notebooklm_conveyor_{0}.md" -f (Get-Date -Format "yyyy-MM-dd_HHmmss"))
$summary = @"
# NotebookLM Conveyor Run

- timestamp: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz")
- mode: $Mode
- notebook_id: $NotebookId
- export_dir: $exportDir
- python_path: $PythonPath
- title_mode: relpath-hash
- models_invoked: false
- external_services_invoked: $($Mode -eq "Live")
- live_external_action_executed: $($Mode -eq "Live")

AgentOS local files remain the source of truth. NotebookLM is retrieval-only.
"@

Set-Content -LiteralPath $summaryPath -Value $summary -Encoding UTF8

Write-Output "CONVEYOR_STATUS=ok"
Write-Output "CONVEYOR_MODE=$Mode"
Write-Output "SUMMARY_PATH=$summaryPath"

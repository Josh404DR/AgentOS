param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$ExportDir = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "exports\notebooklm_v1"),
    [switch]$NoClean
)

$ErrorActionPreference = "Stop"

function Get-RelativePathCompat {
    param(
        [string]$BasePath,
        [string]$TargetPath
    )

    $base = [System.IO.Path]::GetFullPath($BasePath).TrimEnd('\') + '\'
    $target = [System.IO.Path]::GetFullPath($TargetPath)
    $baseUri = New-Object System.Uri($base)
    $targetUri = New-Object System.Uri($target)
    $relativeUri = $baseUri.MakeRelativeUri($targetUri)
    return [System.Uri]::UnescapeDataString($relativeUri.ToString()).Replace('/', '\')
}

$rootPath = (Resolve-Path $Root).Path
$exportPath = $ExportDir

if (-not (Test-Path $exportPath)) {
    New-Item -ItemType Directory -Path $exportPath | Out-Null
}

$resolvedExport = (Resolve-Path $exportPath).Path
$expectedPrefix = (Join-Path $rootPath "exports")
if (-not $resolvedExport.StartsWith($expectedPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to write export outside workspace exports directory: $resolvedExport"
}

if (-not $NoClean) {
    Get-ChildItem -LiteralPath $resolvedExport -Force | Remove-Item -Recurse -Force
}

$sourcePatterns = @(
    "current_state.md",
    "README.md",
    "PROJECT_ANALYSIS.md",
    "RECOMMENDATIONS.md",
    "docs\*.md",
    "agents\roles\*.md",
    "workflows\*.md",
    "data\memory\HERMES_CORE_MEMORY.md",
    "data\memory\NOTEBOOKLM_SOURCE_INDEX.md",
    "data\knowledge_pool\*.md"
)

$files = New-Object System.Collections.Generic.List[string]
foreach ($pattern in $sourcePatterns) {
    Get-ChildItem -Path (Join-Path $rootPath $pattern) -File -ErrorAction SilentlyContinue |
        ForEach-Object { $files.Add($_.FullName) }
}

$files = $files | Sort-Object -Unique

foreach ($file in $files) {
    $relative = Get-RelativePathCompat -BasePath $rootPath -TargetPath $file
    $destination = Join-Path $resolvedExport $relative
    $destinationDir = Split-Path -Parent $destination
    if (-not (Test-Path $destinationDir)) {
        New-Item -ItemType Directory -Path $destinationDir | Out-Null
    }
    Copy-Item -LiteralPath $file -Destination $destination -Force
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"
$guide = @"
# NotebookLM Export Guide

Generated: $timestamp

This folder is a generated export pack for NotebookLM. AgentOS local files remain the source of truth.

Cursor-owned analysis files are copied read-only for retrieval:

- PROJECT_ANALYSIS.md
- RECOMMENDATIONS.md

Do not edit generated export copies by hand. Edit source files through their owning agent/process and rerun the conveyor.

## Exported Source Count

$($files.Count)
"@

$guidePath = Join-Path $resolvedExport "NOTEBOOK_GUIDE.md"
Set-Content -LiteralPath $guidePath -Value $guide -Encoding UTF8

$logDir = Join-Path $rootPath "data\memory\sync_logs\conveyor"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

$logPath = Join-Path $logDir ("notebooklm_export_manifest_{0}.md" -f (Get-Date -Format "yyyy-MM-dd_HHmmss"))
$manifestLines = @(
    "# NotebookLM Export Manifest",
    "",
    "- generated_at: $timestamp",
    "- export_dir: $resolvedExport",
    "- source_count: $($files.Count)",
    "- cursor_owned_files_copied_read_only: true",
    "",
    "## Sources"
)

foreach ($file in $files) {
    $manifestLines += "- " + (Get-RelativePathCompat -BasePath $rootPath -TargetPath $file)
}

Set-Content -LiteralPath $logPath -Value ($manifestLines -join [Environment]::NewLine) -Encoding UTF8

Write-Output "EXPORT_STATUS=ok"
Write-Output "EXPORT_DIR=$resolvedExport"
Write-Output "SOURCE_COUNT=$($files.Count)"
Write-Output "MANIFEST_PATH=$logPath"

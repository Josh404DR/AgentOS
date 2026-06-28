param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$ExportDir = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "exports\notebooklm_v1")
)

$ErrorActionPreference = "Stop"

function Get-RelativePathCompat {
    param([string]$BasePath, [string]$TargetPath)
    $base = [System.IO.Path]::GetFullPath($BasePath).TrimEnd('\') + '\'
    $target = [System.IO.Path]::GetFullPath($TargetPath)
    $baseUri = New-Object System.Uri($base)
    $targetUri = New-Object System.Uri($target)
    return [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString()).Replace('/', '\')
}

function Resolve-SourceFiles {
    param([string[]]$Patterns)
    $resolved = New-Object System.Collections.Generic.List[string]
    foreach ($pattern in $Patterns) {
        Get-ChildItem -Path (Join-Path $script:RootPath $pattern) -File -ErrorAction SilentlyContinue |
            ForEach-Object { $resolved.Add($_.FullName) }
    }
    return @($resolved | Sort-Object -Unique)
}

function Write-Bundle {
    param(
        [string]$Name,
        [string]$Definition,
        [string[]]$Files
    )

    $outputPath = Join-Path $script:ExportPath "$Name.md"
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# AgentOS $Name")
    $lines.Add("")
    $lines.Add("- generated_at: $script:Timestamp")
    $lines.Add("- source_of_truth: local_git")
    $lines.Add("- notebooklm_role: human_auxiliary_retrieval")
    $lines.Add("- exclusive_definition: $Definition")
    $lines.Add("- source_count: $($Files.Count)")
    $lines.Add("")

    foreach ($file in $Files) {
        $relative = Get-RelativePathCompat -BasePath $script:RootPath -TargetPath $file
        $content = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)
        $lines.Add("---")
        $lines.Add("")
        $lines.Add("## Source: $relative")
        $lines.Add("")
        $lines.Add($content.Trim())
        $lines.Add("")
    }

    [System.IO.File]::WriteAllText(
        $outputPath,
        ($lines -join [Environment]::NewLine),
        (New-Object System.Text.UTF8Encoding($false))
    )

    return [PSCustomObject]@{
        Bundle = $Name
        Path = $outputPath
        SourceCount = $Files.Count
        Sha256 = (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash.ToLowerInvariant()
        Sources = $Files
    }
}

$script:RootPath = (Resolve-Path $Root).Path
$script:ExportPath = $ExportDir
$script:Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"

if (-not (Test-Path $script:ExportPath)) {
    New-Item -ItemType Directory -Path $script:ExportPath | Out-Null
}

$resolvedExport = (Resolve-Path $script:ExportPath).Path
$expectedPrefix = (Join-Path $script:RootPath "exports")
if (-not $resolvedExport.StartsWith($expectedPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to write export outside workspace exports directory: $resolvedExport"
}

# The export directory is generated data. Rebuild it completely so stale
# per-file snapshots from the previous layout cannot leak into a bundle run.
Get-ChildItem -LiteralPath $resolvedExport -Force | Remove-Item -Recurse -Force

$bundleSpecs = @(
    @{
        Name = "CORE"
        Definition = "System architecture, governance, and role definitions that do not represent transient task state."
        Patterns = @(
            "README.md",
            "docs\ARCHITECTURE.md",
            "docs\EVIDENCE_AND_REPORTING_CONTRACT.md",
            "docs\HERMES_REPORTING_PRINCIPLES.md",
            "docs\MEMORY_ARCHITECTURE.md",
            "agents\roles\*.md"
        )
    },
    @{
        Name = "OPERATIONS"
        Definition = "Current operating procedures, routing rules, setup guidance, and active workflow instructions."
        Patterns = @(
            "workflows\*.md",
            "docs\AGENT_ROUTING_PLAN.md",
            "docs\COST_SAVING_ROUTING_PROTOCOL.md",
            "docs\FREE_CLOUD_WINDOW_POLICY.md",
            "docs\NOTEBOOKLM_CONVEYOR.md",
            "docs\PRE_FLIGHT_TEST_PLAN.md",
            "docs\RESOURCE_INVENTORY.md",
            "docs\SETUP_STATUS.md",
            "docs\TELEGRAM_TYPED_DISPATCH_HANDOFF.md"
        )
    },
    @{
        Name = "MEMORY"
        Definition = "Compact current state and maintained Agent memory indexes; raw transcripts and task evidence are excluded."
        Patterns = @(
            "current_state.md",
            "HERMES_NOTES.md",
            "data\memory\HERMES_CORE_MEMORY.md",
            "data\memory\NOTEBOOKLM_SOURCE_INDEX.md"
        )
    },
    @{
        Name = "KNOWLEDGE_POOL"
        Definition = "External references and distilled reusable research, not current operational truth."
        Patterns = @("data\knowledge_pool\*.md")
    },
    @{
        Name = "PROJECT_ANALYSIS"
        Definition = "Cursor-owned project analysis copied read-only for human retrieval."
        Patterns = @("PROJECT_ANALYSIS.md")
    },
    @{
        Name = "RECOMMENDATIONS"
        Definition = "Cursor-owned recommendations copied read-only; recommendations are not adopted decisions."
        Patterns = @("RECOMMENDATIONS.md")
    }
)

$results = New-Object System.Collections.Generic.List[object]
foreach ($spec in $bundleSpecs) {
    $files = Resolve-SourceFiles -Patterns $spec.Patterns
    $results.Add((Write-Bundle -Name $spec.Name -Definition $spec.Definition -Files $files))
}

$logDir = Join-Path $script:RootPath "data\memory\sync_logs\conveyor"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

$logPath = Join-Path $logDir ("notebooklm_bundle_manifest_{0}.md" -f (Get-Date -Format "yyyy-MM-dd_HHmmss"))
$manifest = New-Object System.Collections.Generic.List[string]
$manifest.Add("# NotebookLM Bundle Manifest")
$manifest.Add("")
$manifest.Add("- generated_at: $script:Timestamp")
$manifest.Add("- bundle_count: $($results.Count)")
$manifest.Add("- local_source_of_truth: true")
$manifest.Add("- cursor_owned_files_copied_read_only: true")
$manifest.Add("- raw_evidence_excluded: true")
$manifest.Add("")

foreach ($result in $results) {
    $manifest.Add("## $($result.Bundle)")
    $manifest.Add("")
    $manifest.Add("- source_count: $($result.SourceCount)")
    $manifest.Add("- sha256: $($result.Sha256)")
    foreach ($file in $result.Sources) {
        $manifest.Add("- source: " + (Get-RelativePathCompat -BasePath $script:RootPath -TargetPath $file))
    }
    $manifest.Add("")
}

[System.IO.File]::WriteAllText(
    $logPath,
    ($manifest -join [Environment]::NewLine),
    (New-Object System.Text.UTF8Encoding($false))
)

Write-Output "EXPORT_STATUS=ok"
Write-Output "EXPORT_DIR=$resolvedExport"
Write-Output "BUNDLE_COUNT=$($results.Count)"
Write-Output "MANIFEST_PATH=$logPath"

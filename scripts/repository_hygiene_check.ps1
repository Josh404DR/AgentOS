[CmdletBinding()]
param(
    [string]$AgentOSRoot = (Split-Path $PSScriptRoot -Parent),
    [switch]$ReportOnly,
    [string]$JsonReportPath
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $AgentOSRoot).Path
$boundaryPath = Join-Path $root "config\repository_boundary.json"

if (-not (Test-Path -LiteralPath $boundaryPath -PathType Leaf)) {
    throw "Repository boundary file missing: $boundaryPath"
}

$boundary = Get-Content -LiteralPath $boundaryPath -Raw -Encoding UTF8 | ConvertFrom-Json
$safeRoot = $root.Replace("\", "/")
$findings = [Collections.Generic.List[object]]::new()

function Add-Finding {
    param([string]$Severity, [string]$Code, [string]$Path, [string]$Detail)
    $findings.Add([pscustomobject]@{
        severity = $Severity
        code = $Code
        path = $Path
        detail = $Detail
    })
}

function Test-GlobMatch {
    param([string]$Path, [object[]]$Patterns)
    $normalized = $Path.Replace("\", "/")
    $matched = $false
    foreach ($rawPattern in $Patterns) {
        $pattern = [string]$rawPattern
        if ($pattern.StartsWith("!")) {
            if ($normalized -like $pattern.Substring(1)) { $matched = $false }
            continue
        }
        if ($normalized -like $pattern) { $matched = $true }
    }
    return $matched
}

foreach ($required in $boundary.required_files) {
    $requiredPath = Join-Path $root ([string]$required).Replace("/", "\")
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        Add-Finding "error" "REQUIRED_FILE_MISSING" ([string]$required) "Required repository file is absent."
    }
}

$tracked = @(& git -c "safe.directory=$safeRoot" -c core.quotepath=false -C $root ls-files)
if ($LASTEXITCODE -ne 0) {
    throw "git ls-files failed with exit code $LASTEXITCODE"
}
$untracked = @(& git -c "safe.directory=$safeRoot" -c core.quotepath=false -C $root ls-files --others --exclude-standard)
if ($LASTEXITCODE -ne 0) {
    throw "git ls-files --others failed with exit code $LASTEXITCODE"
}
$candidateFiles = @($tracked + $untracked | Sort-Object -Unique)

foreach ($path in $tracked) {
    $normalized = $path.Replace("\", "/")

    if ($normalized.StartsWith("data/") -and
        -not (Test-GlobMatch $normalized $boundary.allowed_tracked_data_globs)) {
        Add-Finding "error" "RUNTIME_DATA_TRACKED" $normalized "Tracked data path is outside the explicit data allowlist."
    }

    if (Test-GlobMatch $normalized $boundary.forbidden_tracked_globs) {
        Add-Finding "error" "FORBIDDEN_PATH_TRACKED" $normalized "Path matches a machine-local, generated, or runtime exclusion."
    }

    $fullPath = Join-Path $root $path.Replace("/", "\")
    if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
        $item = Get-Item -LiteralPath $fullPath
        if ($item.Length -gt [long]$boundary.max_tracked_file_bytes) {
            Add-Finding "error" "TRACKED_FILE_TOO_LARGE" $normalized "Tracked file is $($item.Length) bytes."
        }
    }
}

$secretNames = '(?i)(api[_-]?key|access[_-]?token|refresh[_-]?token|client[_-]?secret|password)'
$literalAssignment = [regex]::new(
    $secretNames + '\s*[:=]\s*["'']([A-Za-z0-9_\-]{16,})["'']',
    [Text.RegularExpressions.RegexOptions]::Compiled
)
$textExtensions = @(".ps1", ".py", ".js", ".mjs", ".ts", ".tsx", ".json", ".yml", ".yaml", ".toml", ".ini")

foreach ($path in $candidateFiles) {
    $fullPath = Join-Path $root $path.Replace("/", "\")
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { continue }
    if ($textExtensions -notcontains [IO.Path]::GetExtension($fullPath).ToLowerInvariant()) { continue }

    $lineNumber = 0
    foreach ($line in Get-Content -LiteralPath $fullPath -Encoding UTF8) {
        $lineNumber++
        $match = $literalAssignment.Match($line)
        if (-not $match.Success) { continue }
        $candidate = $match.Groups[2].Value
        if ($candidate -match '^[A-Z][A-Z0-9_]+$' -or $candidate -match '(?i)(example|placeholder|replace|changeme)') {
            continue
        }
        Add-Finding "error" "POSSIBLE_LITERAL_SECRET" ($path.Replace("\", "/")) "Possible literal secret at line $lineNumber; value redacted."
    }
}

$errors = @($findings | Where-Object severity -eq "error")
$warnings = @($findings | Where-Object severity -eq "warning")
$uniquePaths = @($findings.path | Sort-Object -Unique)

if (-not [string]::IsNullOrWhiteSpace($JsonReportPath)) {
    $reportFullPath = if ([IO.Path]::IsPathRooted($JsonReportPath)) {
        $JsonReportPath
    } else {
        Join-Path $root $JsonReportPath
    }
    $reportParent = Split-Path $reportFullPath -Parent
    if (-not (Test-Path -LiteralPath $reportParent)) {
        New-Item -ItemType Directory -Path $reportParent -Force | Out-Null
    }
    $migrationEntries = foreach ($uniquePath in $uniquePaths) {
        $fullPath = Join-Path $root $uniquePath.Replace("/", "\")
        $item = if (Test-Path -LiteralPath $fullPath -PathType Leaf) { Get-Item -LiteralPath $fullPath } else { $null }
        [ordered]@{
            path = $uniquePath
            finding_codes = @($findings | Where-Object path -eq $uniquePath | Select-Object -ExpandProperty code -Unique)
            bytes = if ($item) { $item.Length } else { $null }
            sha256 = if ($item) { (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash } else { $null }
            proposed_action = "untrack_from_cleanup_branch_only"
            live_workspace_effect = "none"
            restore_command = "git checkout origin/master -- `"$uniquePath`""
        }
    }
    $report = [ordered]@{
        generated_at = (Get-Date).ToString("o")
        repository_root = $root
        report_only = [bool]$ReportOnly
        tracked_file_count = $tracked.Count
        untracked_candidate_count = $untracked.Count
        candidate_file_count = $candidateFiles.Count
        error_count = $errors.Count
        warning_count = $warnings.Count
        unique_path_count = $uniquePaths.Count
        proposed_action = "untrack_from_cleanup_branch_only"
        live_workspace_effect = "none"
        findings = @($findings | Sort-Object code, path)
        migration_entries = @($migrationEntries)
    }
    $json = $report | ConvertTo-Json -Depth 6
    [IO.File]::WriteAllText($reportFullPath, $json, [Text.UTF8Encoding]::new($false))
    Write-Output "json_report=$reportFullPath"
}

foreach ($finding in $findings | Sort-Object code, path) {
    Write-Output ("{0}: {1} | {2} | {3}" -f $finding.severity.ToUpperInvariant(), $finding.code, $finding.path, $finding.detail)
}

Write-Output "repository_hygiene_status=$(if ($errors.Count -eq 0) { 'PASS' } elseif ($ReportOnly) { 'REPORT_ONLY' } else { 'FAIL' })"
Write-Output "tracked_file_count=$($tracked.Count)"
Write-Output "untracked_candidate_count=$($untracked.Count)"
Write-Output "candidate_file_count=$($candidateFiles.Count)"
Write-Output "error_count=$($errors.Count)"
Write-Output "warning_count=$($warnings.Count)"
Write-Output "unique_path_count=$($uniquePaths.Count)"

if ($errors.Count -gt 0 -and -not $ReportOnly) { exit 1 }

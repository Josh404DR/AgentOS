[CmdletBinding()]
param(
    [string]$AgentOSRoot = "E:\AgentOS",
    [string]$TasksRoot = "",
    [string]$IndexPath = "",
    [string[]]$TaskPaths = @()
)

$ErrorActionPreference = "Stop"
$utf8NoBom = [Text.UTF8Encoding]::new($false)
if (-not $TasksRoot) { $TasksRoot = Join-Path $AgentOSRoot "data\codex_tasks" }
if (-not $IndexPath) { $IndexPath = Join-Path $AgentOSRoot "data\queue_runs\ACTIVE_TASK_INDEX.json" }

function Get-TaskField([string]$Text, [string]$Name) {
    $match = [regex]::Match(
        $Text,
        "(?mi)^\s*" + [regex]::Escape($Name) + "\s*[:=]\s*(.+?)\s*$"
    )
    if ($match.Success) { return $match.Groups[1].Value.Trim().Trim('"').Trim("'") }
    return ""
}

function Convert-TaskFileToIndexEntry([string]$TaskPath) {
    if (-not (Test-Path -LiteralPath $TaskPath -PathType Leaf)) { return $null }
    $item = Get-Item -LiteralPath $TaskPath
    $text = [IO.File]::ReadAllText($item.FullName, [Text.Encoding]::UTF8)
    $dispatchId = Get-TaskField $text "dispatch_id"
    if (-not $dispatchId) { return $null }
    $order = Get-TaskField $text "dependency_order"
    $revisionRound = Get-TaskField $text "revision_round"
    return [ordered]@{
        dispatch_id = $dispatchId
        directory_name = $item.Directory.Name
        task_path = $item.FullName
        task_mtime_utc = $item.LastWriteTimeUtc.ToString("o")
        task_mtime_utc_ticks = $item.LastWriteTimeUtc.Ticks
        task_length = [long]$item.Length
        dispatch_status = Get-TaskField $text "dispatch_status"
        task_status = Get-TaskField $text "task_status"
        type = Get-TaskField $text "type"
        route_to = Get-TaskField $text "route_to"
        depends_on = Get-TaskField $text "depends_on"
        parent_dispatch_id = Get-TaskField $text "parent_dispatch_id"
        revision_of = Get-TaskField $text "revision_of"
        source_dispatch_id = Get-TaskField $text "source_dispatch_id"
        dependency_order = if ($order) { [int]$order } else { 999 }
        revision_round = if ($revisionRound) { [int]$revisionRound } else { 0 }
        task_type = Get-TaskField $text "task_type"
        risk_level = Get-TaskField $text "risk_level"
        codex_mode = Get-TaskField $text "codex_mode"
        governance_version = Get-TaskField $text "governance_version"
        governance_hash = Get-TaskField $text "governance_hash"
    }
}

$isIncremental = $TaskPaths.Count -gt 0
$entriesById = [ordered]@{}
$existing = $null

if ($isIncremental -and (Test-Path -LiteralPath $IndexPath -PathType Leaf)) {
    $existing = [IO.File]::ReadAllText($IndexPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
    foreach ($entry in @($existing.tasks)) {
        $entriesById[[string]$entry.dispatch_id] = $entry
    }
}

$directories = if (-not $isIncremental -and (Test-Path -LiteralPath $TasksRoot -PathType Container)) {
    @(Get-ChildItem -LiteralPath $TasksRoot -Directory)
} else {
    @()
}
$pathsToRead = if ($isIncremental) {
    @($TaskPaths | Select-Object -Unique)
} else {
    @($directories | ForEach-Object { Join-Path $_.FullName "TASK.md" })
}

foreach ($taskPath in $pathsToRead) {
    $resolvedPath = [IO.Path]::GetFullPath($taskPath)
    $tasksRootPrefix = [IO.Path]::GetFullPath($TasksRoot).TrimEnd('\') + '\'
    if (-not $resolvedPath.StartsWith($tasksRootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "task path outside TasksRoot: $resolvedPath"
    }
    $entry = Convert-TaskFileToIndexEntry $resolvedPath
    if ($entry) {
        $entriesById[[string]$entry.dispatch_id] = $entry
    } else {
        foreach ($id in @($entriesById.Keys)) {
            if ([string]$entriesById[$id].task_path -eq $resolvedPath) {
                $entriesById.Remove($id)
            }
        }
    }
}

$directoryCount = if ($isIncremental) { [int]$existing.directory_count } else { $directories.Count }
$tasksRootItem = if (Test-Path -LiteralPath $TasksRoot -PathType Container) {
    Get-Item -LiteralPath $TasksRoot
} else {
    $null
}
$index = [ordered]@{
    schema_version = 3
    generated_at = (Get-Date -Format o)
    source = "TASK.md"
    tasks_root = [IO.Path]::GetFullPath($TasksRoot)
    tasks_root_mtime_utc = if ($tasksRootItem) { $tasksRootItem.LastWriteTimeUtc.ToString("o") } else { [datetime]::MinValue.ToString("o") }
    tasks_root_mtime_utc_ticks = if ($tasksRootItem) { $tasksRootItem.LastWriteTimeUtc.Ticks } else { [datetime]::MinValue.Ticks }
    directory_count = $directoryCount
    task_count = $entriesById.Count
    tasks = @($entriesById.Values | Sort-Object dispatch_id)
}

$parent = Split-Path -Parent $IndexPath
New-Item -ItemType Directory -Force -Path $parent | Out-Null
$tempPath = Join-Path $parent (".ACTIVE_TASK_INDEX.$PID.$([guid]::NewGuid().ToString('N')).tmp")
try {
    [IO.File]::WriteAllText(
        $tempPath,
        ($index | ConvertTo-Json -Depth 5),
        $utf8NoBom
    )
    Move-Item -LiteralPath $tempPath -Destination $IndexPath -Force
} finally {
    if (Test-Path -LiteralPath $tempPath -PathType Leaf) {
        Remove-Item -LiteralPath $tempPath -Force
    }
}

Write-Output "index_rebuild_status=completed"
Write-Output "index_rebuild_mode=$(if ($isIncremental) { 'incremental' } else { 'full' })"
Write-Output "index_path=$IndexPath"
Write-Output "directory_count=$directoryCount"
Write-Output "task_count=$($entriesById.Count)"

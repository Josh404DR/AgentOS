[CmdletBinding()]
param(
    [string]$AgentOSRoot = "E:\AgentOS",
    [int]$Runs = 20,
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"
$utf8NoBom = [Text.UTF8Encoding]::new($false)
$currentCount = @(Get-ChildItem -LiteralPath (Join-Path $AgentOSRoot "data\codex_tasks") -Directory).Count
if ($currentCount -lt 1) { throw "current task directory count is zero" }
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) "AgentOS-queue-benchmark-$PID-$([guid]::NewGuid().ToString('N'))"
$tasksRoot = Join-Path $fixtureRoot "data\codex_tasks"
$indexPath = Join-Path $fixtureRoot "data\queue_runs\ACTIVE_TASK_INDEX.json"
$resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
$resolvedFixture = [IO.Path]::GetFullPath($fixtureRoot)
if (-not $resolvedFixture.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase)) {
    throw "unsafe fixture path: $resolvedFixture"
}

function Get-Field([string]$Text, [string]$Name) {
    $match = [regex]::Match($Text, "(?mi)^\s*" + [regex]::Escape($Name) + "\s*[:=]\s*(.+?)\s*$")
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return ""
}

function Measure-Latencies([scriptblock]$Action, [int]$Count) {
    & $Action | Out-Null
    $values = for ($i = 0; $i -lt $Count; $i++) {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        & $Action | Out-Null
        $sw.Stop()
        $sw.Elapsed.TotalMilliseconds
    }
    return @($values)
}

function Get-P95([double[]]$Values) {
    $sorted = @($Values | Sort-Object)
    $rank = [math]::Ceiling(0.95 * $sorted.Count) - 1
    return [math]::Round($sorted[$rank], 3)
}

function Add-Fixtures([int]$From, [int]$To) {
    for ($i = $From; $i -lt $To; $i++) {
        $id = "synthetic-$i"
        $dir = Join-Path $tasksRoot $id
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $isScoped = $i -lt 10
        $parent = if ($i -eq 0 -or -not $isScoped) { "none" } else { "synthetic-0" }
        $source = if ($isScoped) { "synthetic-0" } else { "unrelated-root-$i" }
        $task = "dispatch_id: $id`nparent_dispatch_id: $parent`nsource_dispatch_id: $source`ndependency_order: $i`ndepends_on: none`ntype: CODEX_BUILD`nroute_to: Codex`ncodex_mode: build`ntask_type: Simple`ntask_status: ready`ndispatch_status: ready_to_route`ngovernance_version: 1.3.0`ngovernance_hash: fixture`n"
        [IO.File]::WriteAllText((Join-Path $dir "TASK.md"), $task, $utf8NoBom)
    }
}

$results = [Collections.Generic.List[object]]::new()
try {
    New-Item -ItemType Directory -Force -Path $tasksRoot | Out-Null
    $previousTarget = 0
    foreach ($scale in @(1, 3, 10)) {
        $target = $currentCount * $scale
        Add-Fixtures $previousTarget $target
        $previousTarget = $target
        & (Join-Path $AgentOSRoot "scripts\rebuild_active_task_index.ps1") `
            -AgentOSRoot $fixtureRoot -TasksRoot $tasksRoot -IndexPath $indexPath | Out-Null

        $baseline = Measure-Latencies {
            @(Get-ChildItem -LiteralPath $tasksRoot -Directory | ForEach-Object {
                $path = Join-Path $_.FullName "TASK.md"
                $text = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
                [pscustomobject]@{
                    Id = Get-Field $text "dispatch_id"
                    Status = Get-Field $text "dispatch_status"
                    Parent = Get-Field $text "parent_dispatch_id"
                    Route = Get-Field $text "route_to"
                }
            })
        } $Runs
        $indexed = Measure-Latencies {
            $null = (Get-Item -LiteralPath $tasksRoot).LastWriteTimeUtc
            $index = [IO.File]::ReadAllText($indexPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
            $tasks = @($index.tasks | ForEach-Object {
                $metadataText = @(
                    "dispatch_id: $($_.dispatch_id)"
                    "dispatch_status: $($_.dispatch_status)"
                    "task_status: $($_.task_status)"
                    "type: $($_.type)"
                    "route_to: $($_.route_to)"
                    "depends_on: $($_.depends_on)"
                    "parent_dispatch_id: $($_.parent_dispatch_id)"
                    "revision_of: $($_.revision_of)"
                    "source_dispatch_id: $($_.source_dispatch_id)"
                    "dependency_order: $($_.dependency_order)"
                    "revision_round: $($_.revision_round)"
                    "task_type: $($_.task_type)"
                    "risk_level: $($_.risk_level)"
                    "codex_mode: $($_.codex_mode)"
                    "governance_version: $($_.governance_version)"
                    "governance_hash: $($_.governance_hash)"
                ) -join [Environment]::NewLine
                [pscustomobject]@{
                    Id = $_.dispatch_id
                    Status = $_.dispatch_status
                    Parent = $_.parent_dispatch_id
                    RevisionOf = $_.revision_of
                    SourceDispatch = $_.source_dispatch_id
                    Route = $_.route_to
                    Path = $_.task_path
                    Text = $metadataText
                    IndexedMtimeUtcTicks = [long]$_.task_mtime_utc_ticks
                    IndexedLength = [long]$_.task_length
                }
            })
            $ids = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            $null = $ids.Add("synthetic-0")
            $changed = $true
            while ($changed) {
                $changed = $false
                foreach ($task in $tasks) {
                    if ($ids.Contains($task.Id)) { continue }
                    if (($task.Parent -and $ids.Contains($task.Parent)) -or
                        ($task.RevisionOf -and $ids.Contains($task.RevisionOf)) -or
                        ($task.SourceDispatch -eq "synthetic-0")) {
                        $null = $ids.Add($task.Id)
                        $changed = $true
                    }
                }
            }
            # Measure the normal throttled loop path. Periodic full sweeps are
            # correctness maintenance and are excluded from this steady-state
            # latency comparison, as index rebuilds are.
            foreach ($task in @($tasks | Where-Object { $ids.Contains($_.Id) })) {
                $item = Get-Item -LiteralPath $task.Path
                $null = $item.LastWriteTimeUtc.Ticks -ne $task.IndexedMtimeUtcTicks
                $null = [long]$item.Length -ne $task.IndexedLength
            }
        } $Runs
        $results.Add([ordered]@{
            scale = "${scale}x"
            directory_count = $target
            runs = $Runs
            baseline_ms = @($baseline | ForEach-Object { [math]::Round($_, 3) })
            indexed_ms = @($indexed | ForEach-Object { [math]::Round($_, 3) })
            baseline_p95_ms = Get-P95 $baseline
            indexed_p95_ms = Get-P95 $indexed
            p95_improvement_ratio = [math]::Round((Get-P95 $baseline) / (Get-P95 $indexed), 2)
        })
    }
    $report = [ordered]@{
        measured_at = (Get-Date -Format o)
        method = "One warm-up followed by $Runs measured runs per scale; nearest-rank p95."
        baseline = "Enumerate every directory, read every TASK.md, and regex-parse routing metadata."
        indexed = "Actual-path equivalent for a normal throttled loop: stat TasksRoot, deserialize index, run unchanged root-scope BFS, and stat scoped TASK.md files; periodic full sweep and index rebuild excluded."
        current_directory_count = $currentCount
        fixture_root = $fixtureRoot
        results = $results
    }
    $json = $report | ConvertTo-Json -Depth 6
    if ($OutputPath) {
        $outputParent = Split-Path -Parent $OutputPath
        if ($outputParent) { New-Item -ItemType Directory -Force -Path $outputParent | Out-Null }
        [IO.File]::WriteAllText($OutputPath, $json, $utf8NoBom)
    }
    Write-Output $json
} finally {
    if (Test-Path -LiteralPath $fixtureRoot -PathType Container) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
    Write-Output "fixture_cleanup_path=$fixtureRoot"
    Write-Output "fixture_cleanup_confirmed=$(-not (Test-Path -LiteralPath $fixtureRoot))"
}

[CmdletBinding()]
param([string]$AgentOSRoot = "E:\AgentOS")

$ErrorActionPreference = "Stop"
$utf8NoBom = [Text.UTF8Encoding]::new($false)
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) "AgentOS-queue-reparent-$PID-$([guid]::NewGuid().ToString('N'))"
$tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
$resolvedFixture = [IO.Path]::GetFullPath($fixtureRoot)
if (-not $resolvedFixture.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "unsafe fixture path: $resolvedFixture"
}

function Write-FixtureTask {
    param(
        [string]$Id,
        [string]$Parent = "none",
        [string]$RevisionOf = "none",
        [string]$SourceDispatch = "none"
    )
    $directory = Join-Path $fixtureRoot "data\codex_tasks\$Id"
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $text = @"
dispatch_id: $Id
parent_dispatch_id: $Parent
revision_of: $RevisionOf
source_dispatch_id: $SourceDispatch
dependency_order: 0
depends_on: none
type: FIXTURE
route_to: Hermes
task_status: completed
dispatch_status: completed
governance_version: 1.3.0
governance_hash: fixture
"@
    [IO.File]::WriteAllText((Join-Path $directory "TASK.md"), $text, $utf8NoBom)
}

function Get-FixtureScopedCount {
    $tasks = @(Get-AllTasks)
    return @(Get-ScopedTasks $tasks "fixture-root").Count
}

function Assert-ScopedCount([int]$Expected) {
    $actual = Get-FixtureScopedCount
    if ($actual -ne $Expected) {
        throw "expected scoped count $Expected; actual=$actual"
    }
}

function Invoke-MockedIntervalExpiry {
    $script:LastFullSweepUtc = [datetime]::UtcNow.AddSeconds(-($FullSweepIntervalSeconds + 1))
}

function Set-ExistingTaskField {
    param([string]$Id, [string]$Field, [string]$Value)
    $path = Join-Path $fixtureRoot "data\codex_tasks\$Id\TASK.md"
    $before = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
    $after = [regex]::Replace(
        $before,
        "(?mi)^" + [regex]::Escape($Field) + "\s*:\s*.+$",
        "${Field}: $Value"
    )
    if ($after -eq $before) { throw "field edit did not change $Id/$Field" }
    [IO.File]::WriteAllText($path, $after, $utf8NoBom)
}

try {
    New-Item -ItemType Directory -Force -Path (Join-Path $fixtureRoot "scripts\lib") | Out-Null
    Copy-Item -LiteralPath (Join-Path $AgentOSRoot "scripts\task_queue_runner.ps1") `
        -Destination (Join-Path $fixtureRoot "scripts\task_queue_runner.ps1")
    Copy-Item -LiteralPath (Join-Path $AgentOSRoot "scripts\rebuild_active_task_index.ps1") `
        -Destination (Join-Path $fixtureRoot "scripts\rebuild_active_task_index.ps1")
    Copy-Item -LiteralPath (Join-Path $AgentOSRoot "scripts\escalation_receipt_validation.ps1") `
        -Destination (Join-Path $fixtureRoot "scripts\escalation_receipt_validation.ps1")
    Copy-Item -LiteralPath (Join-Path $AgentOSRoot "scripts\lib\global_jsonl_lock.ps1") `
        -Destination (Join-Path $fixtureRoot "scripts\lib\global_jsonl_lock.ps1")

    Write-FixtureTask "fixture-root"
    Write-FixtureTask "parent-candidate" -Parent "unrelated-parent"
    Write-FixtureTask "revision-candidate" -RevisionOf "unrelated-revision"
    Write-FixtureTask "source-candidate" -SourceDispatch "unrelated-source"

    $tasksRoot = Join-Path $fixtureRoot "data\codex_tasks"
    $directoryCount = @(Get-ChildItem -LiteralPath $tasksRoot -Directory).Count
    $runner = Join-Path $fixtureRoot "scripts\task_queue_runner.ps1"
    $runnerText = [IO.File]::ReadAllText($runner, [Text.Encoding]::UTF8)
    $mainMarker = 'New-Item -ItemType Directory -Force -Path (Split-Path -Parent $QueueLog) | Out-Null'
    $mainOffset = $runnerText.IndexOf($mainMarker, [StringComparison]::Ordinal)
    if ($mainOffset -lt 0) { throw "runner main marker not found" }
    $functionsOnlyPath = Join-Path $fixtureRoot "scripts\runner_functions.ps1"
    [IO.File]::WriteAllText(
        $functionsOnlyPath,
        $runnerText.Substring(0, $mainOffset),
        $utf8NoBom
    )
    . $functionsOnlyPath -AgentOSRoot $fixtureRoot -RootDispatchId "fixture-root" `
        -FullSweepIntervalSeconds 60

    New-Item -ItemType Directory -Force -Path (Join-Path $fixtureRoot "logs") | Out-Null
    Assert-ScopedCount 1
    $queueLogPath = Join-Path $fixtureRoot "logs\task-queue.log"

    Set-ExistingTaskField "parent-candidate" "parent_dispatch_id" "fixture-root"
    if (@(Get-ChildItem -LiteralPath $tasksRoot -Directory).Count -ne $directoryCount) {
        throw "directory count changed during parent_dispatch_id edit"
    }
    Assert-ScopedCount 1
    Invoke-MockedIntervalExpiry
    Assert-ScopedCount 2

    Set-ExistingTaskField "revision-candidate" "revision_of" "fixture-root"
    if (@(Get-ChildItem -LiteralPath $tasksRoot -Directory).Count -ne $directoryCount) {
        throw "directory count changed during revision_of edit"
    }
    Assert-ScopedCount 2
    Invoke-MockedIntervalExpiry
    Assert-ScopedCount 3

    Set-ExistingTaskField "source-candidate" "source_dispatch_id" "fixture-root"
    if (@(Get-ChildItem -LiteralPath $tasksRoot -Directory).Count -ne $directoryCount) {
        throw "directory count changed during source_dispatch_id edit"
    }
    Assert-ScopedCount 3
    Invoke-MockedIntervalExpiry
    Assert-ScopedCount 4

    $queueLog = [IO.File]::ReadAllText(
        $queueLogPath,
        [Text.Encoding]::UTF8
    )
    $incrementalEvents = [regex]::Matches(
        $queueLog,
        'status=index_rebuild_triggered detail=reason=scoped_task_metadata_changed mode=incremental'
    ).Count
    if ($incrementalEvents -ne 3) {
        throw "expected 3 incremental metadata rebuilds; actual=$incrementalEvents"
    }
    $fullSweepEvents = [regex]::Matches(
        $queueLog,
        'status=full_sweep_completed'
    ).Count
    if ($fullSweepEvents -ne 4) {
        throw "expected startup plus 3 expired-interval full sweeps; actual=$fullSweepEvents"
    }

    Write-Output "queue_index_reparenting_staleness=PASS"
    Write-Output "parent_dispatch_id_reparenting=true"
    Write-Output "revision_of_reparenting=true"
    Write-Output "source_dispatch_id_reparenting=true"
    Write-Output "directory_count_unchanged=true"
    Write-Output "incremental_metadata_rebuilds=$incrementalEvents"
    Write-Output "throttle_window_skipped_full_sweep=true"
    Write-Output "full_sweep_events=$fullSweepEvents"
    Write-Output "interval_expiry_mode=mocked_LastFullSweepUtc"
} finally {
    if (Test-Path -LiteralPath $fixtureRoot -PathType Container) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
    Write-Output "fixture_cleanup_path=$fixtureRoot"
    Write-Output "fixture_cleanup_confirmed=$(-not (Test-Path -LiteralPath $fixtureRoot))"
}

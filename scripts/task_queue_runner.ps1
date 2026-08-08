[CmdletBinding()]
param(
    [string]$AgentOSRoot = "E:\AgentOS",
    [Parameter(Mandatory = $true)]
    [string]$RootDispatchId,
    [switch]$ValidateOnly,
    [switch]$Once,
    [int]$PollSeconds = 5,
    [int]$MaxTasksPerRun = 20,
    [int]$MaxAttemptsPerRoute = 2,
    [string]$DispatcherPath = "",
    [int]$FullSweepIntervalSeconds = 60,
    [ValidateSet("ci", "runtime")]
    [string]$Environment = "runtime"
)

$ErrorActionPreference = "Stop"
$Utf8NoBom = [Text.UTF8Encoding]::new($false)
$TasksRoot = Join-Path $AgentOSRoot "data\codex_tasks"
$Dispatcher = if ($DispatcherPath) { (Resolve-Path -LiteralPath $DispatcherPath).Path } else { Join-Path $AgentOSRoot "scripts\dispatch_task_packet.ps1" }
$Gate = Join-Path $AgentOSRoot "scripts\assert_governance_ready.ps1"
$QueueLog = Join-Path $AgentOSRoot "logs\task-queue.log"
$QueueStatePath = Join-Path $AgentOSRoot (Join-Path "data\queue_runs" "$RootDispatchId.json")
$TaskIndexPath = Join-Path $AgentOSRoot "data\queue_runs\ACTIVE_TASK_INDEX.json"
$TaskIndexRebuildScript = Join-Path $AgentOSRoot "scripts\rebuild_active_task_index.ps1"
$script:LoopScanMilliseconds = 0.0
$script:LoopDirectoryCount = 0
$script:LoopIndexRebuilds = 0
# MinValue forces a full sweep on the very first Get-AllTasks call in this
# process (correct-by-default on startup), then throttled to at most once
# per $FullSweepIntervalSeconds after that. See Get-AllTasks for why this
# exists (2026-07-29, AC1 reparenting-staleness fix + benchmark regression).
$script:LastFullSweepUtc = [datetime]::MinValue
. (Join-Path $AgentOSRoot "scripts\escalation_receipt_validation.ps1")
. (Join-Path $AgentOSRoot "scripts\lib\global_jsonl_lock.ps1")

function Get-Field([string]$Text, [string]$Name) {
    $match = [regex]::Match(
        $Text,
        "(?mi)^\s*" + [regex]::Escape($Name) + "\s*[:=]\s*(.+?)\s*$"
    )
    if ($match.Success) { return $match.Groups[1].Value.Trim().Trim('"').Trim("'") }
    return ""
}

function Read-Utf8([string]$Path) {
    return [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
}

function Write-Utf8([string]$Path, [string]$Text) {
    $parent = Split-Path -Parent $Path
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    [IO.File]::WriteAllText($Path, $Text, $Utf8NoBom)
}

function Write-QueueEvent([string]$DispatchId, [string]$Status, [string]$Detail) {
    $line = "$(Get-Date -Format o) dispatch_id=$DispatchId status=$Status detail=$Detail"
    $pending = $line + [Environment]::NewLine
    Invoke-GlobalJsonlLockedAppend -LiteralPath $QueueLog -PendingContent $pending -AppendAction {
        [IO.File]::AppendAllText($QueueLog, $pending, $Utf8NoBom)
    }
    Write-Output $line
}

function Get-EscalationDecisionGate([string]$DispatchId) {
    $safeId = Get-AgentOSEscalationSafeId $DispatchId
    $dir = Join-Path $AgentOSRoot "data\escalations\$safeId"
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
        return [pscustomobject]@{ HasEscalation=$false; Valid=$true; Reason='no_escalation' }
    }
    $events = @(Get-ChildItem -LiteralPath $dir -Filter '*.json' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike 'DECISION-*' -and $_.Name -notlike 'RESOLUTION*' })
    if (-not $events) {
        return [pscustomobject]@{ HasEscalation=$false; Valid=$true; Reason='no_escalation_event' }
    }
    $decisions = @(Get-ChildItem -LiteralPath $dir -Filter 'DECISION-*.json' -File -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending)
    if (-not $decisions) {
        return [pscustomobject]@{ HasEscalation=$true; Valid=$false; Reason='escalation_awaiting_josh:no_decision_receipt' }
    }
    $lastReason = 'decision_record_invalid'
    foreach ($path in $decisions) {
        try {
            $record = [IO.File]::ReadAllText($path.FullName, [Text.Encoding]::UTF8) | ConvertFrom-Json
            $validation = Test-AgentOSEscalationDecisionRecord -AgentOSRoot $AgentOSRoot -DecisionRecord $record
            if ($validation.Valid) {
                return [pscustomobject]@{
                    HasEscalation=$true; Valid=$true; Reason='verified_owner_decision'
                    Decision=[string]$record.decision; DecisionPath=$path.FullName
                }
            }
            $lastReason = [string]$validation.Reason
        } catch {
            $lastReason = 'decision_json_invalid'
        }
    }
    return [pscustomobject]@{
        HasEscalation=$true; Valid=$false
        Reason="escalation_decision_receipt_invalid:$lastReason"
    }
}

function Test-TaskRequiresEscalationGate([object]$Task) {
    if (-not $Task) { return $false }
    return $Task.Status -eq 'escalation_required' -or $Task.TaskStatus -eq 'blocked'
}

function Set-QueueRunState([string]$Status, [string]$Detail = "") {
    if (-not (Test-Path -LiteralPath $QueueStatePath -PathType Leaf)) { return }
    try {
        $state = Get-Content -Raw -LiteralPath $QueueStatePath -Encoding UTF8 |
            ConvertFrom-Json
        $state.status = $Status
        $state | Add-Member -NotePropertyName "finished_at" `
            -NotePropertyValue (Get-Date -Format o) -Force
        $state | Add-Member -NotePropertyName "detail" `
            -NotePropertyValue $Detail -Force
        Write-Utf8 $QueueStatePath ($state | ConvertTo-Json -Depth 6)
    } catch {
        Write-QueueEvent "queue" "state_update_failed" $_.Exception.Message
    }
}

function Get-TaskPath([string]$DispatchId) {
    return Join-Path $TasksRoot (Join-Path $DispatchId "TASK.md")
}

function Get-ResultPath([string]$DispatchId) {
    return Join-Path $TasksRoot (Join-Path $DispatchId "OUTPUTS\RESULT.md")
}

function Get-ReviewFlowPath([string]$DispatchId) {
    return Join-Path $TasksRoot (Join-Path $DispatchId "OUTPUTS\REVIEW_FLOW_STATUS.md")
}

function Invoke-TaskIndexRebuild(
    [string]$Reason,
    [string[]]$TaskPaths = @()
) {
    $mode = if ($TaskPaths.Count) { "incremental" } else { "full" }
    Write-QueueEvent $RootDispatchId "index_rebuild_triggered" `
        "reason=$Reason mode=$mode index_path=$TaskIndexPath" | Out-Null
    $arguments = @{
        AgentOSRoot = $AgentOSRoot
        TasksRoot = $TasksRoot
        IndexPath = $TaskIndexPath
    }
    if ($TaskPaths.Count) { $arguments.TaskPaths = $TaskPaths }
    try {
        $output = & $TaskIndexRebuildScript @arguments 2>&1
    } catch {
        $detail = $_.Exception.Message
        Write-QueueEvent $RootDispatchId "index_rebuild_failed" `
            "reason=$Reason mode=$mode error=$detail" | Out-Null
        throw "task index rebuild failed: $detail"
    }
    $script:LoopIndexRebuilds++
    Write-QueueEvent $RootDispatchId "index_rebuild_completed" `
        "reason=$Reason mode=$mode index_path=$TaskIndexPath" | Out-Null
}

function Convert-IndexEntryToTask([object]$Entry) {
    $metadataText = @(
        "dispatch_id: $($Entry.dispatch_id)"
        "dispatch_status: $($Entry.dispatch_status)"
        "task_status: $($Entry.task_status)"
        "type: $($Entry.type)"
        "route_to: $($Entry.route_to)"
        "depends_on: $($Entry.depends_on)"
        "parent_dispatch_id: $($Entry.parent_dispatch_id)"
        "revision_of: $($Entry.revision_of)"
        "source_dispatch_id: $($Entry.source_dispatch_id)"
        "dependency_order: $($Entry.dependency_order)"
        "revision_round: $($Entry.revision_round)"
        "task_type: $($Entry.task_type)"
        "risk_level: $($Entry.risk_level)"
        "codex_mode: $($Entry.codex_mode)"
        "governance_version: $($Entry.governance_version)"
        "governance_hash: $($Entry.governance_hash)"
    ) -join [Environment]::NewLine
    return [pscustomobject]@{
        Id = [string]$Entry.dispatch_id
        Path = [string]$Entry.task_path
        Text = $metadataText
        Status = [string]$Entry.dispatch_status
        TaskStatus = [string]$Entry.task_status
        Type = [string]$Entry.type
        Route = [string]$Entry.route_to
        DependsOn = [string]$Entry.depends_on
        Parent = [string]$Entry.parent_dispatch_id
        SourceDispatch = [string]$Entry.source_dispatch_id
        RevisionOf = [string]$Entry.revision_of
        RevisionRound = [int]$Entry.revision_round
        Order = [int]$Entry.dependency_order
        IndexedMtimeUtcTicks = [long]$Entry.task_mtime_utc_ticks
        IndexedLength = [long]$Entry.task_length
    }
}

function Read-TaskIndex {
    return [IO.File]::ReadAllText($TaskIndexPath, [Text.Encoding]::UTF8) |
        ConvertFrom-Json
}

function Get-AllTasks {
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    try {
        if (-not (Test-Path -LiteralPath $TasksRoot -PathType Container)) {
            $script:LoopDirectoryCount = 0
            return @()
        }
        if (-not (Test-Path -LiteralPath $TaskIndexPath -PathType Leaf)) {
            Invoke-TaskIndexRebuild "index_missing"
        }
        $index = Read-TaskIndex
        if ([int]$index.schema_version -ne 3) {
            Invoke-TaskIndexRebuild "schema_version_mismatch"
            $index = Read-TaskIndex
        }
        $tasksRootMtimeTicks = (Get-Item -LiteralPath $TasksRoot).LastWriteTimeUtc.Ticks
        if ($tasksRootMtimeTicks -ne [long]$index.tasks_root_mtime_utc_ticks) {
            Invoke-TaskIndexRebuild "tasks_root_changed"
            $index = Read-TaskIndex
        }
        $script:LoopDirectoryCount = [int]$index.directory_count

        $tasks = @($index.tasks | ForEach-Object { Convert-IndexEntryToTask $_ })
        # 2026-07-29 history: AC1 finding on queue-active-index-optimization
        # revision-3 fresh Verify FAIL said staleness must be checked against
        # EVERY indexed entry, not just the subset already believed to be in
        # this root's scope - a task manually re-parented INTO this root
        # (via editing parent_dispatch_id/revision_of/source_dispatch_id,
        # with no directory created/deleted) was never a member of the OLD
        # scoped subset, so it was never staleness-checked and stayed
        # silently excluded until an unrelated full rebuild happened to
        # catch it. The first fix checked all indexed entries on every
        # single loop - that closed the correctness gap but a real benchmark
        # showed it made the 10x-scale case SLOWER than the original
        # unoptimized full-parse baseline (p95 ratio dropped from 1.97 to
        # 0.67), defeating the point of this whole ticket. Per-file stat
        # calls at thousands-of-files scale are not as cheap as they looked
        # on paper.
        #
        # Revised fix (Josh's choice after seeing the regression): keep the
        # cheap scoped-only check as the per-loop default (this is what
        # restores the original performance characteristics), and run the
        # full all-entries sweep only periodically, throttled to at most
        # once every $FullSweepIntervalSeconds (default 60s). This bounds
        # re-parenting detection to "within at most ~60 seconds" instead of
        # "next loop" - an accepted trade-off since re-parenting only
        # happens via manual TASK.md edits, not as part of normal dispatch
        # flow, so near-immediate detection was never actually required.
        $nowUtc = [datetime]::UtcNow
        $dueForFullSweep = ($nowUtc - $script:LastFullSweepUtc).TotalSeconds -ge $FullSweepIntervalSeconds
        $checkSet = if ($dueForFullSweep) { $tasks } else { @(Get-ScopedTasks $tasks $RootDispatchId) }
        $stalePaths = [Collections.Generic.List[string]]::new()
        foreach ($task in $checkSet) {
            if (-not (Test-Path -LiteralPath $task.Path -PathType Leaf)) {
                $stalePaths.Add($task.Path)
                continue
            }
            $item = Get-Item -LiteralPath $task.Path
            if ($item.LastWriteTimeUtc.Ticks -ne $task.IndexedMtimeUtcTicks -or
                [long]$item.Length -ne $task.IndexedLength) {
                $stalePaths.Add($task.Path)
            }
        }
        if ($stalePaths.Count) {
            Invoke-TaskIndexRebuild "scoped_task_metadata_changed" $stalePaths.ToArray()
            $index = Read-TaskIndex
            $tasks = @($index.tasks | ForEach-Object { Convert-IndexEntryToTask $_ })
        }
        if ($dueForFullSweep) {
            $script:LastFullSweepUtc = $nowUtc
            Write-QueueEvent $RootDispatchId "full_sweep_completed" `
                "checked_count=$($checkSet.Count);stale_count=$($stalePaths.Count)" | Out-Null
        }
        return $tasks
    } finally {
        $stopwatch.Stop()
        $script:LoopScanMilliseconds += $stopwatch.Elapsed.TotalMilliseconds
    }
}

function Write-LoopScanEvent([object[]]$ScopedTasks) {
    $scanMs = [math]::Round($script:LoopScanMilliseconds, 3)
    Write-QueueEvent $RootDispatchId "queue_scan" `
        "scan_ms=$scanMs directory_count=$script:LoopDirectoryCount scoped_task_count=$($ScopedTasks.Count) index_rebuilds=$script:LoopIndexRebuilds"
}

function Get-ScopedTasks([object[]]$Tasks, [string]$RootId) {
    $ids = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )
    $null = $ids.Add($RootId)
    $changed = $true
    while ($changed) {
        $changed = $false
        foreach ($task in $Tasks) {
            if ($ids.Contains($task.Id)) { continue }
            if (($task.Parent -and $ids.Contains($task.Parent)) -or
                ($task.RevisionOf -and $ids.Contains($task.RevisionOf)) -or
                ($task.SourceDispatch -eq $RootId)) {
                $null = $ids.Add($task.Id)
                $changed = $true
            }
        }
    }
    return @($Tasks | Where-Object { $ids.Contains($_.Id) })
}

function Get-ResultStatus([string]$DispatchId) {
    $path = Get-ResultPath $DispatchId
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return "" }
    return Get-Field (Read-Utf8 $path) "status"
}

function Get-AttemptLogPath([string]$DispatchId) {
    return Join-Path $TasksRoot (Join-Path $DispatchId "OUTPUTS\DISPATCH_ATTEMPTS.jsonl")
}

function Get-Attempts([string]$DispatchId) {
    $path = Get-AttemptLogPath $DispatchId
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }
    return @(Get-Content -LiteralPath $path -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object {
        try { $_ | ConvertFrom-Json } catch { $null }
    } | Where-Object { $null -ne $_ })
}

function Write-Attempt(
    [object]$Task,
    [int]$ExitCode,
    [string]$Reason,
    [string]$Phase,
    [string]$Artifact
) {
    $record = [ordered]@{
        timestamp = (Get-Date -Format o)
        dispatch_id = $Task.Id
        route_to = $Task.Route
        codex_mode = Get-Field $Task.Text "codex_mode"
        exit_code = $ExitCode
        reason = $Reason
        phase = $Phase
        artifact = $Artifact
    } | ConvertTo-Json -Compress
    $attemptLogPath = Get-AttemptLogPath $Task.Id
    $pending = $record + [Environment]::NewLine
    Invoke-GlobalJsonlLockedAppend -LiteralPath $attemptLogPath -PendingContent $pending -AppendAction {
        [IO.File]::AppendAllText($attemptLogPath, $pending, $Utf8NoBom)
    }
}

function Set-OrAddField([string]$Text, [string]$Name, [string]$Value) {
    $pattern = '(?mi)^\s*' + [regex]::Escape($Name) + '\s*:\s*.*$'
    if ([regex]::IsMatch($Text, $pattern)) {
        return [regex]::Replace($Text, $pattern, "${Name}: $Value")
    }
    return $Text.TrimEnd() + "`r`n${Name}: $Value`r`n"
}

function Set-TaskRoute([object]$Task, [string]$Route, [string]$Type, [string]$AssignedTo, [string]$CodexMode) {
    $text = Read-Utf8 $Task.Path
    if (-not (Get-Field $text "original_route_to")) {
        $text = Set-OrAddField $text "original_route_to" $Task.Route
    }
    $text = Set-OrAddField $text "route_to" $Route
    $text = Set-OrAddField $text "type" $Type
    $text = Set-OrAddField $text "assigned_to" $AssignedTo
    $text = Set-OrAddField $text "codex_mode" $CodexMode
    $text = Set-OrAddField $text "dispatch_status" "ready_to_route"
    $text = Set-OrAddField $text "task_status" "fallback_ready"
    $text = Set-OrAddField $text "fallback_from" $Task.Route
    Write-Utf8 $Task.Path $text
}

function Get-RouteKey([string]$Route, [string]$CodexMode) {
    return ($Route + ":" + $CodexMode).ToLowerInvariant()
}

function Get-FallbackSpec([object]$Task, [object[]]$Attempts) {
    $taskType = Get-Field $Task.Text "task_type"
    $riskLevel = Get-Field $Task.Text "risk_level"
    if ($taskType -eq "Risky" -or $riskLevel -in @("medium", "high", "risky")) { return $null }
    $mode = ([string](Get-Field $Task.Text "codex_mode")).ToLowerInvariant()
    $candidate = $null
    if ($Task.Route -eq "Claude") {
        $candidate = [pscustomobject]@{ Route="Codex"; Type="CODEX_BUILD"; AssignedTo="Codex"; CodexMode="build" }
    } elseif ($Task.Route -eq "Codex" -and $mode -eq "build") {
        $candidate = [pscustomobject]@{ Route="Claude"; Type="CLAUDE_WORKER"; AssignedTo="Claude Worker"; CodexMode="n/a" }
    } elseif ($Task.Route -eq "Antigravity CLI") {
        $candidate = [pscustomobject]@{ Route="Codex"; Type="CODEX_BUILD"; AssignedTo="Codex"; CodexMode="build" }
    }
    if (-not $candidate) { return $null }
    $candidateKey = Get-RouteKey $candidate.Route $candidate.CodexMode
    $usedKeys = @($Attempts | ForEach-Object { Get-RouteKey ([string]$_.route_to) ([string]$_.codex_mode) })
    if ($candidateKey -in $usedKeys) { return $null }
    return $candidate
}

function Test-RecoverableFailure([string]$Reason) {
    return $Reason -notin @(
        "governance_gate_blocked", "task_governance_binding_missing",
        "invalid_codex_mode", "unsupported_route", "config_file_missing"
    )
}

function Get-VerifyVerdict([string]$VerifyId) {
    $path = Get-ResultPath $VerifyId
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return "" }
    $text = Read-Utf8 $path
    $match = [regex]::Match(
        $text,
        '(?mi)^verify_verdict\s*:\s*(PASS|FAIL|NEEDS_HUMAN_DECISION)\s*$'
    )
    if ($match.Success) { return $match.Groups[1].Value.ToUpperInvariant() }
    return "invalid"
}

function Get-FailurePatternKey([string]$VerifyId, [string]$OriginalId) {
    # Deterministic failure-pattern extraction for the learning loop.
    # No model calls; pure regex over existing artifacts. The key feeds
    # METRICS_LOG.fail_reason so collect_learning_candidates.ps1 can cluster
    # recurring patterns (threshold >= 2) without manual review.
    $verifyPath = Get-ResultPath $VerifyId
    $verifyText = if (Test-Path -LiteralPath $verifyPath -PathType Leaf) {
        Read-Utf8 $verifyPath
    } else { "" }
    $workerPath = Get-ResultPath $OriginalId
    $workerText = if (Test-Path -LiteralPath $workerPath -PathType Leaf) {
        Read-Utf8 $workerPath
    } else { "" }
    $originalTaskPath = Get-TaskPath $OriginalId
    $taskText = if (Test-Path -LiteralPath $originalTaskPath -PathType Leaf) {
        Read-Utf8 $originalTaskPath
    } else { "" }

    # garbled request accusation (luan-ma / cannot-recognize / garbled)
    if ($verifyText -match '\u4E82\u78BC|\u7121\u6CD5[\u53EF\u9760]{0,2}\u8FA8\u8B58|garbled|mojibake') {
        return "verify_false_fail_garbled_request"
    }
    # info query delivered by a workspace_change packet (misroute signature):
    # worker declared change_required false and talked about web search/query
    if ($taskText -match '(?mi)^task_kind\s*:\s*workspace_change\b' -and
        $workerText -match '(?mi)^[\s>*_-]*change_required\s*[:\uFF1A]\s*\*{0,2}false\b' -and
        $workerText -match 'WebSearch|\u7DB2\u8DEF\u641C\u5C0B|\u67E5\u8A62|\u641C\u5C0B') {
        return "info_query_misrouted_to_workspace_worker"
    }
    # missing test evidence (test_status: missing / que-shao ... yan-zheng)
    if ($verifyText -match 'test_status\s*:\s*missing|\u7F3A\u5C11[^\r\n]{0,10}\u9A57\u8B49|TEST_RESULT') {
        return "verify_fail_missing_test_evidence"
    }
    return "verify_fail_unclassified"
}

function Get-FailedVerifyId([string]$OriginalId, [int]$PassRound) {
    # The verify that FAILed before a round-N PASS belongs to round N-1
    # (round 0 = the original dispatch).
    if ($PassRound -ge 2) {
        return "$OriginalId-revision-$($PassRound - 1)-codex-verify"
    }
    return "$OriginalId-codex-verify"
}

function Find-Verify([object[]]$Tasks, [string]$ParentId) {
    return $Tasks |
        Where-Object { $_.Type -eq "CODEX_VERIFY" -and $_.Parent -eq $ParentId } |
        Sort-Object Id -Descending |
        Select-Object -First 1
}

function Find-LatestRevision([object[]]$Tasks, [string]$OriginalId) {
    return $Tasks |
        Where-Object {
            $_.RevisionOf -eq $OriginalId -and
            $_.Status -notin @("superseded_queue_bug", "blocked_review_disagreement")
        } |
        Sort-Object RevisionRound -Descending |
        Select-Object -First 1
}

function Get-OriginalDispatchId([object[]]$Tasks, [object]$Task) {
    if ($Task.RevisionOf) { return $Task.RevisionOf }
    if ($Task.Type -eq "CODEX_VERIFY" -and $Task.Parent) {
        $parent = $Tasks | Where-Object { $_.Id -eq $Task.Parent } | Select-Object -First 1
        if ($parent -and $parent.RevisionOf) { return $parent.RevisionOf }
        return $Task.Parent
    }
    return $Task.Id
}

function Write-ReviewFlowStatus(
    [string]$OriginalId,
    [string]$VerifyId,
    [string]$Decision,
    [string]$State,
    [string]$Detail,
    [int]$RevisionRound
) {
    $path = Get-ReviewFlowPath $OriginalId
    $content = @"
# AgentOS Review Flow Status

dispatch_id: $OriginalId
latest_verify_dispatch_id: $VerifyId
verify_verdict: $Decision
review_flow_state: $State
revision_round: $RevisionRound
updated_at: $(Get-Date -Format o)

## Audit Marker

$State

## Detail

$Detail
"@
    Write-Utf8 $path $content
}

function Test-Approved([object[]]$Tasks, [string]$DispatchId) {
    if ((Get-ResultStatus $DispatchId) -ne "completed") { return $false }
    $task = $Tasks | Where-Object { $_.Id -eq $DispatchId } | Select-Object -First 1
    if ($task -and $task.Type -eq "CODEX_VERIFY") {
        $decision = Get-VerifyVerdict $DispatchId
        if ($decision -eq "PASS") { return $true }
        if ($decision -eq "FAIL" -and $task.Parent) {
            $revision = Find-LatestRevision $Tasks $task.Parent
            if ($revision) { return Test-Approved $Tasks $revision.Id }
        }
        return $false
    }
    $review = Find-Verify $Tasks $DispatchId
    if (-not $review) { return $true }
    $decision = Get-VerifyVerdict $review.Id
    if ($decision -eq "PASS") { return $true }
    if ($decision -eq "FAIL") {
        $revision = Find-LatestRevision $Tasks $DispatchId
        if ($revision) { return Test-Approved $Tasks $revision.Id }
    }
    return $false
}

function Set-TaskState([string]$TaskPath, [string]$DispatchStatus, [string]$TaskStatus) {
    $text = Read-Utf8 $TaskPath
    $text = [regex]::Replace(
        $text,
        '(?mi)^dispatch_status\s*:\s*.+$',
        "dispatch_status: $DispatchStatus"
    )
    $text = [regex]::Replace(
        $text,
        '(?mi)^task_status\s*:\s*.+$',
        "task_status: $TaskStatus"
    )
    Write-Utf8 $TaskPath $text
}

function Promote-Dependencies([object[]]$Tasks) {
    foreach ($task in $Tasks | Where-Object { $_.Status -eq "pending_dependency" }) {
        $dependency = $task.DependsOn
        $satisfied = $false
        if ($dependency -like "parent_created:*") {
            $parentId = $dependency.Substring("parent_created:".Length)
            $satisfied = Test-Path -LiteralPath (Get-TaskPath $parentId)
        } elseif ($dependency) {
            $satisfied = Test-Approved $Tasks $dependency
        }
        if ($satisfied) {
            Set-TaskState $task.Path "ready_to_route" "ready"
            Write-QueueEvent $task.Id "ready_to_route" "dependency_satisfied:$dependency"
        }
    }
}

function New-RevisionTask([object[]]$Tasks, [object]$VerifyTask) {
    $reviewedId = $VerifyTask.Parent
    $reviewedTask = $Tasks |
        Where-Object { $_.Id -eq $reviewedId } |
        Select-Object -First 1
    if (-not $reviewedTask) { return }
    $originalId = if ($reviewedTask.RevisionOf) {
        $reviewedTask.RevisionOf
    } else {
        $reviewedId
    }
    $existing = Find-LatestRevision $Tasks $originalId
    if (-not $reviewedTask.RevisionOf -and $existing) {
        # The original review already produced a revision. Wait for that
        # revision's own Claude review before creating another round.
        return
    }
    $round = if ($reviewedTask.RevisionOf) {
        $reviewedTask.RevisionRound + 1
    } else {
        1
    }
    $id = "$originalId-revision-$round"
    if (Test-Path -LiteralPath (Get-TaskPath $id)) { return }
    if ($round -gt 2) {
        # Added 2026-07-28 (Josh's finding on queue-active-index-optimization):
        # a resolved "Modify" escalation decision (recorded via
        # decide_escalation.ps1, receipt-verified as Josh's own action) was
        # sitting valid on disk, but nothing here ever consumed it - this
        # branch always re-escalated with revision_limit_reached regardless,
        # so `tasks_executed=0` forever even after Josh explicitly chose
        # Modify. "Modify" for an `accept_partial_delivery` escalation means
        # "adjust and retry", i.e. grant exactly one more revision round
        # beyond the normal 2-round cap.
        #
        # FIXED 2026-07-29 (Josh's finding, real production incident on the
        # same ticket): the first version of this fix keyed the consumption
        # marker to the ROUND NUMBER ("MODIFY_CONSUMED-round_$round.json").
        # That only prevented the SAME round from reusing a decision - it did
        # NOT prevent a single old decision from being replayed across
        # DIFFERENT round numbers, because round N+1 checks a marker file
        # named for round N+1, which doesn't exist yet, so the still-"Valid"
        # old decision passed the gate again and silently authorized round
        # N+1 with no new escalation and no new Josh decision. This is
        # exactly what happened: round 3 was legitimately unlocked by a
        # Modify decision; round 3's fresh Verify FAILed; round 4 was then
        # created and dispatched automatically using that same, already-spent
        # decision, with no Josh involvement, and it ran for hours before
        # timing out.
        #
        # The fix: track consumption by the DECISION itself (its
        # DecisionPath, which is unique per verified-owner decision record),
        # not by round number. A given decision may consume exactly one round
        # across the ENTIRE lifetime of this original_id, regardless of which
        # round number it happens to land on. Every additional round beyond
        # that requires a brand new escalation + a brand new Josh decision.
        $safeOriginalId = Get-AgentOSEscalationSafeId $originalId
        $escalationDir = Join-Path $AgentOSRoot "data\escalations\$safeOriginalId"
        $consumedMarkerPath = Join-Path $escalationDir "MODIFY_CONSUMED-round_$round.json"
        $gate = Get-EscalationDecisionGate $originalId
        $decisionAlreadyConsumed = $false
        if ($gate.Valid -and $gate.DecisionPath -and (Test-Path -LiteralPath $escalationDir -PathType Container)) {
            foreach ($markerFile in @(Get-ChildItem -LiteralPath $escalationDir -Filter "MODIFY_CONSUMED-*.json" -File -ErrorAction SilentlyContinue)) {
                try {
                    $markerRecord = [IO.File]::ReadAllText($markerFile.FullName, [Text.Encoding]::UTF8) | ConvertFrom-Json
                    if ([string]$markerRecord.decision_path -eq [string]$gate.DecisionPath) {
                        $decisionAlreadyConsumed = $true
                        break
                    }
                } catch {
                    continue
                }
            }
        }
        if ($gate.HasEscalation -and $gate.Valid -and $gate.Decision -eq "modify" -and
            -not $decisionAlreadyConsumed -and -not (Test-Path -LiteralPath $consumedMarkerPath)) {
            Write-Utf8 $consumedMarkerPath (([ordered]@{
                consumed_at = (Get-Date -Format o)
                decision_path = $gate.DecisionPath
                granted_round = $round
                original_id = $originalId
            } | ConvertTo-Json) + [Environment]::NewLine)
            Write-QueueEvent $originalId "revision_round_extended" "modify_decision_consumed:round_$round;decision_path=$($gate.DecisionPath)"
            # Fall through: do not escalate, proceed to create round $round below.
        } else {
            $original = $Tasks | Where-Object { $_.Id -eq $originalId } | Select-Object -First 1
            if ($original) {
                Set-TaskState $original.Path "escalation_required" "blocked"
            }
            Write-ReviewFlowStatus $originalId $VerifyTask.Id "FAIL" `
                "escalation_required" "revision_limit_reached" $reviewedTask.RevisionRound
            $taskType = Get-Field $original.Text "task_type"
            $source = if ($taskType -eq "Complex") { "complex_fail" } else { "simple_fail" }
            $escalationReason = if ($decisionAlreadyConsumed) { "revision_limit_reached_decision_already_consumed" } else { "revision_limit_reached" }
            & powershell.exe -NoProfile -ExecutionPolicy Bypass `
                -File (Join-Path $AgentOSRoot "scripts\write_escalation.ps1") `
                -TaskId $originalId -Source $source -Reason $escalationReason `
                -DecisionType "accept_partial_delivery" `
                -SummaryForJosh "Task $originalId failed Codex Verify after two Claude revisions." `
                -Evidence @((Get-ReviewFlowPath $originalId)) -AgentOSRoot $AgentOSRoot -Environment $Environment | Out-Null
            Write-QueueEvent $originalId "escalation_required" $escalationReason
            return
        }
    }
    $originalTaskPath = Get-TaskPath $originalId
    $reviewResultPath = Get-ResultPath $VerifyTask.Id
    $governanceVersion = Get-Field $VerifyTask.Text "governance_version"
    $governanceHash = Get-Field $VerifyTask.Text "governance_hash"
    $task = @"
# Task Packet: Claude Revision Round $round

dispatch_id: $id
parent_dispatch_id: $originalId
revision_of: $originalId
revision_round: $round
type: CLAUDE_WORKER
assigned_to: Claude Worker
route_to: Claude
codex_mode: n/a
workflow_version: 1.2
impact_scope: core_script
dispatch_status: ready_to_route
task_status: ready
requires_josh_approval: true
approval: inherited_from_original_dispatch
governance_version: $governanceVersion
governance_hash: $governanceHash

## Task

Read the original task and Codex Verify result:
- $originalTaskPath
- $reviewResultPath

Operation: revise_or_rebut_with_evidence.

Address the feedback, or rebut it with concrete file and verification evidence.
Do not exceed the original task scope.
Do not rewrite or delete prior RESULT, TEST_RESULT, or Verify artifacts.
Provide corrected evidence in this revision's own output contract.
If the underlying workspace requires no change, emit `change_required: false`.
"@
    Write-Utf8 (Get-TaskPath $id) $task
    Write-ReviewFlowStatus $originalId $VerifyTask.Id "FAIL" `
        "FAIL" "revision_created:round_$round; revision_dispatch_id=$id" $round
    Write-QueueEvent $id "ready_to_route" "revision_created:round_$round"
}

function Update-ReviewFlowStates([object[]]$Tasks) {
    foreach ($review in $Tasks | Where-Object { $_.Type -eq "CODEX_VERIFY" }) {
        if ((Get-ResultStatus $review.Id) -ne "completed") { continue }
        $decision = Get-VerifyVerdict $review.Id
        $reviewedTask = $Tasks |
            Where-Object { $_.Id -eq $review.Parent } |
            Select-Object -First 1
        if (-not $reviewedTask) { continue }
        $originalId = Get-OriginalDispatchId $Tasks $review
        $round = if ($reviewedTask.RevisionOf) { $reviewedTask.RevisionRound } else { 0 }

        if ($decision -eq "PASS") {
            Write-ReviewFlowStatus $originalId $review.Id $decision `
                "Codex Verify PASS" "approved_dependency_gate_open" $round
            $taskType = Get-Field $reviewedTask.Text "task_type"
            if (-not $taskType -and $reviewedTask.RevisionOf) {
                $original = $Tasks | Where-Object { $_.Id -eq $originalId } | Select-Object -First 1
                $taskType = Get-Field $original.Text "task_type"
            }
            $metricArgs = @(
                "-NoProfile", "-ExecutionPolicy", "Bypass",
                "-File", (Join-Path $AgentOSRoot "scripts\write_task_metric.ps1"),
                "-TaskId", $originalId,
                "-TaskType", $(if ($taskType) { $taskType } else { "unknown" }),
                "-Verdict", "PASS", "-RetryCount", $round,
                "-FinalStatus", "completed",
                "-AgentOSRoot", $AgentOSRoot
            )
            if ($round -ge 1) {
                # FAIL -> revision -> PASS trajectory: record the extracted
                # failure pattern so the learning collector can cluster it.
                # Extra nodes burned per round = revision + its verify (2).
                $failedVerifyId = Get-FailedVerifyId $originalId $round
                $metricArgs += @(
                    "-FailReason",
                    (Get-FailurePatternKey $failedVerifyId $originalId)
                )
            }
            & powershell.exe @metricArgs | Out-Null
            continue
        }

        if ($decision -eq "FAIL") {
            New-RevisionTask $Tasks $review
            continue
        }

        if ($decision -eq "NEEDS_HUMAN_DECISION") {
            $original = $Tasks | Where-Object { $_.Id -eq $originalId } | Select-Object -First 1
            if ($original) {
                Set-TaskState $original.Path "escalation_required" "blocked"
            }
            Write-ReviewFlowStatus $originalId $review.Id $decision `
                "escalation_required" "verify_needs_human" $round
            & powershell.exe -NoProfile -ExecutionPolicy Bypass `
                -File (Join-Path $AgentOSRoot "scripts\write_escalation.ps1") `
                -TaskId $originalId -Source "verify_needs_human" `
                -Reason "codex_verify_needs_human_decision" `
                -DecisionType "clarify_requirement" `
                -SummaryForJosh "Codex Verify requires a Josh decision instead of PASS or FAIL." `
                -Evidence @((Get-ResultPath $review.Id)) -AgentOSRoot $AgentOSRoot -Environment $Environment | Out-Null
            # NEEDS_HUMAN_DECISION trajectories also feed the learning loop.
            $originalTaskType = if ($original) {
                Get-Field $original.Text "task_type"
            } else { "" }
            & powershell.exe -NoProfile -ExecutionPolicy Bypass `
                -File (Join-Path $AgentOSRoot "scripts\write_task_metric.ps1") `
                -TaskId $originalId `
                -TaskType $(if ($originalTaskType) { $originalTaskType } else { "unknown" }) `
                -Verdict "NEEDS_HUMAN_DECISION" -RetryCount $round `
                -FailReason (Get-FailurePatternKey $review.Id $originalId) `
                -FinalStatus "escalation_required" `
                -AgentOSRoot $AgentOSRoot | Out-Null
            Write-QueueEvent $originalId "escalation_required" "verify_needs_human:$($review.Id)"
            continue
        }

        if ($decision -eq "invalid") {
            $original = $Tasks | Where-Object { $_.Id -eq $originalId } | Select-Object -First 1
            if ($original) {
                Set-TaskState $original.Path "escalation_required" "blocked"
            }
            Write-ReviewFlowStatus $originalId $review.Id $decision `
                "escalation_required" "invalid_or_missing_verify_verdict" $round
            & powershell.exe -NoProfile -ExecutionPolicy Bypass `
                -File (Join-Path $AgentOSRoot "scripts\write_escalation.ps1") `
                -TaskId $originalId -Source "verify_needs_human" `
                -Reason "invalid_or_missing_verify_verdict" `
                -DecisionType "retry_with_changes" `
                -SummaryForJosh "Codex Verify did not emit a valid verdict; Josh must decide whether to retry." `
                -Evidence @((Get-ResultPath $review.Id)) -AgentOSRoot $AgentOSRoot -Environment $Environment | Out-Null
            Write-QueueEvent $originalId "escalation_required" "invalid_verify_verdict:$($review.Id)"
        }
    }
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $QueueLog) | Out-Null
if ($ValidateOnly) {
    $script:LoopScanMilliseconds = 0.0
    $script:LoopIndexRebuilds = 0
    $validatedTasks = @(Get-ScopedTasks (Get-AllTasks) $RootDispatchId)
    Write-LoopScanEvent $validatedTasks
    $validatedRoot = $validatedTasks | Where-Object Id -eq $RootDispatchId | Select-Object -First 1
    if (Test-TaskRequiresEscalationGate $validatedRoot) {
        $decisionGate = Get-EscalationDecisionGate $RootDispatchId
        if ($decisionGate.HasEscalation -and -not $decisionGate.Valid) {
            Write-Output "queue_validation=blocked"
            Write-Output "root_dispatch_id=$RootDispatchId"
            Write-Output "reason=$($decisionGate.Reason)"
            Write-Output "task_status=awaiting_josh"
            exit 22
        }
    }
    Write-Output "queue_validation=passed"
    Write-Output "root_dispatch_id=$RootDispatchId"
    Write-Output "scoped_task_count=$($validatedTasks.Count)"
    foreach ($task in $validatedTasks | Sort-Object Order, Id) {
        Write-Output "task=$($task.Id)|status=$($task.Status)|route=$($task.Route)"
    }
    exit 0
}

$executed = 0
$recoveryPending = $false
$containedFailures = 0
while ($executed -lt $MaxTasksPerRun) {
    $script:LoopScanMilliseconds = 0.0
    $script:LoopIndexRebuilds = 0
    $gateOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Gate -AgentOSRoot $AgentOSRoot
    if ($LASTEXITCODE -ne 0) {
        Write-QueueEvent "queue" "blocked" "governance_gate"
        Set-QueueRunState "blocked" "governance_gate"
        exit 20
    }

    $tasks = @(Get-ScopedTasks (Get-AllTasks) $RootDispatchId)
    $rootTask = $tasks | Where-Object Id -eq $RootDispatchId | Select-Object -First 1
    if (Test-TaskRequiresEscalationGate $rootTask) {
        $decisionGate = Get-EscalationDecisionGate $RootDispatchId
        if ($decisionGate.HasEscalation -and -not $decisionGate.Valid) {
            Write-LoopScanEvent $tasks
            Write-QueueEvent $RootDispatchId "awaiting_josh" $decisionGate.Reason
            Set-QueueRunState "awaiting_josh" $decisionGate.Reason
            Write-Output "queue_status=awaiting_josh"
            Write-Output "root_dispatch_id=$RootDispatchId"
            Write-Output "reason=$($decisionGate.Reason)"
            Write-Output "tasks_executed=0"
            exit 0
        }
    }
    Update-ReviewFlowStates $tasks

    $tasks = @(Get-ScopedTasks (Get-AllTasks) $RootDispatchId)
    Promote-Dependencies $tasks
    $tasks = @(Get-ScopedTasks (Get-AllTasks) $RootDispatchId)
    Write-LoopScanEvent $tasks
    $ready = $tasks |
        Where-Object {
            $_.Status -eq "ready_to_route" -and
            $_.Route -in @("Codex", "Claude", "Ollama", "Antigravity CLI") -and
            ((-not (Test-Path -LiteralPath (Get-ResultPath $_.Id) -PathType Leaf)) -or
                $_.TaskStatus -in @("retrying", "fallback_ready"))
        } |
        Sort-Object Order, Id |
        Select-Object -First 1

    if (-not $ready) {
        Write-QueueEvent "queue" "idle" "no_ready_tasks"
        break
    }

    Write-QueueEvent $ready.Id "processing" "dispatcher_start"
    $dispatcherOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Dispatcher `
        -DispatchId $ready.Id -AgentOSRoot $AgentOSRoot 2>&1
    $exitCode = $LASTEXITCODE
    $dispatcherText = $dispatcherOutput -join [Environment]::NewLine
    if ($dispatcherText) { Write-Output $dispatcherText }
    $reason = Get-Field $dispatcherText "reason"
    $phase = Get-Field $dispatcherText "phase"
    $artifact = Get-Field $dispatcherText "recovery_status_path"
    if (-not $artifact) { $artifact = Get-Field $dispatcherText "result_path" }
    $executed++
    if ($exitCode -ne 0) {
        if (-not $reason) { $reason = "dispatcher_exit_$exitCode" }
        if (-not $phase) { $phase = "unknown" }
        if (-not $artifact) { $artifact = "not_available" }
        $detail = "reason=$reason phase=$phase exit_code=$exitCode artifact=$artifact"
        Write-Attempt $ready $exitCode $reason $phase $artifact
        $attempts = Get-Attempts $ready.Id
        $mode = [string](Get-Field $ready.Text "codex_mode")
        $routeKey = Get-RouteKey $ready.Route $mode
        $routeAttempts = @($attempts | Where-Object {
            (Get-RouteKey ([string]$_.route_to) ([string]$_.codex_mode)) -eq $routeKey
        }).Count
        if ((Test-RecoverableFailure $reason) -and $routeAttempts -lt $MaxAttemptsPerRoute) {
            Set-TaskState $ready.Path "ready_to_route" "retrying"
            $recoveryPending = $true
            Write-QueueEvent $ready.Id "retry_scheduled" "$detail attempt=$routeAttempts/$MaxAttemptsPerRoute"
            if ($Once) { break }
            continue
        }
        $fallback = if (Test-RecoverableFailure $reason) { Get-FallbackSpec $ready $attempts } else { $null }
        if ($fallback) {
            Set-TaskRoute $ready $fallback.Route $fallback.Type $fallback.AssignedTo $fallback.CodexMode
            $recoveryPending = $true
            Write-QueueEvent $ready.Id "fallback_scheduled" "$detail next_route=$($fallback.Route) next_mode=$($fallback.CodexMode)"
            if ($Once) { break }
            continue
        }
        Set-TaskState $ready.Path "escalation_required" "blocked"
        $containedFailures++
        Write-QueueEvent $ready.Id "failure_contained" "$detail recovery_exhausted=true"
        try {
            $escalationSource = if ((Get-Field $ready.Text "task_type") -eq "Complex") { "complex_fail" } else { "simple_fail" }
            # This is the one call site that passes >1 evidence item across the
            # `powershell.exe -File` process boundary. Confirmed by direct repro
            # (2026-07-27) that a plain -Evidence array silently mis-binds its
            # second element onto -Environment in that scenario; -EvidenceB64
            # (Base64-encoded JSON array) is the only transport verified to
            # survive the boundary intact. See write_escalation.ps1 for the
            # decode side and the full root-cause note.
            $evidenceJson = @($artifact, (Get-AttemptLogPath $ready.Id)) | ConvertTo-Json -Compress
            $evidenceB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($evidenceJson))
            $escalationOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass `
                -File (Join-Path $AgentOSRoot "scripts\write_escalation.ps1") `
                -TaskId $ready.Id -Source $escalationSource `
                -Reason $reason -DecisionType "retry_with_changes" `
                -SummaryForJosh "All bounded retries and compliant worker fallbacks were exhausted; the queue continued processing independent tasks." `
                -EvidenceB64 $evidenceB64 -AgentOSRoot $AgentOSRoot -Environment $Environment 2>&1
            if ($LASTEXITCODE -ne 0) { throw ($escalationOutput -join [Environment]::NewLine) }
        } catch {
            Write-QueueEvent $ready.Id "escalation_write_failed" $_.Exception.Message
        }
        if ($Once) { break }
        continue
    }
    $successReason = if ($reason) { $reason } else { "dispatcher_exit_0" }
    $successDetail = "reason=$successReason phase=$(if($phase){$phase}else{'completed'}) artifact=$(if($artifact){$artifact}else{'not_available'})"
    Write-QueueEvent $ready.Id "completed" $successDetail
    Set-TaskState $ready.Path "completed" "completed"
    $recoveryPending = $false
    if ($Once) { break }
    Start-Sleep -Seconds $PollSeconds
}

# Learning loop closeout: cluster recurring failure patterns (threshold >= 2)
# from METRICS_LOG and resolved escalations. Append-only and deduplicated in
# the collector, so repeated runs are safe. Failures here never affect the
# queue result.
try {
    $collector = Join-Path $AgentOSRoot "scripts\collect_learning_candidates.ps1"
    if (Test-Path -LiteralPath $collector -PathType Leaf) {
        $collectorOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass `
            -File $collector -AgentOSRoot $AgentOSRoot 2>&1
        $collectorSummary = @($collectorOutput |
            Where-Object { $_ -match '^(candidates_created|governance_escalations|skipped_)' }) -join "; "
        Write-QueueEvent "queue" "learning_collector_done" $collectorSummary
    }
} catch {
    Write-QueueEvent "queue" "learning_collector_failed" $_.Exception.Message
}

$finalQueueStatus = if ($recoveryPending) { "recovery_pending" } elseif ($containedFailures -gt 0) { "completed_with_failures" } else { "completed" }
Write-Output "queue_status=$finalQueueStatus"
Write-Output "root_dispatch_id=$RootDispatchId"
Write-Output "tasks_executed=$executed"
Write-Output "contained_failures=$containedFailures"
Set-QueueRunState $finalQueueStatus "tasks_executed=$executed contained_failures=$containedFailures"

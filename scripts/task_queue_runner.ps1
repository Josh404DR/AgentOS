[CmdletBinding()]
param(
    [string]$AgentOSRoot = "E:\AgentOS",
    [Parameter(Mandatory = $true)]
    [string]$RootDispatchId,
    [switch]$ValidateOnly,
    [switch]$Once,
    [int]$PollSeconds = 5,
    [int]$MaxTasksPerRun = 20
)

$ErrorActionPreference = "Stop"
$Utf8NoBom = [Text.UTF8Encoding]::new($false)
$TasksRoot = Join-Path $AgentOSRoot "data\codex_tasks"
$Dispatcher = Join-Path $AgentOSRoot "scripts\dispatch_task_packet.ps1"
$Gate = Join-Path $AgentOSRoot "scripts\assert_governance_ready.ps1"
$QueueLog = Join-Path $AgentOSRoot "logs\task-queue.log"
$QueueStatePath = Join-Path $AgentOSRoot (Join-Path "data\queue_runs" "$RootDispatchId.json")

function Get-Field([string]$Text, [string]$Name) {
    $match = [regex]::Match(
        $Text,
        "(?mi)^\s*" + [regex]::Escape($Name) + "\s*:\s*(.+?)\s*$"
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
    Add-Content -LiteralPath $QueueLog -Value $line -Encoding UTF8
    Write-Output $line
    try {
        $eventDir = Join-Path $AgentOSRoot "data\observability\events"
        New-Item -ItemType Directory -Force -Path $eventDir | Out-Null
        $result = if ($Status -in @("blocked", "state_update_failed", "escalation_required")) { "error" } elseif ($Status -eq "idle") { "warn" } else { "ok" }
        $exitCode = $null
        if ($Detail -match "dispatcher_exit_(\d+)") { $exitCode = [int]$Matches[1] }
        $event = [ordered]@{
            event_id = "evt-$((Get-Date).ToString('yyyyMMdd-HHmmssfff'))-$([Guid]::NewGuid().ToString('N').Substring(0, 6))"
            ts = (Get-Date).ToString('o')
            actor = "queue_runner"
            runtime_id = "task-queue-runner"
            pid = $PID
            dispatch_id = $DispatchId
            parent_event_id = $null
            script = "scripts\task_queue_runner.ps1"
            action = $Status
            input_ref = if ($DispatchId -eq "queue") { $null } else { "data\codex_tasks\$DispatchId\TASK.md" }
            output_ref = if ($DispatchId -eq "queue") { $null } else { "data\codex_tasks\$DispatchId\OUTPUTS\RESULT.md" }
            next_step = $Detail
            result = $result
            exit_code = $exitCode
            error_class = if ($Status -eq "state_update_failed") { "STATE_UPDATE_FAILED" } else { $null }
            severity_basis = if ($null -ne $exitCode) { "exit_code" } else { "state_transition" }
            duration_ms = $null
        }
        $eventPath = Join-Path $eventDir "task-queue-runner-$((Get-Date).ToString('yyyyMM')).jsonl"
        [IO.File]::AppendAllText($eventPath, (($event | ConvertTo-Json -Compress -Depth 6) + [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
    } catch {
        Write-Warning "Observability event write failed: $($_.Exception.Message)"
    }
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

function Get-AllTasks {
    if (-not (Test-Path -LiteralPath $TasksRoot)) { return @() }
    return @(Get-ChildItem -LiteralPath $TasksRoot -Directory | ForEach-Object {
        $taskPath = Join-Path $_.FullName "TASK.md"
        if (Test-Path -LiteralPath $taskPath -PathType Leaf) {
            $text = Read-Utf8 $taskPath
            $revisionRoundValue = Get-Field $text "revision_round"
            $orderValue = Get-Field $text "dependency_order"
            [pscustomobject]@{
                Id = Get-Field $text "dispatch_id"
                Path = $taskPath
                Text = $text
                Status = Get-Field $text "dispatch_status"
                Type = Get-Field $text "type"
                Route = Get-Field $text "route_to"
                DependsOn = Get-Field $text "depends_on"
                Parent = Get-Field $text "parent_dispatch_id"
                SourceDispatch = Get-Field $text "source_dispatch_id"
                RevisionOf = Get-Field $text "revision_of"
                RevisionRound = if ($revisionRoundValue) {
                    [int]$revisionRoundValue
                } else { 0 }
                Order = if ($orderValue) {
                    [int]$orderValue
                } else { 999 }
            }
        }
    })
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
    if ($round -gt 2) {
        $original = $Tasks | Where-Object { $_.Id -eq $originalId } | Select-Object -First 1
        if ($original) {
            Set-TaskState $original.Path "escalation_required" "blocked"
        }
        Write-ReviewFlowStatus $originalId $VerifyTask.Id "FAIL" `
            "escalation_required" "revision_limit_reached" $reviewedTask.RevisionRound
        $taskType = Get-Field $original.Text "task_type"
        $source = if ($taskType -eq "Complex") { "complex_fail" } else { "simple_fail" }
        & powershell.exe -NoProfile -ExecutionPolicy Bypass `
            -File (Join-Path $AgentOSRoot "scripts\write_escalation.ps1") `
            -TaskId $originalId -Source $source -Reason "revision_limit_reached" `
            -DecisionType "accept_partial_delivery" `
            -SummaryForJosh "Task $originalId failed Codex Verify after two Claude revisions." `
            -Evidence @((Get-ReviewFlowPath $originalId)) -AgentOSRoot $AgentOSRoot | Out-Null
        Write-QueueEvent $originalId "escalation_required" "revision_limit_reached"
        return
    }
    $id = "$originalId-revision-$round"
    if (Test-Path -LiteralPath (Get-TaskPath $id)) { return }
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
            & powershell.exe -NoProfile -ExecutionPolicy Bypass `
                -File (Join-Path $AgentOSRoot "scripts\write_task_metric.ps1") `
                -TaskId $originalId -TaskType $(if ($taskType) { $taskType } else { "unknown" }) `
                -Verdict "PASS" -RetryCount $round -FinalStatus "completed" `
                -AgentOSRoot $AgentOSRoot | Out-Null
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
                -Evidence @((Get-ResultPath $review.Id)) -AgentOSRoot $AgentOSRoot | Out-Null
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
                -Evidence @((Get-ResultPath $review.Id)) -AgentOSRoot $AgentOSRoot | Out-Null
            Write-QueueEvent $originalId "escalation_required" "invalid_verify_verdict:$($review.Id)"
        }
    }
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $QueueLog) | Out-Null
if ($ValidateOnly) {
    $validatedTasks = Get-ScopedTasks (Get-AllTasks) $RootDispatchId
    Write-Output "queue_validation=passed"
    Write-Output "root_dispatch_id=$RootDispatchId"
    Write-Output "scoped_task_count=$($validatedTasks.Count)"
    foreach ($task in $validatedTasks | Sort-Object Order, Id) {
        Write-Output "task=$($task.Id)|status=$($task.Status)|route=$($task.Route)"
    }
    exit 0
}

$executed = 0
while ($executed -lt $MaxTasksPerRun) {
    $gateOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Gate -AgentOSRoot $AgentOSRoot
    if ($LASTEXITCODE -ne 0) {
        Write-QueueEvent "queue" "blocked" "governance_gate"
        Set-QueueRunState "blocked" "governance_gate"
        exit 20
    }

    $tasks = Get-ScopedTasks (Get-AllTasks) $RootDispatchId
    Update-ReviewFlowStates $tasks

    $tasks = Get-ScopedTasks (Get-AllTasks) $RootDispatchId
    Promote-Dependencies $tasks
    $tasks = Get-ScopedTasks (Get-AllTasks) $RootDispatchId
    $ready = $tasks |
        Where-Object {
            $_.Id -ne $RootDispatchId -and
            $_.Status -eq "ready_to_route" -and
            $_.Route -in @("Codex", "Claude", "Ollama", "Antigravity CLI") -and
            -not (Test-Path -LiteralPath (Get-ResultPath $_.Id) -PathType Leaf)
        } |
        Sort-Object Order, Id |
        Select-Object -First 1

    if (-not $ready) {
        Write-QueueEvent "queue" "idle" "no_ready_tasks"
        break
    }

    Write-QueueEvent $ready.Id "processing" "dispatcher_start"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Dispatcher `
        -DispatchId $ready.Id -AgentOSRoot $AgentOSRoot
    $exitCode = $LASTEXITCODE
    $executed++
    if ($exitCode -ne 0) {
        Write-QueueEvent $ready.Id "blocked" "dispatcher_exit_$exitCode"
        Set-QueueRunState "blocked" "dispatcher_exit_$exitCode"
        exit $exitCode
    }
    Write-QueueEvent $ready.Id "completed" "dispatcher_exit_0"
    if ($Once) { break }
    Start-Sleep -Seconds $PollSeconds
}

Write-Output "queue_status=completed"
Write-Output "root_dispatch_id=$RootDispatchId"
Write-Output "tasks_executed=$executed"
Set-QueueRunState "completed" "tasks_executed=$executed"

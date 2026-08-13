[CmdletBinding()]
param([string]$AgentOSRoot = "E:\AgentOS")

$ErrorActionPreference = "Stop"
$utf8 = [Text.UTF8Encoding]::new($false)
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("agentos-revision-replay-" + [guid]::NewGuid().ToString("N"))

function Write-File([string]$Path, [string]$Content) {
    $parent = Split-Path -Parent $Path
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    [IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Write-Task {
    param(
        [string]$Root,
        [string]$Id,
        [string]$Type,
        [string]$Parent = "none",
        [string]$RevisionOf = "",
        [int]$Round = 0,
        [string]$DispatchStatus = "completed",
        [string]$TaskStatus = "completed"
    )
    $revisionFields = if ($RevisionOf) {
        "revision_of: $RevisionOf`nrevision_round: $Round"
    } else { "" }
    Write-File (Join-Path $Root "data\codex_tasks\$Id\TASK.md") @"
# Replay guard fixture
dispatch_id: $Id
parent_dispatch_id: $Parent
$revisionFields
type: $Type
assigned_to: Claude Worker
route_to: Claude
codex_mode: n/a
task_type: Simple
dispatch_status: $DispatchStatus
task_status: $TaskStatus
requires_josh_approval: true
approval: offline_fixture
governance_version: 1.3.0
governance_hash: 0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1
"@
}

function New-Fixture([string]$Name) {
    $root = Join-Path $fixtureRoot $Name
    foreach ($relative in @(
        "scripts",
        "scripts\lib",
        "data\codex_tasks",
        "data\escalations",
        "data\queue_runs",
        "logs"
    )) {
        New-Item -ItemType Directory -Force -Path (Join-Path $root $relative) | Out-Null
    }
    Copy-Item (Join-Path $AgentOSRoot "scripts\task_queue_runner.ps1") (Join-Path $root "scripts\task_queue_runner.ps1")
    Copy-Item (Join-Path $AgentOSRoot "scripts\rebuild_active_task_index.ps1") (Join-Path $root "scripts\rebuild_active_task_index.ps1")
    Copy-Item (Join-Path $AgentOSRoot "scripts\write_escalation.ps1") (Join-Path $root "scripts\write_escalation.ps1")
    Copy-Item (Join-Path $AgentOSRoot "scripts\lib\global_jsonl_lock.ps1") (Join-Path $root "scripts\lib\global_jsonl_lock.ps1")
    Write-File (Join-Path $root "scripts\assert_governance_ready.ps1") @'
param([string]$AgentOSRoot)
Write-Output "governance_gate=passed"
exit 0
'@
    Write-File (Join-Path $root "scripts\escalation_receipt_validation.ps1") @'
function Get-AgentOSEscalationSafeId([string]$TaskId) {
    return [regex]::Replace($TaskId, '[^A-Za-z0-9_.-]+', '-')
}
function Test-AgentOSEscalationDecisionRecord {
    param([string]$AgentOSRoot, [object]$DecisionRecord)
    return [pscustomobject]@{ Valid=$true; Reason='offline_fixture_verified' }
}
'@
    Write-File (Join-Path $root "scripts\fake_dispatcher.ps1") @'
param([string]$DispatchId, [string]$AgentOSRoot)
Write-Output "status=completed"
Write-Output "reason=offline_fixture"
Write-Output "phase=completed"
Write-Output "result_path=not_applicable"
exit 0
'@
    return $root
}

function Write-EscalationDecision([string]$Root, [string]$Id) {
    $dir = Join-Path $Root "data\escalations\$Id"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Write-File (Join-Path $dir "event.json") '{"status":"awaiting_josh"}'
    $decisionPath = Join-Path $dir "DECISION-fixture.json"
    Write-File $decisionPath '{"decision":"modify"}'
    return $decisionPath
}

function Invoke-Queue([string]$Root, [string]$Id) {
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass `
        -File (Join-Path $Root "scripts\task_queue_runner.ps1") `
        -AgentOSRoot $Root -RootDispatchId $Id -Once -MaxTasksPerRun 1 `
        -DispatcherPath (Join-Path $Root "scripts\fake_dispatcher.ps1") 2>&1
    return [pscustomobject]@{ ExitCode=$LASTEXITCODE; Text=($output -join "`n") }
}

try {
    New-Item -ItemType Directory -Force -Path $fixtureRoot | Out-Null

    # Legal one-time extension: revision-2 FAIL + a fresh Modify decision
    # creates revision-3 and records that exact decision as consumed.
    $singleRoot = New-Fixture "single-use"
    $singleId = "fixture-single-use"
    Write-Task $singleRoot $singleId "BUILDER_TASK" -DispatchStatus "escalation_required" -TaskStatus "blocked"
    Write-Task $singleRoot "$singleId-revision-2" "CLAUDE_WORKER" -Parent $singleId -RevisionOf $singleId -Round 2
    Write-Task $singleRoot "$singleId-revision-2-codex-verify" "CODEX_VERIFY" -Parent "$singleId-revision-2"
    Write-File (Join-Path $singleRoot "data\codex_tasks\$singleId-revision-2-codex-verify\OUTPUTS\RESULT.md") "status: completed`nverify_verdict: FAIL"
    $singleDecision = Write-EscalationDecision $singleRoot $singleId
    $single = Invoke-Queue $singleRoot $singleId
    if ($single.ExitCode -ne 0) { throw "single-use queue failed: $($single.Text)" }
    $revision3 = Join-Path $singleRoot "data\codex_tasks\$singleId-revision-3\TASK.md"
    $singleMarker = Join-Path $singleRoot "data\escalations\$singleId\MODIFY_CONSUMED-round_3.json"
    if (-not (Test-Path $revision3) -or -not (Test-Path $singleMarker)) {
        throw "fresh Modify decision did not grant exactly one revision-3; queue=$($single.Text)"
    }
    $markerDecision = [string]((Get-Content -Raw -Encoding UTF8 $singleMarker | ConvertFrom-Json).decision_path)
    if ($markerDecision -ne $singleDecision) { throw "consumption marker did not bind the decision path" }

    # Replay attempt: revision-3 FAIL + marker for the same still-valid
    # decision must escalate and must never create revision-4.
    $replayRoot = New-Fixture "replay"
    $replayId = "fixture-replay"
    Write-Task $replayRoot $replayId "BUILDER_TASK" -DispatchStatus "escalation_required" -TaskStatus "blocked"
    Write-Task $replayRoot "$replayId-revision-3" "CLAUDE_WORKER" -Parent $replayId -RevisionOf $replayId -Round 3
    Write-Task $replayRoot "$replayId-revision-3-codex-verify" "CODEX_VERIFY" -Parent "$replayId-revision-3"
    Write-File (Join-Path $replayRoot "data\codex_tasks\$replayId-revision-3-codex-verify\OUTPUTS\RESULT.md") "status: completed`nverify_verdict: FAIL"
    $replayDecision = Write-EscalationDecision $replayRoot $replayId
    Write-File (Join-Path $replayRoot "data\escalations\$replayId\MODIFY_CONSUMED-round_3.json") `
        (([ordered]@{ decision_path=$replayDecision; granted_round=3; original_id=$replayId } | ConvertTo-Json) + "`n")
    $replay = Invoke-Queue $replayRoot $replayId
    if ($replay.ExitCode -ne 0) { throw "replay queue failed: $($replay.Text)" }
    if (Test-Path (Join-Path $replayRoot "data\codex_tasks\$replayId-revision-4")) {
        throw "consumed Modify decision incorrectly created revision-4"
    }
    $indexPath = Join-Path $replayRoot "data\escalations\ESCALATION_INDEX.jsonl"
    if (-not (Test-Path $indexPath)) { throw "replay escalation index missing" }
    $indexText = Get-Content -Raw -Encoding UTF8 $indexPath
    if ($indexText -notmatch '"reason":"revision_limit_reached_decision_already_consumed"') {
        throw "replay did not create the exact decision-already-consumed escalation"
    }

    Write-Output "revision_decision_replay_guard=PASS"
    Write-Output "single_modify_grants_one_round=true"
    Write-Output "same_decision_round4_blocked=true"
    Write-Output "escalation_reason=revision_limit_reached_decision_already_consumed"
} finally {
    if (Test-Path -LiteralPath $fixtureRoot) {
        $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        $resolved = [IO.Path]::GetFullPath($fixtureRoot)
        if ($resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}

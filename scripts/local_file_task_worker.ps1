param(
    [Parameter(Mandatory = $true)][string]$MessageText,
    [Parameter(Mandatory = $true)][string]$DispatchId,
    [string]$AgentOSRoot = "E:\AgentOS",
    [int]$TimeoutSeconds = 600
)

$ErrorActionPreference = "Stop"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$root = (Resolve-Path -LiteralPath $AgentOSRoot).Path
$governanceGate = Join-Path $root "scripts\assert_governance_ready.ps1"
$governanceOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $governanceGate -AgentOSRoot $root
if ($LASTEXITCODE -ne 0) { throw "Governance gate blocked Codex workspace task.`n$($governanceOutput -join "`n")" }
$governanceText = $governanceOutput -join "`n"
$governanceVersion = ([regex]::Match($governanceText, '(?m)^governance_version=(.+)$')).Groups[1].Value.Trim()
$governanceHash = ([regex]::Match($governanceText, '(?m)^governance_hash=(.+)$')).Groups[1].Value.Trim()
$match = [regex]::Match(
    $MessageText,
    '(?i)([A-Z]:\\[^\r\n<>:"|?*]+\.(?:md|txt)|(?:prompts|docs|data|scripts|config|agents|workflows)[\\/][^\r\n<>:"|?*]+\.(?:md|txt))'
)
$target = $null
if ($match.Success) {
    $rawTarget = $match.Groups[1].Value.Trim().TrimEnd(
        [char[]]@('.', ',', [char]0xFF0C, [char]0x3002)
    )
    $candidate = if ([IO.Path]::IsPathRooted($rawTarget)) {
        $rawTarget
    } else {
        Join-Path $root ($rawTarget -replace '/', '\')
    }
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $target = (Resolve-Path -LiteralPath $candidate).Path
        if (-not $target.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)) {
            throw "Target must be inside AgentOSRoot."
        }
    }
}

$safeId = [regex]::Replace($DispatchId, '[^A-Za-z0-9_.-]+', '-').Trim('-')
$taskDir = Join-Path $root ("data\codex_tasks\{0}" -f $safeId)
$outputs = Join-Path $taskDir "OUTPUTS"
New-Item -ItemType Directory -Path $outputs -Force | Out-Null
$taskPath = Join-Path $taskDir "TASK.md"
$resultPath = Join-Path $outputs "RESULT.md"
$promptPath = Join-Path $outputs "CODEX_PROMPT.md"
$consolePath = Join-Path $outputs "CODEX_CONSOLE.log"
$targetField = if ($target) { $target } else { "not_explicitly_resolved" }
$targetInstruction = if ($target) {
    "Read the existing target file before acting: $target"
} else {
    "Resolve requested workspace paths from Josh's message. Work only inside E:\AgentOS."
}

$classifier = Join-Path $root "scripts\classify_task.ps1"
if (-not (Test-Path -LiteralPath $classifier -PathType Leaf)) {
    throw "Task classifier not found: $classifier"
}
$classificationJson = & $classifier -MessageText $MessageText -AsJson
if ($LASTEXITCODE -ne 0) { throw "Rule-based classifier failed." }
$classification = ($classificationJson -join "") | ConvertFrom-Json
$taskType = [string]$classification.task_type
$riskHits = @($classification.risk_hits)
$complexHits = @($classification.complex_hits)
$negatedRiskConstraints = @($classification.negated_risk_constraints)
$isPlanTask = $taskType -eq "Complex"
$taskTitle = switch ($taskType) {
    "Complex" { "Codex Plan Orchestration Task" }
    "Risky" { "Risky Task Awaiting Josh" }
    "classification_unclear" { "Unclear Task Awaiting Josh" }
    default { "Claude Workspace Task" }
}
$taskKind = switch ($taskType) {
    "Complex" { "plan_orchestration" }
    "Risky" { "risky_task" }
    "classification_unclear" { "classification_unclear" }
    default { "workspace_change" }
}
$routeTo = if ($isPlanTask) { "Codex" } elseif ($taskType -eq "Simple") { "Claude" } else { "STOP" }
$assignedTo = if ($isPlanTask) { "Codex" } elseif ($taskType -eq "Simple") { "Claude Worker" } else { "Josh" }
$packetType = if ($isPlanTask) { "CODEX_PLAN" } elseif ($taskType -eq "Simple") { "CLAUDE_WORKER" } else { "ESCALATION" }
$codexModeLine = if ($isPlanTask) { "codex_mode: plan" } else { "codex_mode: n/a" }
$dispatchStatus = if ($taskType -in @("Risky", "classification_unclear")) { "escalation_required" } else { "ready_to_route" }
$taskStatus = if ($taskType -in @("Risky", "classification_unclear")) { "awaiting_josh" } else { "ready" }
$approvalEvidence = if ($taskType -in @("Risky", "classification_unclear")) {
    "pending_explicit_josh_decision"
} else {
    "Josh explicit Telegram request $DispatchId"
}
$riskHitsText = if ($riskHits.Count) { $riskHits -join "," } else { "none" }
$complexHitsText = if ($complexHits.Count) { $complexHits -join "," } else { "none" }
$negatedRiskText = if ($negatedRiskConstraints.Count) {
    $negatedRiskConstraints -join " | "
} else { "none" }
$planInstructions = if ($isPlanTask) {
@"
## Codex Plan Output Contract

- Do not implement the requested workspace change.
- Create governed child `TASK.md` packets under `data\codex_tasks\<child_id>\`.
- Every implementation child must use:
  - `type: CLAUDE_WORKER`
  - `assigned_to: Claude Worker`
  - `route_to: Claude`
  - `workflow_version: 1.2`
  - `source_dispatch_id: $DispatchId`
  - current governance version and hash
- Include `parent_dispatch_id`, deterministic `dependency_order`,
  `depends_on`, and explicit `## Acceptance Criteria`.
- First child may depend on `parent_created:$DispatchId`; later children
  depend on the preceding child dispatch ID.
"@
} else { "" }

$task = @"
# $taskTitle

dispatch_id: $DispatchId
type: $packetType
assigned_to: $assignedTo
route_to: $routeTo
$codexModeLine
impact_scope: core_script
task_kind: $taskKind
task_type: $taskType
workflow_version: 1.2
risk_hits: $riskHitsText
complex_hits: $complexHitsText
negated_risk_constraints: $negatedRiskText
classifier: rule_based_v1
target: $targetField
task_status: $taskStatus
dispatch_status: $dispatchStatus
requires_josh_approval: true
approval: $approvalEvidence
source: telegram_natural_language
governance_version: $governanceVersion
governance_hash: $governanceHash

## Josh Request

$MessageText

## Boundaries

- Work only inside E:\AgentOS.
- $targetInstruction
- Do not contact external services or clients.
- Do not delete evidence.
- Preserve unrelated user changes.
- Verify any modifications.

## Acceptance Criteria

- Fulfill the explicit Josh Request within its stated scope.
- Preserve unrelated workspace changes.
- Provide concrete verification evidence.

## Worker Output Contract

For every modified file, include one line:
changed_file: <workspace-relative-or-absolute-path>

Include exactly one:
change_required: true
or
change_required: false

For every verification command, include:
test_command: <literal command>
test_result: <PASS|FAIL and concise evidence>

$planInstructions
"@
[IO.File]::WriteAllText($taskPath, $task, $Utf8NoBom)

if ($taskType -in @("Risky", "classification_unclear")) {
    $escalationWriter = Join-Path $root "scripts\write_escalation.ps1"
    $source = if ($taskType -eq "Risky") { "risky_task" } else { "classification_unclear" }
    $decision = if ($taskType -eq "Risky") { "approve_risky_action" } else { "clarify_requirement" }
    $reason = if ($taskType -eq "Risky") {
        "risk_rules_matched:$riskHitsText"
    } else {
        "rule_based_classifier_could_not_safely_classify"
    }
    $escalationOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass `
        -File $escalationWriter -TaskId $safeId -Source $source `
        -Reason $reason -DecisionType $decision `
        -SummaryForJosh "Task $safeId requires Josh decision; no model or worker was invoked." `
        -Evidence @($taskPath) -AgentOSRoot $root
    Write-Output "local_file_task_status=escalation_required"
    Write-Output "dispatch_id=$DispatchId"
    Write-Output "task_type=$taskType"
    Write-Output "task_path=$taskPath"
    Write-Output ($escalationOutput -join [Environment]::NewLine)
    Write-Output "models_invoked=false"
    Write-Output "external_services_invoked=false"
    exit 0
}

$boundGovernanceOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $governanceGate -AgentOSRoot $root -TaskPath $taskPath
if ($LASTEXITCODE -ne 0) { throw "Governance binding check blocked Codex execution.`n$($boundGovernanceOutput -join "`n")" }
$agentRole = if ($isPlanTask) {
    "You are Codex Plan. Decompose this Complex Task into governed Claude Worker child tasks with deterministic dependencies and acceptance criteria. Do not implement the requested workspace changes yourself."
} else {
    "You are Claude Worker executing an AgentOS workspace task."
}
$prompt = @"
$agentRole
Read E:\AgentOS\AGENTS.md first, then read the task packet at $taskPath. $targetInstruction
Fulfill Josh's request using only E:\AgentOS.
You may edit workspace files when the request asks for changes.
Do not access external services, contact clients, delete evidence, commit, or push.
Write a concise completion report with status, files changed, verification, issues,
and recommended next step. Write all user-facing explanations in Traditional Chinese
(`zh-TW`). Keep machine-readable fields, paths, commands, and literal errors unchanged.

TASK:
$task
"@
[IO.File]::WriteAllText($promptPath, $prompt, $Utf8NoBom)

$dispatcher = Join-Path $root "scripts\dispatch_task_packet.ps1"
if (-not (Test-Path -LiteralPath $dispatcher -PathType Leaf)) {
    throw "Canonical dispatcher not found: $dispatcher"
}
$dispatchOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $dispatcher `
    -DispatchId $safeId -AgentOSRoot $root 2>&1 | Out-String
[IO.File]::WriteAllText($consolePath, $dispatchOutput.Trim(), $Utf8NoBom)
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $resultPath)) {
    throw "Canonical dispatcher failed with exit code $LASTEXITCODE."
}
$queueStartStatus = "not_requested"
$queueProcessId = ""
$queueStatePath = ""
if ($taskType -in @("Simple", "Complex")) {
    $queueStarter = Join-Path $root "scripts\start_task_queue.ps1"
    if (-not (Test-Path -LiteralPath $queueStarter -PathType Leaf)) {
        throw "Queue starter not found: $queueStarter"
    }
    $queueOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass `
        -File $queueStarter -RootDispatchId $safeId -AgentOSRoot $root 2>&1
    $queueExitCode = $LASTEXITCODE
    $queueText = $queueOutput -join "`n"
    if ($queueExitCode -ne 0) {
        throw "Queue starter failed with exit code $queueExitCode.`n$queueText"
    }
    $queueStartStatus = ([regex]::Match(
        $queueText,
        '(?m)^queue_start_status=(.+)$'
    )).Groups[1].Value.Trim()
    $queueProcessId = ([regex]::Match(
        $queueText,
        '(?m)^queue_process_id=(.+)$'
    )).Groups[1].Value.Trim()
    $queueStatePath = ([regex]::Match(
        $queueText,
        '(?m)^queue_state_path=(.+)$'
    )).Groups[1].Value.Trim()
}
Write-Output "local_file_task_status=completed"
Write-Output "dispatch_id=$DispatchId"
Write-Output "target_path=$target"
Write-Output "task_path=$taskPath"
Write-Output "result_path=$resultPath"
Write-Output "models_invoked=$(if ($isPlanTask) { 'codex_cli' } else { 'claude_cli' })"
Write-Output "external_services_invoked=false"
Write-Output "queue_start_status=$queueStartStatus"
Write-Output "queue_process_id=$queueProcessId"
Write-Output "queue_state_path=$queueStatePath"
Write-Output "governance_version=$governanceVersion"
Write-Output "governance_hash=$governanceHash"

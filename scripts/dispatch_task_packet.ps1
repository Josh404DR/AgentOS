# AgentOS canonical task-packet execution entry point.
# Reads data\codex_tasks\<DispatchId>\TASK.md, enforces governance and approval,
# invokes exactly one selected local agent CLI, and writes OUTPUTS\RESULT.md.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$DispatchId,

    [string]$AgentOSRoot = "E:\AgentOS",

    [switch]$DryRun,

    [int]$AgentTimeoutSeconds = 600,
    [int]$HeartbeatIntervalSeconds = 30,
    [string]$TestAgentScript = "",
    [switch]$TestPostprocessError
)

$ErrorActionPreference = "Stop"
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $Utf8NoBom
$OutputEncoding = $Utf8NoBom

function Get-PacketField {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Name
    )
    $escaped = [regex]::Escape($Name)
    $patterns = @(
        "(?im)^\s*$escaped\s*[:=]\s*(?<value>.+?)\s*$",
        "(?im)^\s*[-*]\s*$escaped\s*[:=]\s*(?<value>.+?)\s*$",
        "(?im)^\s*\*\*$escaped\*\*\s*[:=]\s*(?<value>.+?)\s*$"
    )
    foreach ($pattern in $patterns) {
        $match = [regex]::Match($Text, $pattern)
        if ($match.Success) {
            return $match.Groups["value"].Value.Trim().Trim('"').Trim("'")
        }
    }
    return ""
}

function Convert-ToBool {
    param([string]$Value)
    return $Value -match '^(?i:true|1|yes)$'
}

function Write-Utf8File {
    param([string]$Path, [string]$Content)
    $parent = Split-Path -Parent $Path
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
}

function Get-GitStatusSnapshot {
    # Added 2026-07-28 (structural redesign Pillar B, per Josh's direction:
    # docs\VERIFY_PIPELINE_STRUCTURAL_REDESIGN_2026-07-28.md). The verify
    # pipeline has repeatedly failed because it only trusted what an agent
    # SAID it changed (free-text changed_file:/change_required: lines,
    # scraped by regex) with nothing to check that against. This function
    # takes an independent, ground-truth git snapshot - not agent-reported,
    # not regex-guessed. It is intentionally best-effort and NEVER throws:
    # a snapshot failure (git unavailable, non-repo path, transient error)
    # must degrade to "snapshot_unavailable" and let the dispatch proceed
    # normally, not block real work over instrumentation.
    param([string]$AgentOSRoot)
    $gitRoot = $AgentOSRoot -replace '\\', '/'
    try {
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = "git"
        $psi.Arguments = "-c safe.directory=$gitRoot status --porcelain=v1 -uall"
        $psi.WorkingDirectory = $AgentOSRoot
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
        $psi.StandardErrorEncoding = [Text.Encoding]::UTF8
        $process = [System.Diagnostics.Process]::Start($psi)
        if ($null -eq $process) {
            return [pscustomobject]@{ Ok = $false; Lines = @(); Reason = "git_process_start_failed" }
        }
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) {
            return [pscustomobject]@{ Ok = $false; Lines = @(); Reason = "git_exit_$($process.ExitCode):$($stderr.Trim())" }
        }
        $lines = @($stdout -split "`r?`n" | Where-Object { $_ })
        return [pscustomobject]@{ Ok = $true; Lines = $lines; Reason = "" }
    } catch {
        return [pscustomobject]@{ Ok = $false; Lines = @(); Reason = "exception:$($_.Exception.Message)" }
    }
}

function Write-GitVerifiedChanges {
    # Diffs two Get-GitStatusSnapshot results (before/after an agent run) and
    # writes OUTPUTS\GIT_VERIFIED_CHANGES.json - the system's own independent
    # record of what actually changed on disk, separate from and not derived
    # from anything the agent said. Never throws; a failure on either side
    # just yields snapshot_status: unavailable so downstream tooling knows
    # not to rely on it, rather than crashing the dispatch.
    param(
        [Parameter(Mandatory = $true)][object]$Before,
        [Parameter(Mandatory = $true)][object]$After,
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [string[]]$IgnoredRelativePaths = @()
    )
    $result = if (-not $Before.Ok -or -not $After.Ok) {
        [ordered]@{
            snapshot_status = "unavailable"
            before_reason = $Before.Reason
            after_reason = $After.Reason
            git_verified_files_modified = @()
            git_verified_files_created = @()
            git_verified_files_deleted = @()
        }
    } else {
        $beforeSet = [Collections.Generic.HashSet[string]]::new([string[]]$Before.Lines)
        $ignoredSet = [Collections.Generic.HashSet[string]]::new(
            [string[]]@($IgnoredRelativePaths | ForEach-Object { ($_ -replace '\\', '/').Trim('"') }),
            [StringComparer]::OrdinalIgnoreCase
        )
        $newOrChangedLines = @($After.Lines | Where-Object { -not $beforeSet.Contains($_) })
        $created = [Collections.Generic.List[string]]::new()
        $modified = [Collections.Generic.List[string]]::new()
        $deleted = [Collections.Generic.List[string]]::new()
        foreach ($line in $newOrChangedLines) {
            if ($line.Length -lt 4) { continue }
            $code = $line.Substring(0, 2)
            $path = ($line.Substring(3).Trim().Trim('"') -replace '\\', '/')
            # These files are produced by the dispatcher for every invocation,
            # not by the delivery itself. Counting them would make every
            # query/read-only task disagree with change_required:false.
            if ($ignoredSet.Contains($path)) { continue }
            if ($code -eq "??") { $created.Add($path) }
            elseif ($code -match "D") { $deleted.Add($path) }
            else { $modified.Add($path) }
        }
        [ordered]@{
            snapshot_status = "captured"
            before_reason = ""
            after_reason = ""
            git_verified_files_modified = @($modified)
            git_verified_files_created = @($created)
            git_verified_files_deleted = @($deleted)
        }
    }
    try {
        Write-Utf8File -Path $OutputPath -Content (($result | ConvertTo-Json -Depth 6) + [Environment]::NewLine)
    } catch { }
}

function Stop-ProcessTree {
    param([int]$ProcessId)
    # Snapshot only this process' descendants; never match by executable name.
    try {
        $all = @(Get-CimInstance Win32_Process -ErrorAction Stop |
            Select-Object ProcessId, ParentProcessId)
        $pending = [Collections.Generic.Queue[int]]::new()
        $pending.Enqueue($ProcessId)
        $descendants = [Collections.Generic.List[int]]::new()
        while ($pending.Count) {
            $parent = $pending.Dequeue()
            foreach ($child in $all | Where-Object { $_.ParentProcessId -eq $parent }) {
                $childId = [int]$child.ProcessId
                $descendants.Add($childId)
                $pending.Enqueue($childId)
            }
        }
        for ($i = $descendants.Count - 1; $i -ge 0; $i--) {
            Stop-Process -Id $descendants[$i] -Force -ErrorAction SilentlyContinue
        }
        Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
    } catch {
        try { & taskkill.exe /T /F /PID $ProcessId 2>&1 | Out-Null } catch { }
    }
}

function Write-Heartbeat {
    param([string]$Path, [string]$Phase, [int]$ElapsedSeconds, [int]$AgentPid)
    try {
        $hb = "{`"dispatch_id`":`"$DispatchId`",`"phase`":`"$Phase`",`"elapsed_seconds`":$ElapsedSeconds,`"agent_pid`":$AgentPid,`"timestamp`":`"$(Get-Date -Format o)`"}"
        [System.IO.File]::WriteAllText($Path, $hb, $Utf8NoBom)
    } catch { }
}

function Invoke-BoundedProcess {
    param(
        [Parameter(Mandatory = $true)][Diagnostics.Process]$Process,
        [Parameter(Mandatory = $true)]$StdoutTask,
        [Parameter(Mandatory = $true)]$StderrTask,
        [string]$Phase = "agent_execution"
    )
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $intervalMs = [Math]::Max(250, $HeartbeatIntervalSeconds * 1000)
    $timeoutMs = [Math]::Max(1000, $AgentTimeoutSeconds * 1000)
    Write-Heartbeat -Path $HeartbeatPath -Phase $Phase -ElapsedSeconds 0 -AgentPid $Process.Id
    $timedOut = $false
    while (-not $Process.HasExited) {
        $remaining = $timeoutMs - [int]$timer.ElapsedMilliseconds
        if ($remaining -le 0) { $timedOut = $true; break }
        $waitMs = [Math]::Min($intervalMs, $remaining)
        if (-not $Process.WaitForExit($waitMs)) {
            Write-Heartbeat -Path $HeartbeatPath -Phase $Phase `
                -ElapsedSeconds ([int]$timer.Elapsed.TotalSeconds) -AgentPid $Process.Id
        }
    }
    if ($timedOut) {
        Write-Heartbeat -Path $HeartbeatPath -Phase "agent_timeout_cleanup" `
            -ElapsedSeconds ([int]$timer.Elapsed.TotalSeconds) -AgentPid $Process.Id
        Stop-ProcessTree -ProcessId $Process.Id
        try { [void]$Process.WaitForExit(5000) } catch { }
    }
    $timer.Stop()
    $stdout = if ($StdoutTask.IsCompleted) { try { [string]$StdoutTask.Result } catch { "" } } else { "" }
    $stderr = if ($StderrTask.IsCompleted) { try { [string]$StderrTask.Result } catch { "" } } else { "" }
    $code = if ($timedOut) { 124 } elseif ($Process.HasExited) { $Process.ExitCode } else { 125 }
    return [pscustomobject]@{
        TimedOut = $timedOut
        ExitCode = $code
        Stdout = $stdout
        Stderr = $stderr
        ElapsedSeconds = [int]$timer.Elapsed.TotalSeconds
        AgentPid = $Process.Id
    }
}

function Set-TestAgentStartInfo {
    param([Diagnostics.ProcessStartInfo]$StartInfo)
    if (-not $TestAgentScript) { return $false }
    $resolved = (Resolve-Path -LiteralPath $TestAgentScript).Path
    $StartInfo.FileName = "powershell.exe"
    $StartInfo.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $resolved + '" "' + $AgentOutputPath + '"'
    return $true
}

function Write-RecoveryStatus {
    param([string]$Reason, [string]$Phase, [string]$Detail)
    $content = @"
dispatch_id: $DispatchId
status: recoverable
reason: $Reason
phase: $Phase
agent_output_path: $AgentOutputPath
result_path: $ResultPath
heartbeat_path: $HeartbeatPath
detail: $Detail
recorded_at: $(Get-Date -Format o)
"@
    Write-Utf8File -Path $RecoveryStatusPath -Content $content
}

function Write-CanonicalResult {
    param(
        [string]$Status,
        [bool]$ModelsInvoked,
        [bool]$ScriptsExecuted,
        [string]$Findings,
        [string]$Caveats,
        [string]$ReviewDispatchId = ""
    )
    $safeFindings = if ($Findings) { $Findings.Trim() } else { "not_available" }
    $safeCaveats = if ($Caveats) { $Caveats.Trim() } else { "none" }
    $reviewLine = if ($ReviewDispatchId) {
        "review_dispatch_id: $ReviewDispatchId"
    } else {
        "review_dispatch_id: not_created"
    }
    $content = @"
# AgentOS Dispatch Result

dispatch_id: $DispatchId
route_to: $RouteTo
codex_mode: $CodexModeForResult
governance_version: $GovernanceVersion
governance_hash: $GovernanceHash
status: $Status
models_invoked: $($ModelsInvoked.ToString().ToLowerInvariant())
scripts_executed: $($ScriptsExecuted.ToString().ToLowerInvariant())
cleanup_executed: false
dry_run: $($DryRun.IsPresent.ToString().ToLowerInvariant())
$reviewLine

## Findings

$safeFindings

## Caveats

$safeCaveats
"@
    Write-Utf8File -Path $ResultPath -Content $content
}

# DEPRECATED (2026-07-28): Invoke-GitDiffText / Find-ExistingVerifyDispatch /
# New-CodexVerifyTask below are the ORIGINAL versions that
# scripts\create_codex_verify_task.ps1 was cloned from on 2026-07-27. A full
# audit on 2026-07-28 (triggered by repeated Verify FAILs on
# docs-governance-status-autolink / queue-active-index-optimization) found
# these originals still have every bug that's since been fixed in the clone:
# no UTF8 StandardOutputEncoding on the git diff subprocess (mojibake on any
# non-ASCII diff content), no untracked-new-file detection (SCOPED_DIFF silently
# empty for brand-new deliverable files), no impact_scope/## Scope-section
# fallback when RESULT.md has no explicit changed_file:/change_required:
# fields (true for the "AgentOS Dispatch Result" canonical format used by
# most codex_mode: plan tickets), and no version-string false-positive
# filtering. Rather than fixing the same logic twice in two files, the actual
# auto-trigger call site below (search "builderCompleted") now calls
# create_codex_verify_task.ps1 directly. These functions are left defined
# only so a future cleanup pass can diff/delete them deliberately - nothing
# in this file should call them. Do not add a new call site here; fix
# create_codex_verify_task.ps1 instead.
function Invoke-GitDiffText {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    # Use Arguments string (not ArgumentList) for PS 5.1 / .NET Framework compatibility.
    # ArgumentList is .NET Core 2.1+ only; accessing it in PS 5.1 returns null and
    # calling .Add() on null throws InvokeMethodOnNull.
    $gitRoot = $AgentOSRoot -replace '\\', '/'
    $safePath = '"' + ($RelativePath -replace '"', '\"') + '"'
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = "git"
    $psi.Arguments = "-c safe.directory=$gitRoot diff -- $safePath"
    $psi.WorkingDirectory = $AgentOSRoot
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $process = [System.Diagnostics.Process]::Start($psi)
    if ($null -eq $process) {
        return "diff_status: git_process_start_failed path=$RelativePath`n"
    }
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    $nonWarningStderr = @(
        $stderr -split "`r?`n" |
            Where-Object {
                $_ -and
                $_ -notmatch '^warning:' -and
                $_ -notmatch 'LF will be replaced by CRLF' -and
                $_ -notmatch 'CRLF will be replaced by LF'
            }
    )

    if ($process.ExitCode -ne 0 -and $nonWarningStderr.Count -gt 0) {
        return "diff_status: git_diff_failed path=$RelativePath exit_code=$($process.ExitCode)`n$($nonWarningStderr -join [Environment]::NewLine)`n"
    }
    if ($nonWarningStderr.Count -gt 0) {
        return "$stdout`ndiff_stderr:`n$($nonWarningStderr -join [Environment]::NewLine)`n"
    }
    return $stdout
}

function Find-ExistingVerifyDispatch {
    param([string]$ParentDispatchId)
    foreach ($task in Get-ChildItem -LiteralPath $TasksRoot -Filter "TASK.md" -File -Recurse -ErrorAction SilentlyContinue) {
        $text = Get-Content -Raw -LiteralPath $task.FullName -Encoding UTF8
        if ((Get-PacketField $text "parent_dispatch_id") -eq $ParentDispatchId -and
            (Get-PacketField $text "type") -eq "CODEX_VERIFY") {
            return $task.Directory.Name
        }
    }
    return ""
}

function New-CodexVerifyTask {
    param([string]$ParentDispatchId)
    $existing = Find-ExistingVerifyDispatch -ParentDispatchId $ParentDispatchId
    if ($existing) { return $existing }

    $parentTaskPath = Join-Path $TasksRoot (Join-Path $ParentDispatchId "TASK.md")
    $parentResultPath = Join-Path $TasksRoot (Join-Path $ParentDispatchId "OUTPUTS\RESULT.md")
    $parentResult = if (Test-Path -LiteralPath $parentResultPath) {
        Get-Content -Raw -LiteralPath $parentResultPath -Encoding UTF8
    } elseif ($script:rawOutput) {
        [string]$script:rawOutput
    } else { "" }
    $changedFiles = @(
        [regex]::Matches($parentResult, '(?mi)^changed_file\s*:\s*(.+)$') |
        ForEach-Object { $_.Groups[1].Value.Trim() } |
        Where-Object { $_ }
    )
    # Tolerant parse: workers sometimes wrap the field in markdown emphasis or
    # append a trailing note (e.g. "**change_required: false** (note)").
    # Field semantics still require the key at line start (after decorations).
    $changeRequiredMatch = [regex]::Match(
        $parentResult,
        '(?mi)^[\s>*_-]*change_required\s*[:\uFF1A]\s*\*{0,2}(true|false)\b'
    )
    $changeRequired = if ($changeRequiredMatch.Success) {
        $changeRequiredMatch.Groups[1].Value.ToLowerInvariant()
    } else {
        "unknown"
    }
    $parentOutputDir = Split-Path -Parent $parentResultPath
    $diffPath = Join-Path $parentOutputDir "SCOPED_DIFF.patch"
    $testPath = Join-Path $parentOutputDir "TEST_RESULT.md"
    $bundlePath = Join-Path $parentOutputDir "VERIFY_BUNDLE.md"
    $diffText = ""
    foreach ($changedFile in $changedFiles) {
        $candidate = if ([IO.Path]::IsPathRooted($changedFile)) {
            $changedFile
        } else {
            Join-Path $AgentOSRoot ($changedFile -replace '/', '\')
        }
        if ($candidate.StartsWith($AgentOSRoot, [StringComparison]::OrdinalIgnoreCase)) {
            $relative = $candidate.Substring($AgentOSRoot.Length).TrimStart('\')
            $diffText += Invoke-GitDiffText -RelativePath $relative
        }
    }
    if (-not $diffText) { $diffText = "diff_status: missing_or_empty" }
    Write-Utf8File -Path $diffPath -Content $diffText
    # Same tolerance as change_required: allow markdown decorations, full-width
    # colon, and bold field names. `evidence:` supports query-type tasks whose
    # contract substitutes evidence lines for test_command/test_result.
    $testEvidence = @(
        [regex]::Matches($parentResult, '(?mi)^[\s>*_-]*\*{0,2}(test_command|test_result|verification|evidence)\*{0,2}\s*[:\uFF1A]\s*(.+)$') |
        ForEach-Object { $_.Value.Trim() }
    )
    if (-not $testEvidence.Count) { $testEvidence = @("test_status: missing") }
    Write-Utf8File -Path $testPath -Content ($testEvidence -join [Environment]::NewLine)
    $bundle = @"
# Codex Blind Verify Bundle

parent_dispatch_id: $ParentDispatchId
workflow_version: 1.2
plan_reasoning_included: false
prior_chat_history_included: false
change_required: $changeRequired

## Task Ticket

$parentTaskPath

## Acceptance Criteria

Use only the acceptance criteria and boundaries in the parent task ticket.

## Scoped Diff

$diffPath

## Test Result

$testPath

## Delivery Artifact

$parentResultPath

## Allowed Workspace Paths

$($changedFiles -join [Environment]::NewLine)
"@
    Write-Utf8File -Path $bundlePath -Content $bundle

    $childId = "$ParentDispatchId-codex-verify"
    $childPath = Join-Path $TasksRoot (Join-Path $childId "TASK.md")
    $child = @"
# Task Packet: Codex Blind Verify

dispatch_id: $childId
parent_dispatch_id: $ParentDispatchId
type: CODEX_VERIFY
assigned_to: Codex
route_to: Codex
codex_mode: verify
workflow_version: 1.2
impact_scope: internal_only
dispatch_status: ready_to_route
requires_josh_approval: false
approval: inherited_verify_of_approved_parent
task_status: ready
governance_version: $GovernanceVersion
governance_hash: $GovernanceHash

## Blind Verify Input

Read only this verify bundle and the paths explicitly listed inside it:
$bundlePath

This is a new independent verification session. Do not use plan reasoning or
prior chat history. Use read-only inspection and acceptance criteria only.
If test result or delivery evidence is missing, do not PASS. Missing scoped
diff cannot PASS unless the bundle explicitly says `change_required: false`.

Query-type rule: when the bundle says `change_required: false` AND lists no
changed files, the task is a query-type delivery. In that case at least one
`evidence:` line in the test result is sufficient verification evidence; you
must not FAIL solely because the scoped diff is empty or because
test_command/test_result lines are absent. This rule applies only when both
conditions hold; any changed file re-enables the full test evidence
requirement.

Your response must include exactly one machine-readable verdict line:
verify_verdict: PASS
or
verify_verdict: FAIL
or
verify_verdict: NEEDS_HUMAN_DECISION

Then include findings, evidence, and required changes in Traditional Chinese.
"@
    Write-Utf8File -Path $childPath -Content $child
    return $childId
}

$TasksRoot = Join-Path $AgentOSRoot "data\codex_tasks"
$TaskPath = Join-Path $TasksRoot (Join-Path $DispatchId "TASK.md")
$OutputDir = Join-Path (Split-Path -Parent $TaskPath) "OUTPUTS"
$ResultPath = Join-Path $OutputDir "RESULT.md"
$AgentOutputPath = Join-Path $OutputDir "AGENT_OUTPUT.md"
$HeartbeatPath = Join-Path $OutputDir "HEARTBEAT.json"
$RecoveryStatusPath = Join-Path $OutputDir "RECOVERY_STATUS.md"
$RoutingDecisionPath = Join-Path $AgentOSRoot (Join-Path "data\routing_decisions" (Join-Path $DispatchId "ROUTING_DECISION.md"))

if (-not (Test-Path -LiteralPath $TaskPath -PathType Leaf)) {
    Write-Error "TASK.md not found: $TaskPath"
    exit 1
}

if (Test-Path -LiteralPath $ResultPath -PathType Leaf) {
    $attemptDir = Join-Path $OutputDir "ATTEMPTS"
    New-Item -ItemType Directory -Force -Path $attemptDir | Out-Null
    $attemptStamp = Get-Date -Format "yyyyMMdd-HHmmss-fff"
    Copy-Item -LiteralPath $ResultPath `
        -Destination (Join-Path $attemptDir "RESULT-$attemptStamp.md")
}

$taskText = Get-Content -Raw -LiteralPath $TaskPath -Encoding UTF8
$GovernanceVersion = Get-PacketField $taskText "governance_version"
$GovernanceHash = Get-PacketField $taskText "governance_hash"
if (-not $GovernanceVersion -or -not $GovernanceHash) {
    Write-Output "status=blocked"
    Write-Output "reason=task_governance_binding_missing"
    Write-Output "task_path=$TaskPath"
    exit 4
}

$governanceGate = Join-Path $AgentOSRoot "scripts\assert_governance_ready.ps1"
$codexModeEarly = ([string](Get-PacketField $taskText "codex_mode")).ToLowerInvariant()
$typeEarly = Get-PacketField $taskText "type"
$useReadOnlyGate = ($codexModeEarly -eq "verify" -or $typeEarly -eq "CODEX_VERIFY")
$gateArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $governanceGate,
    "-AgentOSRoot", $AgentOSRoot, "-TaskPath", $TaskPath)
if ($useReadOnlyGate) { $gateArgs += "-ReadOnly" }
$governanceOutput = & powershell.exe @gateArgs
if ($LASTEXITCODE -ne 0) {
    Write-Output "status=blocked"
    Write-Output "reason=governance_gate_blocked"
    Write-Output "phase=governance"
    Write-Output ($governanceOutput -join [Environment]::NewLine)
    exit 3
}

$decisionText = ""
if (Test-Path -LiteralPath $RoutingDecisionPath -PathType Leaf) {
    $decisionText = Get-Content -Raw -LiteralPath $RoutingDecisionPath -Encoding UTF8
}

$assignedTo = Get-PacketField $taskText "assigned_to"
$RouteTo = Get-PacketField $taskText "route_to"
if (-not $RouteTo) {
    if ($assignedTo -match '^Claude') { $RouteTo = "Claude" }
    elseif ($assignedTo -eq "Ollama") { $RouteTo = "Ollama" }
    elseif ($assignedTo -eq "Codex") { $RouteTo = "Codex" }
}
$type = Get-PacketField $taskText "type"
$codexMode = ([string](Get-PacketField $taskText "codex_mode")).ToLowerInvariant()
$CodexModeForResult = if ($RouteTo -eq "Codex") { $codexMode } else { "n/a" }
$impactScope = ([string](Get-PacketField $taskText "impact_scope")).ToLowerInvariant()

$dispatchStatus = if ($decisionText) {
    Get-PacketField $decisionText "dispatch_status"
} else {
    Get-PacketField $taskText "dispatch_status"
}
$requiresApprovalText = if ($decisionText) {
    Get-PacketField $decisionText "requires_josh_approval"
} else {
    Get-PacketField $taskText "requires_josh_approval"
}
$approval = Get-PacketField $taskText "approval"
if (-not $approval -and $decisionText) {
    $approval = Get-PacketField $decisionText "approval"
}

if ($dispatchStatus -ne "ready_to_route") {
    Write-CanonicalResult -Status "blocked" -ModelsInvoked $false -ScriptsExecuted $false `
        -Findings "Dispatch was not executed." `
        -Caveats "dispatch_status must be ready_to_route; actual=$dispatchStatus"
    Write-Output "status=approval_required"
    Write-Output "dispatch_status=$dispatchStatus"
    Write-Output "models_invoked=false"
    exit 5
}

$approvalRequired = (Convert-ToBool $requiresApprovalText) -or
    ($RouteTo -eq "Codex" -and $codexMode -eq "build")
if ($approvalRequired -and [string]::IsNullOrWhiteSpace($approval)) {
    Write-CanonicalResult -Status "blocked" -ModelsInvoked $false -ScriptsExecuted $false `
        -Findings "Dispatch was stopped before CLI invocation." `
        -Caveats "Approval evidence is required for this route."
    Write-Output "status=approval_required"
    Write-Output "reason=approval_evidence_missing"
    Write-Output "models_invoked=false"
    exit 6
}

$promptPath = Join-Path $OutputDir "DISPATCH_PROMPT.md"
$promptContent = $taskText
if ($RouteTo -eq "Codex" -and $codexMode -eq "verify" -and
    -not ([regex]::IsMatch($promptContent, '(?m)^verify_verdict\s*:\s*PASS\s*$'))) {
    $promptContent += @"

## Required Machine-Readable Verdict

Your response must include exactly one machine-readable verdict line:
verify_verdict: PASS
or
verify_verdict: FAIL
or
verify_verdict: NEEDS_HUMAN_DECISION

Then include findings, evidence, and required changes in Traditional Chinese.
"@
}
# Added 2026-07-28: a systemic audit (triggered by repeated Verify FAIL
# investigations) found that only ~2 of ~95 completed tickets' RESULT.md
# ever populate the files_modified:/files_created: fields that
# docs\EVIDENCE_AND_REPORTING_CONTRACT.md Section 3 has required since
# 2026-06-24 - the contract exists but nothing in this dispatch pipeline ever
# asked the Builder to follow it, so create_codex_verify_task.ps1 has to
# guess changed files from free-form prose, which the same audit showed
# produces both false negatives (real changes missed) and false positives
# (API endpoints/directories/wildcards/example filenames mistaken for real
# files). This block asks every Builder-mode dispatch (Codex build or Claude
# Worker) to end its response with an explicit changed_file:/change_required:
# manifest, mirroring the verify_verdict block above. It does not change the
# Evidence and Reporting Contract itself (still requires Josh approval to
# edit docs\EVIDENCE_AND_REPORTING_CONTRACT.md) - this only asks the Builder
# to actually satisfy the "files_modified/files_created" spirit of the
# contract using the same changed_file:/change_required: convention that
# create_codex_verify_task.ps1 already parses as its highest-priority signal.
$builderModeForManifest = (($RouteTo -eq "Codex" -and $codexMode -eq "build") -or
    ($RouteTo -eq "Claude" -and $assignedTo -match '^Claude'))
if ($builderModeForManifest -and
    -not ([regex]::IsMatch($promptContent, '(?im)^\s*changed_file\s*:'))) {
    $promptContent += @"

## Required Machine-Readable Change Manifest

Per docs\EVIDENCE_AND_REPORTING_CONTRACT.md Section 3 (files_modified/
files_created are required fields), end your response with an explicit
change manifest so an independent Verify session can build an accurate
scoped diff without guessing from prose:

changed_file: <repo-relative path you actually created, modified, or deleted>
changed_file: <repo-relative path>
change_required: true

If this delivery made no code/content changes (query-type, read-only
analysis, or pure investigation), instead write exactly:

change_required: false

List only real files this delivery actually touched - not files you merely
read or referenced as examples, not files planned for a future round, and
not directories, API endpoints, or wildcard patterns.
"@
}
Write-Utf8File -Path $promptPath -Content $promptContent
$commandDescription = ""
$rawOutput = ""
$exitCode = 0
$failureReason = ""
$failurePhase = ""
$elapsedSeconds = 0

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

# Pillar B ground-truth snapshot (before): see Get-GitStatusSnapshot comment.
$gitSnapshotBefore = Get-GitStatusSnapshot -AgentOSRoot $AgentOSRoot

switch ($RouteTo) {
    "Codex" {
        if ($codexMode -notin @("build", "plan", "verify")) {
            Write-CanonicalResult -Status "blocked" -ModelsInvoked $false -ScriptsExecuted $false `
                -Findings "Codex route was not executed." `
                -Caveats "codex_mode must be build, plan, or verify."
            Write-Output "status=blocked"
            Write-Output "reason=invalid_codex_mode"
            exit 7
        }
        $sandboxMode = if ($codexMode -in @("build", "plan")) { "workspace-write" } else { "read-only" }
        $npmCodex = if ($env:APPDATA) { Join-Path $env:APPDATA "npm\codex.cmd" } else { "" }
        $codexCommand = if ($npmCodex -and (Test-Path -LiteralPath $npmCodex -PathType Leaf)) {
            $npmCodex
        } else {
            "codex"
        }
        $commandDescription = "`"$codexCommand`" -a never exec -C `"$AgentOSRoot`" --sandbox $sandboxMode --output-last-message `"$AgentOutputPath`" -"
        if (-not $DryRun) {
            # Use cmd.exe file redirection so Codex receives the UTF-8 prompt
            # bytes unchanged. Remove stale API-key overrides only in the child
            # process; Codex can then use its own persisted login.
            $psi = [Diagnostics.ProcessStartInfo]::new()
            $psi.FileName = "cmd.exe"
            $psi.WorkingDirectory = $AgentOSRoot
            $psi.UseShellExecute = $false
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
            $psi.StandardErrorEncoding = [Text.Encoding]::UTF8
            # chcp 65001 keeps the child console in UTF-8 so the CP950 default
            # cannot mangle the UTF-8 prompt fed through stdin redirection.
            $psi.Arguments = '/d /c "chcp 65001 >nul && "' + $codexCommand + '" -a never exec -C "' + $AgentOSRoot +
                '" --sandbox ' + $sandboxMode + ' --output-last-message "' +
                $AgentOutputPath + '" - < "' + $promptPath + '""'
            [void](Set-TestAgentStartInfo -StartInfo $psi)
            $process = [Diagnostics.Process]::new()
            $process.StartInfo = $psi
            # Start Codex without inherited API-key overrides so it uses its
            # persisted login. Temporarily clearing this dispatcher process is
            # compatible with Windows PowerShell 5.1, whose ProcessStartInfo
            # environment collection may be null.
            $savedOpenAiKey = [Environment]::GetEnvironmentVariable("OPENAI_API_KEY", "Process")
            $savedCodexKey = [Environment]::GetEnvironmentVariable("CODEX_API_KEY", "Process")
            # Bug found 2026-07-28 (Josh traced a FAIL verdict with
            # exit_code=1/elapsed_seconds=0 back to this exact spot): the
            # read-back below only checked whether $AgentOutputPath *exists*,
            # not whether THIS invocation actually wrote it. Codex writes that
            # file itself via --output-last-message; if this run crashes
            # before Codex gets that far (e.g. the ~0-second exit_1 case),
            # the file left over from a PRIOR dispatch of the same
            # dispatch_id is still sitting there and gets silently reused as
            # if it were this run's fresh output - so a stale FAIL/PASS
            # verdict from a previous attempt gets re-reported as if an
            # independent blind verify had just happened. Recording the
            # invocation start time lets the read-back require the file's
            # last-write time to be at/after this specific process start.
            $agentInvocationStartUtc = [DateTime]::UtcNow
            try {
                [Environment]::SetEnvironmentVariable("OPENAI_API_KEY", $null, "Process")
                [Environment]::SetEnvironmentVariable("CODEX_API_KEY", $null, "Process")
                [void]$process.Start()
            } finally {
                [Environment]::SetEnvironmentVariable("OPENAI_API_KEY", $savedOpenAiKey, "Process")
                [Environment]::SetEnvironmentVariable("CODEX_API_KEY", $savedCodexKey, "Process")
            }
            $stdoutTask = $process.StandardOutput.ReadToEndAsync()
            $stderrTask = $process.StandardError.ReadToEndAsync()
            $execution = Invoke-BoundedProcess -Process $process -StdoutTask $stdoutTask -StderrTask $stderrTask -Phase "codex_$codexMode"
            $exitCode = $execution.ExitCode
            $elapsedSeconds = $execution.ElapsedSeconds
            if ($execution.TimedOut) { $failureReason = "agent_timeout"; $failurePhase = "codex_$codexMode" }
            $consoleOutput = ($execution.Stdout + "`n" + $execution.Stderr).Trim()
            $agentOutputIsFresh = (Test-Path -LiteralPath $AgentOutputPath -PathType Leaf) -and
                ((Get-Item -LiteralPath $AgentOutputPath).LastWriteTimeUtc -ge $agentInvocationStartUtc)
            if ($agentOutputIsFresh) {
                $rawOutput = Get-Content -Raw -LiteralPath $AgentOutputPath -Encoding UTF8
            } else {
                if (Test-Path -LiteralPath $AgentOutputPath -PathType Leaf) {
                    $failureReason = if ($failureReason) { $failureReason } else { "stale_agent_output_ignored" }
                    $consoleOutput = "$consoleOutput`n[stale_agent_output_ignored: $AgentOutputPath predates this invocation (last_write=$((Get-Item -LiteralPath $AgentOutputPath).LastWriteTimeUtc.ToString('o'))); a prior attempt's leftover result was NOT reused]".Trim()
                }
                $rawOutput = $consoleOutput
            }
        }
    }
    "Claude" {
        if ($assignedTo -notmatch '^Claude\s+(Worker|Inspector)$') {
            throw "Unsupported Claude assigned_to value: $assignedTo"
        }
        # info_query packets get read-only network tools so pure information
        # requests no longer fail on a worker without web access (route A).
        $taskKindForClaude = ([string](Get-PacketField $taskText "task_kind")).ToLowerInvariant()
        $claudeExtraArgs = if ($taskKindForClaude -eq "info_query") {
            ' --allowedTools "WebSearch" "WebFetch"'
        } else {
            ''
        }
        $commandDescription = "claude -p --permission-mode acceptEdits --no-session-persistence$claudeExtraArgs < `"$promptPath`""
        if (-not $DryRun) {
            $psi = [Diagnostics.ProcessStartInfo]::new()
            $psi.FileName = "cmd.exe"
            $psi.WorkingDirectory = $AgentOSRoot
            $psi.UseShellExecute = $false
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
            $psi.StandardErrorEncoding = [Text.Encoding]::UTF8
            # chcp 65001 keeps the child console in UTF-8 so the CP950 default
            # cannot mangle the UTF-8 prompt fed through stdin redirection.
            $psi.Arguments = '/d /c chcp 65001 >nul && claude -p --permission-mode acceptEdits --no-session-persistence' + $claudeExtraArgs + ' < "' + $promptPath + '"'
            [void](Set-TestAgentStartInfo -StartInfo $psi)
            $process = [Diagnostics.Process]::new()
            $process.StartInfo = $psi
            [void]$process.Start()
            $stdoutTask = $process.StandardOutput.ReadToEndAsync()
            $stderrTask = $process.StandardError.ReadToEndAsync()
            $execution = Invoke-BoundedProcess -Process $process -StdoutTask $stdoutTask -StderrTask $stderrTask -Phase "claude_worker"
            $exitCode = $execution.ExitCode
            $elapsedSeconds = $execution.ElapsedSeconds
            if ($execution.TimedOut) { $failureReason = "agent_timeout"; $failurePhase = "claude_worker" }
            $rawOutput = $execution.Stdout.Trim()
            if (-not $rawOutput) { $rawOutput = $execution.Stderr.Trim() }
            if ($rawOutput) {
                Write-Utf8File -Path $AgentOutputPath -Content $rawOutput
            }
        }
    }
    "Ollama" {
        $ollamaModel = Get-PacketField $taskText "ollama_model"
        if (-not $ollamaModel) {
            Write-CanonicalResult -Status "blocked" -ModelsInvoked $false -ScriptsExecuted $false `
                -Findings "Ollama route was not executed." `
                -Caveats "TASK.md must include an explicit ollama_model."
            Write-Output "status=blocked"
            Write-Output "reason=ollama_model_missing"
            exit 8
        }
        $commandDescription = "ollama run $ollamaModel < `"$promptPath`""
        if (-not $DryRun) {
            $oldEap = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            try {
                $rawOutput = Get-Content -Raw -LiteralPath $promptPath | & ollama run $ollamaModel 2>&1 | Out-String
                $exitCode = $LASTEXITCODE
            } finally {
                $ErrorActionPreference = $oldEap
            }
        }
    }
    "Antigravity CLI" {
        $ConfigPath = Join-Path $AgentOSRoot "config\antigravity_subagents.json"
        if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
            Write-CanonicalResult -Status "blocked" -ModelsInvoked $false -ScriptsExecuted $false `
                -Findings "Antigravity CLI route was not executed." `
                -Caveats "Configuration file not found: $ConfigPath"
            Write-Output "status=blocked"
            Write-Output "reason=config_file_missing"
            exit 10
        }
        
        $subagentMode = Get-PacketField $taskText "subagent_mode"
        $riskLevel = Get-PacketField $taskText "risk_level"
        $writeScope = (Get-PacketField $taskText "write_scope").ToLowerInvariant()
        
        # Load config
        $config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        
        # Find explicit worker_alias in TASK.md if exists
        $workerAlias = Get-PacketField $taskText "worker_alias"
        if (-not $workerAlias) {
            # Find the first enabled worker matching the mode and risk level
            $matchedWorker = $config.workers | Where-Object { 
                $_.enabled -and 
                $_.allowed_modes -contains $subagentMode -and
                $_.allowed_risk_levels -contains $riskLevel
            } | Select-Object -First 1
            if ($matchedWorker) {
                $workerAlias = $matchedWorker.alias
            }
        }
        
        if (-not $workerAlias) {
            # Fallback to check if there is any worker matching mode and risk (even if disabled) to report alias
            $fallbackWorker = $config.workers | Where-Object {
                $_.allowed_modes -contains $subagentMode -and
                $_.allowed_risk_levels -contains $riskLevel
            } | Select-Object -First 1
            if ($fallbackWorker) {
                $workerAlias = $fallbackWorker.alias
            } else {
                Write-CanonicalResult -Status "blocked" -ModelsInvoked $false -ScriptsExecuted $false `
                    -Findings "Antigravity CLI route was not executed." `
                    -Caveats "No suitable Antigravity subagent worker found for mode '$subagentMode' and risk_level '$riskLevel'."
                Write-Output "status=blocked"
                Write-Output "reason=no_matching_worker"
                exit 11
            }
        }
        
        $commandDescription = "powershell -File scripts\invoke_antigravity_subagent.ps1 -TaskPath `"$TaskPath`" -WorkerAlias $workerAlias"
        if (-not $DryRun) {
            $oldEap = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            try {
                if ($TestAgentScript) {
                    $invokeOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $TestAgentScript $AgentOutputPath 2>&1
                } else {
                    $invokeScript = Join-Path $AgentOSRoot "scripts\invoke_antigravity_subagent.ps1"
                    $invokeOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $invokeScript -TaskPath $TaskPath -WorkerAlias $workerAlias 2>&1
                }
                $exitCode = $LASTEXITCODE
            } finally {
                $ErrorActionPreference = $oldEap
            }
            $invokeSummary = $invokeOutput -join [Environment]::NewLine            # A real Antigravity worker writes its own rich RESULT.md. Preserve
            # that content as canonical Findings instead of replacing it with
            # only invoke_antigravity_subagent.ps1's short status receipt.
            $rawOutput = if (-not $TestAgentScript -and (Test-Path -LiteralPath $ResultPath -PathType Leaf)) {
                Get-Content -Raw -LiteralPath $ResultPath -Encoding UTF8
            } elseif (Test-Path -LiteralPath $AgentOutputPath -PathType Leaf) {
                Get-Content -Raw -LiteralPath $AgentOutputPath -Encoding UTF8
            } else {
                $invokeSummary
            }
            if ($rawOutput -and -not (Test-Path -LiteralPath $AgentOutputPath -PathType Leaf)) {
                Write-Utf8File -Path $AgentOutputPath -Content $rawOutput
            }
        }
    }
    default {
        Write-CanonicalResult -Status "blocked" -ModelsInvoked $false -ScriptsExecuted $false `
            -Findings "No CLI was invoked." `
            -Caveats "Unsupported route_to value: $RouteTo"
        Write-Output "status=blocked"
        Write-Output "reason=unsupported_route"
        exit 9
    }
}

# Pillar B ground-truth snapshot (after) + independent diff. Skipped for
# DryRun (no agent ran, nothing changed by definition) so it doesn't write a
# misleading "captured, zero changes" record for a structural dry run.
if (-not $DryRun) {
    $gitSnapshotAfter = Get-GitStatusSnapshot -AgentOSRoot $AgentOSRoot
    $dispatchOutputPrefix = "data/codex_tasks/$DispatchId/OUTPUTS"
    Write-GitVerifiedChanges -Before $gitSnapshotBefore -After $gitSnapshotAfter `
        -OutputPath (Join-Path $OutputDir "GIT_VERIFIED_CHANGES.json") `
        -IgnoredRelativePaths @(
            "$dispatchOutputPrefix/AGENT_OUTPUT.md",
            "$dispatchOutputPrefix/HEARTBEAT.json"
        )
}

if ($DryRun) {
    $rawOutput = "DRY RUN: command plan only; no model or external service invoked.`n$commandDescription"
    $exitCode = 0
}

if ($exitCode -ne 0) {
    if (-not $failureReason) { $failureReason = "agent_exit_$exitCode" }
    if (-not $failurePhase) { $failurePhase = "agent_execution" }
    if (Test-Path -LiteralPath $AgentOutputPath -PathType Leaf) {
        Write-RecoveryStatus -Reason $failureReason -Phase $failurePhase -Detail "Agent output exists after nonzero execution result."
    }
    Write-CanonicalResult -Status "partial_failure" -ModelsInvoked (-not $DryRun) -ScriptsExecuted (-not $DryRun) `
        -Findings $rawOutput -Caveats "reason=$failureReason phase=$failurePhase exit_code=$exitCode elapsed_seconds=$elapsedSeconds"
    Write-Output "status=partial_failure"
    Write-Output "reason=$failureReason"
    Write-Output "phase=$failurePhase"
    Write-Output "elapsed_seconds=$elapsedSeconds"
    Write-Output "result_path=$ResultPath"
    if (Test-Path -LiteralPath $RecoveryStatusPath) { Write-Output "recovery_status_path=$RecoveryStatusPath" }
    Write-Output "exit_code=$exitCode"
    exit $exitCode
}

if ($RouteTo -eq "Codex" -and $codexMode -eq "verify" -and -not $DryRun) {
    $verdictMatches = [regex]::Matches($rawOutput, '(?im)^\s*verify_verdict\s*:\s*(PASS|FAIL|NEEDS_HUMAN_DECISION)\s*$')
    $evidenceText = [regex]::Replace(
        $rawOutput,
        '(?im)^\s*verify_verdict\s*:\s*(PASS|FAIL|NEEDS_HUMAN_DECISION)\s*$',
        ''
    ).Trim()
    if ($verdictMatches.Count -ne 1 -or -not $evidenceText) {
        $failureReason = "invalid_verify_output"
        $failurePhase = "codex_verify_validation"
        $detail = if ($verdictMatches.Count -ne 1) {
            "Expected exactly one machine-readable verify_verdict line; found $($verdictMatches.Count)."
        } else {
            "Verifier returned a verdict without findings or evidence."
        }
        Write-RecoveryStatus -Reason $failureReason -Phase $failurePhase -Detail $detail
        Write-CanonicalResult -Status "partial_failure" -ModelsInvoked $true -ScriptsExecuted $true `
            -Findings $rawOutput -Caveats "reason=$failureReason phase=$failurePhase recovery_status_path=$RecoveryStatusPath detail=$detail"
        Write-Output "status=partial_failure"
        Write-Output "reason=$failureReason"
        Write-Output "phase=$failurePhase"
        Write-Output "result_path=$ResultPath"
        Write-Output "recovery_status_path=$RecoveryStatusPath"
        Write-Output "exit_code=12"
        exit 12
    }
}

$reviewDispatchId = ""
$builderCompleted = (($RouteTo -eq "Claude" -and $assignedTo -eq "Claude Worker") -or
    ($RouteTo -eq "Codex" -and $codexMode -eq "build") -or
    ($RouteTo -eq "Antigravity CLI" -and $writeScope -eq "workspace-write fallback"))
if ($builderCompleted) {
    # The bundle builder reads the parent's RESULT.md. On a first-time
    # dispatch there is no prior RESULT, so creating the bundle before this
    # write deterministically failed (or, on retries, consumed a stale
    # RESULT). Write the completed delivery first with a temporary
    # review_dispatch_id:not_created; after the child id is known, the
    # canonical write below updates only that reference.
    Write-CanonicalResult -Status "completed" -ModelsInvoked (-not $DryRun) -ScriptsExecuted (-not $DryRun) `
        -Findings $rawOutput `
        -Caveats $(if ($DryRun) { "Structural dry run only; command was not executed." } else { "none" })
    try {
        if ($TestPostprocessError) { throw "test_postprocess_failure" }
        # 2026-07-28: delegate to the single, actively-maintained verify-bundle
        # builder instead of the local (deprecated, still-buggy) New-CodexVerifyTask
        # defined above. See the DEPRECATED comment above Invoke-GitDiffText.
        $verifyScriptPath = Join-Path $PSScriptRoot "create_codex_verify_task.ps1"
        $verifyOutputLines = @(
            & $verifyScriptPath -ParentDispatchId $DispatchId -AgentOSRoot $AgentOSRoot 2>&1 |
                ForEach-Object { [string]$_ }
        )
        $verifyIdLine = $verifyOutputLines | Where-Object { $_ -match '^verify_dispatch_id=' } | Select-Object -Last 1
        $reviewDispatchId = if ($verifyIdLine) { ($verifyIdLine -split '=', 2)[1] } else { "" }
        if (-not $reviewDispatchId) {
            throw "verify_bundle_creation_produced_no_dispatch_id: $($verifyOutputLines -join ' | ')"
        }
    } catch {
        Write-RecoveryStatus -Reason "postprocess_failure_recoverable" -Phase "verify_bundle" -Detail $_.Exception.Message
        Write-CanonicalResult -Status "completed_with_recovery" -ModelsInvoked (-not $DryRun) -ScriptsExecuted (-not $DryRun) `
            -Findings $rawOutput -Caveats "reason=postprocess_failure_recoverable phase=verify_bundle recovery_status_path=$RecoveryStatusPath"
        Write-Output "status=completed_with_recovery"
        Write-Output "reason=postprocess_failure_recoverable"
        Write-Output "phase=verify_bundle"
        Write-Output "result_path=$ResultPath"
        Write-Output "recovery_status_path=$RecoveryStatusPath"
        exit 0
    }
}

Write-CanonicalResult -Status "completed" -ModelsInvoked (-not $DryRun) -ScriptsExecuted (-not $DryRun) `
    -Findings $rawOutput `
    -Caveats $(if ($DryRun) { "Structural dry run only; command was not executed." } else { "none" }) `
    -ReviewDispatchId $reviewDispatchId

Write-Output "status=completed"
Write-Output "dispatch_id=$DispatchId"
Write-Output "route_to=$RouteTo"
Write-Output "codex_mode=$CodexModeForResult"
Write-Output "result_path=$ResultPath"
Write-Output "models_invoked=$(((-not $DryRun)).ToString().ToLowerInvariant())"
Write-Output "scripts_executed=$(((-not $DryRun)).ToString().ToLowerInvariant())"
Write-Output "review_dispatch_id=$(if ($reviewDispatchId) { $reviewDispatchId } else { 'not_created' })"
exit 0

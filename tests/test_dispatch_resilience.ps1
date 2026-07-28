[CmdletBinding()]
param([string]$AgentOSRoot = "E:\AgentOS")

$ErrorActionPreference = "Stop"
$dispatcher = Join-Path $AgentOSRoot "scripts\dispatch_task_packet.ps1"
$tasksRoot = Join-Path $AgentOSRoot "data\codex_tasks"
$status = Get-Content -Raw (Join-Path $AgentOSRoot "data\governance\governance_status.json") -Encoding UTF8 | ConvertFrom-Json
$hash = $status.canonical_hash
$version = $status.governance_version
$successScript = Join-Path $AgentOSRoot "tests\fixtures\fake_agent_success.ps1"
$timeoutScript = Join-Path $AgentOSRoot "tests\fixtures\fake_agent_timeout.ps1"
$exitScript = Join-Path $AgentOSRoot "tests\fixtures\fake_agent_exit7.ps1"
$utf8 = [Text.UTF8Encoding]::new($false)
$failures = [Collections.Generic.List[string]]::new()
$timeoutBudgetSeconds = 1
# The outer stopwatch includes governance refresh, a new powershell.exe startup,
# the 1-second agent budget and up to 5 seconds of process-tree cleanup. Measured
# on 2026-07-20: 15.047s isolated and 21s under full-smoke load (two runs).
# Keep a bounded 30s wall-clock margin while separately asserting below that the
# agent reached timeout cleanup within the configured 1s budget (+1s scheduler
# tolerance). This does not weaken the dispatcher timeout or heartbeat contract.
$timeoutWallClockBoundSeconds = 30

function New-FixtureTask([string]$Id, [string]$RouteTo = "Claude", [string]$CodexMode = "n/a") {
    $dir = Join-Path $tasksRoot $Id
    $outputs = Join-Path $dir "OUTPUTS"
    New-Item -ItemType Directory -Force -Path $outputs | Out-Null
    $antigravityFields = if ($RouteTo -eq "Antigravity CLI") {
@"
subagent_mode: test
risk_level: low
write_scope: read-only
worker_alias: antigravity_research_auditor
"@
    } else { "" }
    $task = @"
# Offline Dispatcher Resilience Fixture

dispatch_id: $Id
type: CLAUDE_WORKER
assigned_to: $(if ($RouteTo -eq "Codex") { "Codex" } else { "Claude Worker" })
route_to: $RouteTo
codex_mode: $CodexMode
task_kind: workspace_change
task_type: Simple
workflow_version: 1.3
task_status: ready
dispatch_status: ready_to_route
requires_josh_approval: false
approval: offline_fixture
governance_version: $version
governance_hash: $hash
$antigravityFields

## Acceptance Criteria

- Exercise fake local agent only.
"@
    [IO.File]::WriteAllText((Join-Path $dir "TASK.md"), $task, $utf8)
    return $dir
}

function Invoke-Fixture([string]$Id, [string]$Script, [int]$Timeout, [switch]$PostprocessError) {
    $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $dispatcher,
        "-DispatchId", $Id, "-AgentOSRoot", $AgentOSRoot,
        "-AgentTimeoutSeconds", $Timeout, "-HeartbeatIntervalSeconds", 1,
        "-TestAgentScript", $Script)
    if ($PostprocessError) { $args += "-TestPostprocessError" }
    $output = & powershell.exe @args 2>&1
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Text = ($output -join "`n") }
}

$successId = "ci-dispatch-resilience-success"
$successDir = New-FixtureTask $successId
$success = Invoke-Fixture $successId $successScript 10
if ($success.ExitCode -ne 0 -or $success.Text -notmatch '(?m)^status=completed$') {
    $failures.Add("success fixture failed: exit=$($success.ExitCode) output=$($success.Text)")
}

$timeoutId = "ci-dispatch-resilience-timeout"
$timeoutDir = New-FixtureTask $timeoutId
$timer = [Diagnostics.Stopwatch]::StartNew()
$timeout = Invoke-Fixture $timeoutId $timeoutScript $timeoutBudgetSeconds
$timer.Stop()
if ($timeout.ExitCode -ne 124 -or $timeout.Text -notmatch '(?m)^reason=agent_timeout$') {
    $failures.Add("timeout fixture missing exact reason: exit=$($timeout.ExitCode) output=$($timeout.Text)")
}
if ($timer.Elapsed.TotalSeconds -gt $timeoutWallClockBoundSeconds) {
    $failures.Add("timeout fixture exceeded bound: $([int]$timer.Elapsed.TotalSeconds)s")
}
$pidPath = Join-Path $timeoutDir "OUTPUTS\AGENT_OUTPUT.md.pid"
if (-not (Test-Path $pidPath)) { $failures.Add("timeout fixture pid evidence missing") }
else {
    $fakePid = [int](Get-Content -Raw $pidPath)
    if (Get-Process -Id $fakePid -ErrorAction SilentlyContinue) {
        $failures.Add("timeout fixture child process still running: $fakePid")
    }
}
$heartbeat = Join-Path $timeoutDir "OUTPUTS\HEARTBEAT.json"
if (-not (Test-Path $heartbeat)) { $failures.Add("timeout heartbeat missing") }
else {
    $hb = Get-Content -Raw $heartbeat -Encoding UTF8 | ConvertFrom-Json
    if ($hb.dispatch_id -ne $timeoutId -or $hb.phase -ne "agent_timeout_cleanup" -or -not $hb.agent_pid) {
        $failures.Add("heartbeat fields invalid")
    }
    if ([int]$hb.elapsed_seconds -gt ($timeoutBudgetSeconds + 1)) {
        $failures.Add("agent timeout heartbeat exceeded configured budget: $($hb.elapsed_seconds)s")
    }
}

$exitId = "ci-dispatch-resilience-exit7"
New-FixtureTask $exitId | Out-Null
$nonzero = Invoke-Fixture $exitId $exitScript 10
if ($nonzero.ExitCode -ne 7 -or $nonzero.Text -notmatch '(?m)^reason=agent_exit_7$') {
    $failures.Add("nonzero fixture lost exit code: exit=$($nonzero.ExitCode) output=$($nonzero.Text)")
}

$recoveryId = "ci-dispatch-resilience-postprocess"
$recoveryDir = New-FixtureTask $recoveryId
$recovery = Invoke-Fixture $recoveryId $successScript 10 -PostprocessError
$recoveryPath = Join-Path $recoveryDir "OUTPUTS\RECOVERY_STATUS.md"
if ($recovery.ExitCode -ne 0 -or $recovery.Text -notmatch '(?m)^reason=postprocess_failure_recoverable$' -or -not (Test-Path $recoveryPath)) {
    $failures.Add("postprocess recovery failed: exit=$($recovery.ExitCode) output=$($recovery.Text)")
}

$invalidVerifyId = "ci-dispatch-resilience-invalid-verify"
New-FixtureTask $invalidVerifyId "Codex" "verify" | Out-Null
$invalidVerify = Invoke-Fixture $invalidVerifyId $successScript 10
if ($invalidVerify.ExitCode -ne 12 -or $invalidVerify.Text -notmatch '(?m)^reason=invalid_verify_output$' -or $invalidVerify.Text -notmatch '(?m)^phase=codex_verify_validation$') {
    $failures.Add("verdict-only verify output was not rejected precisely: exit=$($invalidVerify.ExitCode) output=$($invalidVerify.Text)")
}

$codexBuildId = "ci-dispatch-resilience-codex-build"
New-FixtureTask $codexBuildId "Codex" "build" | Out-Null
$codexBuild = Invoke-Fixture $codexBuildId $successScript 10
$verifyTaskPath = Join-Path $tasksRoot "$codexBuildId-codex-verify\TASK.md"
if ($codexBuild.ExitCode -ne 0 -or $codexBuild.Text -notmatch ("(?m)^review_dispatch_id=" + [regex]::Escape("$codexBuildId-codex-verify") + "$") -or -not (Test-Path -LiteralPath $verifyTaskPath)) {
    $failures.Add("Codex Builder did not create independent verify task: exit=$($codexBuild.ExitCode) output=$($codexBuild.Text)")
}

$antigravityTimeoutId = "ci-dispatch-resilience-antigravity-timeout"
$antigravityTimeoutDir = New-FixtureTask $antigravityTimeoutId "Antigravity CLI"
$antigravityTimeout = Invoke-Fixture $antigravityTimeoutId $timeoutScript $timeoutBudgetSeconds
if ($antigravityTimeout.ExitCode -ne 124 -or
    $antigravityTimeout.Text -notmatch '(?m)^reason=agent_timeout$' -or
    $antigravityTimeout.Text -notmatch '(?m)^phase=antigravity_subagent$') {
    $failures.Add("Antigravity timeout lost exact reason/phase: exit=$($antigravityTimeout.ExitCode) output=$($antigravityTimeout.Text)")
}
$antigravityResultPath = Join-Path $antigravityTimeoutDir "OUTPUTS\RESULT.md"
if (-not (Test-Path -LiteralPath $antigravityResultPath -PathType Leaf)) {
    $failures.Add("Antigravity timeout canonical RESULT.md missing")
} else {
    $antigravityResult = Get-Content -Raw -LiteralPath $antigravityResultPath -Encoding UTF8
    if ($antigravityResult -notmatch '(?m)^status: partial_failure$' -or
        $antigravityResult -notmatch 'reason=agent_timeout phase=antigravity_subagent') {
        $failures.Add("Antigravity timeout canonical RESULT.md fields invalid")
    }
}
$antigravityHeartbeatPath = Join-Path $antigravityTimeoutDir "OUTPUTS\HEARTBEAT.json"
if (-not (Test-Path -LiteralPath $antigravityHeartbeatPath -PathType Leaf)) {
    $failures.Add("Antigravity timeout heartbeat missing")
} else {
    $antigravityHeartbeat = Get-Content -Raw -LiteralPath $antigravityHeartbeatPath -Encoding UTF8 | ConvertFrom-Json
    if ($antigravityHeartbeat.dispatch_id -ne $antigravityTimeoutId -or
        $antigravityHeartbeat.phase -ne "agent_timeout_cleanup") {
        $failures.Add("Antigravity timeout heartbeat fields invalid")
    }
}

if ($failures.Count) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Output "dispatch_resilience_status=passed"
Write-Output "case_count=7"
Write-Output "timeout_elapsed_seconds=$([int]$timer.Elapsed.TotalSeconds)"

[CmdletBinding()]
param([string]$AgentOSRoot = "E:\AgentOS")

$ErrorActionPreference = "Stop"
$tasksRoot = Join-Path $AgentOSRoot "data\codex_tasks"
$stateRoot = Join-Path $AgentOSRoot "data\queue_runs"
$status = Get-Content -Raw (Join-Path $AgentOSRoot "data\governance\governance_status.json") -Encoding UTF8 | ConvertFrom-Json
$utf8 = [Text.UTF8Encoding]::new($false)
$runner = Join-Path $AgentOSRoot "scripts\task_queue_runner.ps1"
$fake = Join-Path $AgentOSRoot "tests\fixtures\fake_dispatcher_resilience.ps1"
$failures = [Collections.Generic.List[string]]::new()

function New-Task([string]$Id, [string]$RootId, [int]$Order, [string]$Route, [string]$Type, [string]$Mode) {
    $dir = Join-Path $tasksRoot $Id
    New-Item -ItemType Directory -Force -Path (Join-Path $dir "OUTPUTS") | Out-Null
    $task = @"
dispatch_id: $Id
parent_dispatch_id: $RootId
source_dispatch_id: $RootId
dependency_order: $Order
depends_on: parent_created:$RootId
type: $Type
assigned_to: $(if($Route -eq "Claude"){"Claude Worker"}else{"Codex"})
route_to: $Route
codex_mode: $Mode
task_type: Simple
task_status: ready
dispatch_status: ready_to_route
governance_version: $($status.governance_version)
governance_hash: $($status.canonical_hash)
"@
    [IO.File]::WriteAllText((Join-Path $dir "TASK.md"), $task, $utf8)
}

function New-Root([string]$Id) {
    $dir = Join-Path $tasksRoot $Id
    New-Item -ItemType Directory -Force -Path (Join-Path $dir "OUTPUTS") | Out-Null
    $task = "dispatch_id: $Id`ntype: ROOT`nroute_to: Hermes`ntask_status: created`ndispatch_status: created`ngovernance_version: $($status.governance_version)`ngovernance_hash: $($status.canonical_hash)`n"
    [IO.File]::WriteAllText((Join-Path $dir "TASK.md"), $task, $utf8)
    $state = @{root_dispatch_id=$Id; process_id=$PID; started_at=(Get-Date -Format o); status="running"} | ConvertTo-Json
    [IO.File]::WriteAllText((Join-Path $stateRoot "$Id.json"), $state, $utf8)
}

$runSuffix = "$PID-$(Get-Date -Format 'HHmmssfff')"
$failoverRoot = "ci-queue-failover-root-$runSuffix"
$failoverId = "ci-queue-failover-child-$runSuffix"
New-Root $failoverRoot
New-Task $failoverId $failoverRoot 1 "Claude" "CLAUDE_WORKER" "n/a"
$failoverOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -AgentOSRoot $AgentOSRoot -RootDispatchId $failoverRoot -PollSeconds 0 -MaxTasksPerRun 6 -MaxAttemptsPerRoute 2 -DispatcherPath $fake -Environment ci 2>&1
if ($LASTEXITCODE -ne 0) { $failures.Add("failover queue exited nonzero") }
$failoverTask = Get-Content -Raw (Join-Path $tasksRoot "$failoverId\TASK.md") -Encoding UTF8
$failoverAttempts = @(Get-Content (Join-Path $tasksRoot "$failoverId\OUTPUTS\DISPATCH_ATTEMPTS.jsonl") -Encoding UTF8)
if ($failoverTask -notmatch '(?m)^route_to:\s*Codex\s*$' -or $failoverTask -notmatch '(?m)^task_status:\s*completed\s*$') { $failures.Add("Claude-to-Codex fallback did not complete") }
if ($failoverAttempts.Count -ne 2) { $failures.Add("expected two bounded Claude attempts, got $($failoverAttempts.Count)") }
if (($failoverOutput -join "`n") -notmatch 'fallback_scheduled') { $failures.Add("fallback event missing") }

$containRoot = "ci-queue-containment-root-$runSuffix"
New-Root $containRoot
$alwaysFailId = "ci-queue-01-always-fail-$runSuffix"
$successId = "ci-queue-02-success-$runSuffix"
New-Task $alwaysFailId $containRoot 1 "Codex" "CODEX_VERIFY" "verify"
New-Task $successId $containRoot 2 "Codex" "CODEX_BUILD" "build"
$containOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -AgentOSRoot $AgentOSRoot -RootDispatchId $containRoot -PollSeconds 0 -MaxTasksPerRun 6 -MaxAttemptsPerRoute 2 -DispatcherPath $fake -Environment ci 2>&1
if ($LASTEXITCODE -ne 0) { $failures.Add("contained-failure queue exited nonzero") }
$containState = Get-Content -Raw (Join-Path $stateRoot "$containRoot.json") -Encoding UTF8 | ConvertFrom-Json
$successResult = Join-Path $tasksRoot "$successId\OUTPUTS\RESULT.md"
if ($containState.status -ne "completed_with_failures") { $failures.Add("queue did not expose completed_with_failures") }
if (-not (Test-Path -LiteralPath $successResult) -or (Get-Content -Raw $successResult -Encoding UTF8) -notmatch 'status:\s*completed') { $failures.Add("independent task did not run after contained failure") }
if (($containOutput -join "`n") -notmatch 'failure_contained') { $failures.Add("failure containment event missing") }

$escalationIndexPath = Join-Path $AgentOSRoot "data\escalations\ESCALATION_INDEX.jsonl"
if (Test-Path -LiteralPath $escalationIndexPath) {
    $mismarkedFixtureEscalations = @(Get-Content -LiteralPath $escalationIndexPath -Encoding UTF8 | ForEach-Object {
        if (-not $_.Trim()) { return }
        try { $_ | ConvertFrom-Json } catch { $null }
    } | Where-Object { $_ -and $_.task_id -eq $alwaysFailId -and $_.is_fixture -ne $true })
    if ($mismarkedFixtureEscalations.Count) { $failures.Add("CI fixture escalation for $alwaysFailId was written to ESCALATION_INDEX.jsonl without is_fixture:true") }
}

if ($failures.Count) { $failures | ForEach-Object { Write-Error $_ }; exit 1 }
Write-Output "queue_failure_containment_status=passed"
Write-Output "claude_to_codex_fallback=true"
Write-Output "bounded_attempts_per_route=2"
Write-Output "independent_task_continued=true"

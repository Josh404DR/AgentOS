[CmdletBinding()]
param([string]$AgentOSRoot = "E:\AgentOS")

$ErrorActionPreference = "Stop"
$runSuffix = "$PID-$(Get-Date -Format 'HHmmssfff')"
$rootId = "ci-queue-reason-root-$runSuffix"
$childId = "ci-queue-reason-child-$runSuffix"
$tasksRoot = Join-Path $AgentOSRoot "data\codex_tasks"
$status = Get-Content -Raw (Join-Path $AgentOSRoot "data\governance\governance_status.json") -Encoding UTF8 | ConvertFrom-Json
$utf8 = [Text.UTF8Encoding]::new($false)
foreach ($item in @(
    @{ Id=$rootId; Parent=""; Source=""; Order=0 },
    @{ Id=$childId; Parent=$rootId; Source=$rootId; Order=1 }
)) {
    $dir = Join-Path $tasksRoot $item.Id
    New-Item -ItemType Directory -Force -Path (Join-Path $dir "OUTPUTS") | Out-Null
    $route = if ($item.Id -eq $rootId) { "Hermes" } else { "Claude" }
    $assigned = if ($item.Id -eq $rootId) { "Hermes" } else { "Claude Worker" }
    $task = @"
dispatch_id: $($item.Id)
parent_dispatch_id: $($item.Parent)
source_dispatch_id: $($item.Source)
dependency_order: $($item.Order)
depends_on: parent_created:$rootId
type: CLAUDE_WORKER
assigned_to: $assigned
route_to: $route
task_status: ready
dispatch_status: ready_to_route
governance_version: $($status.governance_version)
governance_hash: $($status.canonical_hash)
"@
    [IO.File]::WriteAllText((Join-Path $dir "TASK.md"), $task, $utf8)
}
$statePath = Join-Path $AgentOSRoot "data\queue_runs\$rootId.json"
$state = @{ root_dispatch_id=$rootId; process_id=$PID; started_at=(Get-Date -Format o); status="running" } | ConvertTo-Json
[IO.File]::WriteAllText($statePath, $state, $utf8)
$runner = Join-Path $AgentOSRoot "scripts\task_queue_runner.ps1"
$fake = Join-Path $AgentOSRoot "tests\fixtures\fake_dispatcher_failure.ps1"
$output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -AgentOSRoot $AgentOSRoot -RootDispatchId $rootId -Once -DispatcherPath $fake -Environment ci 2>&1
$exit = $LASTEXITCODE
$text = $output -join "`n"
$finalState = Get-Content -Raw $statePath -Encoding UTF8 | ConvertFrom-Json
if ($exit -ne 0) { Write-Error "queue should contain dispatcher failure instead of exiting: $exit"; exit 1 }
if ($text -notmatch 'reason=agent_timeout phase=fake_worker exit_code=124 artifact=') { Write-Error "queue detail missing: $text"; exit 1 }
$childTask = Get-Content -Raw (Join-Path $tasksRoot "$childId\TASK.md") -Encoding UTF8
$attemptLog = Join-Path $tasksRoot "$childId\OUTPUTS\DISPATCH_ATTEMPTS.jsonl"
if ($finalState.status -ne "recovery_pending") { Write-Error "queue did not report recovery_pending"; exit 1 }
if ($childTask -notmatch '(?m)^task_status:\s*retrying\s*$') { Write-Error "task retry state missing"; exit 1 }
if (-not (Test-Path -LiteralPath $attemptLog)) { Write-Error "attempt ledger missing"; exit 1 }
Write-Output "queue_reason_propagation_status=passed"
Write-Output "dispatcher_failure_contained=true"
Write-Output "detail=$text"

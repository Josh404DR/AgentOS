[CmdletBinding()]
param([string]$AgentOSRoot = "E:\AgentOS")

$ErrorActionPreference = "Stop"
. (Join-Path $AgentOSRoot "scripts\lib\dependency_status.ps1")
$failures = [Collections.Generic.List[string]]::new()

foreach ($status in @(
    'pending_dependency',
    'waiting_dependencies',
    'blocked_by_dependency',
    'waiting_dependency',
    'waiting_on_dependency'
)) {
    $warnings = [Collections.Generic.List[string]]::new()
    $actual = Test-AgentOSDependencyWaitingStatus -Status $status -OnUnknownStatus {
        param($value)
        $warnings.Add($value)
    }
    if (-not $actual) { $failures.Add("status was not normalized as waiting: $status") }
    if ($warnings.Count) { $failures.Add("known status emitted warning: $status") }
}

$unknownWarnings = [Collections.Generic.List[string]]::new()
$unknownResult = Test-AgentOSDependencyWaitingStatus -Status 'waiting_for_the_moon' -OnUnknownStatus {
    param($value)
    $unknownWarnings.Add($value)
}
if ($unknownResult) { $failures.Add('unknown status was treated as dependency-waiting') }
if ($unknownWarnings.Count -ne 1 -or $unknownWarnings[0] -ne 'waiting_for_the_moon') {
    $failures.Add('unknown status did not invoke warning action exactly once')
}

$runnerText = Get-Content -Raw -LiteralPath (Join-Path $AgentOSRoot 'scripts\task_queue_runner.ps1') -Encoding UTF8
$supervisorText = Get-Content -Raw -LiteralPath (Join-Path $AgentOSRoot 'scripts\workflow_supervisor.ps1') -Encoding UTF8
foreach ($entry in @(
    @{ Name = 'task_queue_runner.ps1'; Text = $runnerText },
    @{ Name = 'workflow_supervisor.ps1'; Text = $supervisorText }
)) {
    if ($entry.Text -notmatch 'scripts\\lib\\dependency_status\.ps1') {
        $failures.Add("$($entry.Name) does not load the shared dependency normalizer")
    }
    if ($entry.Text -notmatch 'Test-AgentOSDependencyWaitingStatus') {
        $failures.Add("$($entry.Name) does not call the shared dependency normalizer")
    }
    if ($entry.Text -notmatch 'unknown_dependency_status') {
        $failures.Add("$($entry.Name) does not log unknown dependency statuses")
    }
}

if ($failures.Count) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Output 'dependency_status_normalization_status=passed'
Write-Output 'known_variants=5'
Write-Output 'unknown_status_warning=passed'

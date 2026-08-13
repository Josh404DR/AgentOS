param([string]$DispatchId, [string]$AgentOSRoot)

$taskPath = Join-Path $AgentOSRoot "data\codex_tasks\$DispatchId\TASK.md"
$resultPath = Join-Path $AgentOSRoot "data\codex_tasks\$DispatchId\OUTPUTS\RESULT.md"
$text = Get-Content -Raw -LiteralPath $taskPath -Encoding UTF8
$route = ([regex]::Match($text, '(?mi)^route_to\s*:\s*(.+?)\s*$')).Groups[1].Value.Trim()
$utf8 = [Text.UTF8Encoding]::new($false)

if ($DispatchId -match 'always-fail') {
    [IO.File]::WriteAllText($resultPath, "status: partial_failure`nreason: agent_exit_9`n", $utf8)
    Write-Output "status=partial_failure"
    Write-Output "reason=agent_exit_9"
    Write-Output "phase=fake_always_fail"
    Write-Output "result_path=$resultPath"
    exit 9
}

if ($DispatchId -match 'failover' -and $route -eq 'Claude') {
    [IO.File]::WriteAllText($resultPath, "status: partial_failure`nreason: agent_exit_7`n", $utf8)
    Write-Output "status=partial_failure"
    Write-Output "reason=agent_exit_7"
    Write-Output "phase=fake_claude"
    Write-Output "result_path=$resultPath"
    exit 7
}

[IO.File]::WriteAllText($resultPath, "status: completed`nchange_required: false`nevidence: fake resilient dispatcher success`n", $utf8)
Write-Output "status=completed"
Write-Output "result_path=$resultPath"
exit 0

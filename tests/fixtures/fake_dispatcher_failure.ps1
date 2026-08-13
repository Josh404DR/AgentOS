param([string]$DispatchId, [string]$AgentOSRoot)
Write-Output "status=partial_failure"
Write-Output "reason=agent_timeout"
Write-Output "phase=fake_worker"
Write-Output "result_path=$AgentOSRoot\data\codex_tasks\$DispatchId\OUTPUTS\RESULT.md"
Write-Output "exit_code=124"
exit 124

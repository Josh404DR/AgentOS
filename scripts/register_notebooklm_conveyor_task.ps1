param(
    [string]$TaskName = "AgentOS NotebookLM Conveyor",
    [string]$At = "03:30",
    [ValidateSet("DryRun", "Live")]
    [string]$Mode = "Live",
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

$rootPath = (Resolve-Path $Root).Path
$conveyorScript = Join-Path $rootPath "scripts\notebooklm_conveyor.ps1"

if (-not (Test-Path $conveyorScript)) {
    throw "Conveyor script not found: $conveyorScript"
}

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$conveyorScript`" -Mode $Mode"

$trigger = New-ScheduledTaskTrigger -Daily -At $At
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description "AgentOS fixed-time conveyor that exports current docs and syncs them to NotebookLM." `
    -Force | Out-Null

Write-Output "SCHEDULE_STATUS=registered"
Write-Output "TASK_NAME=$TaskName"
Write-Output "AT=$At"
Write-Output "MODE=$Mode"

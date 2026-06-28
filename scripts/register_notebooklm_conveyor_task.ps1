param(
    [string]$TaskName = "AgentOS NotebookLM Conveyor",
    [string]$At = "03:30",
    [ValidateSet("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")]
    [string]$DayOfWeek = "Sunday",
    [ValidateSet("DryRun", "Live")]
    [string]$Mode = "DryRun",
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

$trigger = New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek $DayOfWeek -At $At
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description "Weekly local-only NotebookLM bundle export and dry-run. Live upload remains manual." `
    -Force | Out-Null

Write-Output "SCHEDULE_STATUS=registered"
Write-Output "TASK_NAME=$TaskName"
Write-Output "AT=$At"
Write-Output "DAY_OF_WEEK=$DayOfWeek"
Write-Output "MODE=$Mode"

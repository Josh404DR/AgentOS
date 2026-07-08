#!/usr/bin/env pwsh
# Register the AgentOS Dashboard as a per-user Windows scheduled task.
# Usage:
#   powershell.exe -File .\register_autostart.ps1
#   powershell.exe -File .\register_autostart.ps1 -Remove

param([switch]$Remove)

$ErrorActionPreference = "Stop"
$TaskName = "AgentOS-Dashboard"
$StartScript = Join-Path $PSScriptRoot "start.ps1"
$PowerShellExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

if ($Remove) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Output "dashboard_autostart_status=removed"
    Write-Output "task_name=$TaskName"
    return
}

if (-not (Test-Path -LiteralPath $StartScript -PathType Leaf)) {
    throw "Dashboard start script not found: $StartScript"
}

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

$action = New-ScheduledTaskAction `
    -Execute $PowerShellExe `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$StartScript`" -NoBrowser" `
    -WorkingDirectory $PSScriptRoot

$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$trigger.Delay = "PT30S"

$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -RestartCount 2 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -StartWhenAvailable

$principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -LogonType Interactive `
    -RunLevel Limited

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description "AgentOS Dashboard backend and frontend autostart" | Out-Null

Write-Output "dashboard_autostart_status=registered"
Write-Output "task_name=$TaskName"
Write-Output "start_script=$StartScript"
Write-Output "delay_seconds=30"

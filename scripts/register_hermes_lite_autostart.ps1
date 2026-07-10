[CmdletBinding()]
param(
    [string]$TaskName = "HermesLiteAutostart",
    [string]$AgentOSRoot = "E:\AgentOS",
    [int]$DelaySeconds = 30
)

$ErrorActionPreference = "Stop"

$startScript = Join-Path $AgentOSRoot "scripts\start_hermes_lite.ps1"
$logDir = Join-Path $AgentOSRoot "logs"
$registrationLog = Join-Path $logDir "hermes-lite-autostart-registration.log"

if (-not (Test-Path -LiteralPath $startScript -PathType Leaf)) {
    throw "Hermes Lite start script not found: $startScript"
}
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$powerShellExe = (Get-Command powershell.exe -ErrorAction Stop).Source
$arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $startScript
$action = New-ScheduledTaskAction `
    -Execute $powerShellExe `
    -Argument $arguments `
    -WorkingDirectory $AgentOSRoot

$trigger = New-ScheduledTaskTrigger -AtLogOn
$trigger.Delay = "PT${DelaySeconds}S"

$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -StartWhenAvailable `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -MultipleInstances IgnoreNew

$userId = if ($env:USERDOMAIN) {
    "$($env:USERDOMAIN)\$($env:USERNAME)"
} else {
    $env:USERNAME
}
$principal = New-ScheduledTaskPrincipal `
    -UserId $userId `
    -LogonType Interactive `
    -RunLevel Limited

$registered = Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description "AgentOS: start Hermes Lite gateway $DelaySeconds seconds after user logon" `
    -Force

$evidence = @"
registered_at=$(Get-Date -Format o)
task_name=$TaskName
task_state=$($registered.State)
execute=$powerShellExe
arguments=$arguments
working_directory=$AgentOSRoot
user_id=$userId
logon_type=Interactive
run_level=Limited
delay_seconds=$DelaySeconds
"@
[IO.File]::WriteAllText(
    $registrationLog,
    $evidence,
    [Text.UTF8Encoding]::new($false)
)

Write-Output "autostart_registration_status=completed"
Write-Output "task_name=$TaskName"
Write-Output "task_state=$($registered.State)"
Write-Output "execute=$powerShellExe"
Write-Output "arguments=$arguments"
Write-Output "working_directory=$AgentOSRoot"
Write-Output "user_id=$userId"
Write-Output "delay_seconds=$DelaySeconds"
Write-Output "registration_log=$registrationLog"

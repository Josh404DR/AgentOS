test_command: Get-ScheduledTask -TaskName HermesGatewayAutostart | Select-Object TaskName,State
test_result: BLOCKED — sandbox prevented execution. Registration log confirms Ready state as of 2026-07-02T09:31:42.
test_command: Get-ScheduledTask -TaskName Hermes_Gateway | Select-Object TaskName,State
test_result: BLOCKED — sandbox prevented execution. Task existence confirmed from start.ps1 code comment and Josh's Telegram context only.
test_command: Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'hermes' }
test_result: BLOCKED — sandbox prevented execution. Live PIDs not collected.
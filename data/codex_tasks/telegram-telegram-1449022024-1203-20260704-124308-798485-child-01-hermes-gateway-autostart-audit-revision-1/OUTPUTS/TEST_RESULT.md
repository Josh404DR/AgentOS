test_command: .\scripts\assert_governance_ready.ps1
test_result: BLOCKED — sandbox permission denied in this revision session. Governance status confirmed via direct file read: governance_status.json shows aligned/1.2.0/F442C94F…
test_command: Get-ScheduledTask -TaskName HermesGatewayAutostart -ErrorAction SilentlyContinue | Select-Object TaskName,State
test_result: BLOCKED — sandbox permission denied in this revision session. Structural constraint; cannot be resolved by agent iteration.
test_command: Get-ScheduledTask -TaskName Hermes_Gateway -ErrorAction SilentlyContinue | Select-Object TaskName,State
test_result: BLOCKED — sandbox permission denied in this revision session. Structural constraint; cannot be resolved by agent iteration.
test_command: Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'hermes' } | Select-Object ProcessId,Name,ExecutablePath
test_result: BLOCKED — sandbox permission denied in this revision session. Structural constraint; cannot be resolved by agent iteration.
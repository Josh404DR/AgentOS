# AgentOS Dispatch Result

dispatch_id: telegram-telegram-1449022024-1203-20260704-124308-798485-child-02-hermes-gateway-autostart-verify
route_to: Codex
codex_mode: verify
governance_version: 1.2.0
governance_hash: F442C94F00D21340DC70B56B2D08B017BE51AA5B1908D8ECD7E7F38DFF56C747
status: completed
models_invoked: true
scripts_executed: true
cleanup_executed: false
dry_run: false
review_dispatch_id: not_created

## Findings

verification_status: PASS  
governance_status: aligned  
governance_version: 1.2.0  
governance_hash: F442C94F00D21340DC70B56B2D08B017BE51AA5B1908D8ECD7E7F38DFF56C747

Child-01 驗證結論：PASS。`AUDIT_REPORT.md` 本身仍保留「live query blocked」的舊狀態，但 child-01 交付包中的 `OUTPUTS\LIVE_ELEVATED_EVIDENCE.md` 已補足 elevated read-only 證據；我也用本次唯讀查詢獨立確認 scheduled task 與 live PID 內容相符。

changed_file: data\governance\governance_status.json  
change_required: false

test_command: .\scripts\assert_governance_ready.ps1  
test_result: FAIL in read-only sandbox because `governance_status.json` write was denied; rerun with approved elevation.

test_command: .\scripts\assert_governance_ready.ps1  
test_result: PASS; `governance_gate=passed`, `governance_status=aligned`, version/hash matched.

test_command: Get-ScheduledTask -TaskName HermesGatewayAutostart | Select-Object TaskName,TaskPath,State,Actions,Triggers  
test_result: PASS with elevation; task exists at `\`, state `Ready`.

test_command: Get-ScheduledTaskInfo -TaskName HermesGatewayAutostart  
test_result: PASS; last run `2026/7/4 08:34:50`, result `0`, next run blank for logon trigger.

test_command: Get-ScheduledTask -TaskName HermesGatewayAutostart | Select-Object -ExpandProperty Actions | Format-List *  
test_result: PASS; executes `powershell.exe` with `-File "E:\AgentOS\scripts\start.ps1" -SkipProxy`, working directory `E:\AgentOS`.

test_command: Get-ScheduledTask -TaskName HermesGatewayAutostart | Select-Object -ExpandProperty Triggers | Format-List *  
test_result: PASS; `MSFT_TaskLogonTrigger`, enabled, delay `PT30S`.

test_command: Get-ScheduledTask -TaskName Hermes_Gateway | Select-Object TaskName,TaskPath,State,Actions,Triggers  
test_result: PASS with elevation; task exists at `\`, state `Ready`.

test_command: Get-ScheduledTaskInfo -TaskName Hermes_Gateway  
test_result: PASS; last run `2026/7/4 08:34:20`, result `15`.

test_command: Get-ScheduledTask -TaskName Hermes_Gateway | Select-Object -ExpandProperty Actions | Format-List *  
test_result: PASS; executes `C:\Users\brian\AppData\Local\hermes\gateway-service\Hermes_Gateway.cmd`, no arguments or working directory.

test_command: Get-ScheduledTask -TaskName Hermes_Gateway | Select-Object -ExpandProperty Triggers | Format-List *  
test_result: PASS; `MSFT_TaskLogonTrigger`, enabled, start boundary `2026-06-29T12:02:00`.

test_command: Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'hermes|python|node|pwsh|powershell' -or $_.CommandLine -match 'Hermes|gateway|AgentOS' } | Select-Object ProcessId,ParentProcessId,Name,ExecutablePath,CommandLine,CreationDate  
test_result: PASS with elevation; live AI Hermes chain confirmed: PID `12216` `hermes.exe`, parent `6368`, path under `E:\AI_Projects_Hub\External_AI_Agents\hermes-agent`, command includes `gateway run --accept-hooks --replace`; Python child PIDs `6004` and `2420`.

test_command: Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'hermes.exe' -or $_.ExecutablePath -match 'hermes-agent|Acer|Jumpstart' -or $_.CommandLine -match 'hermes-agent|Acer|Jumpstart|gateway run' } | Select-Object ProcessId,ParentProcessId,Name,ExecutablePath,CommandLine,CreationDate  
test_result: PASS; Acer processes exist, but no Acer `hermes.exe` was found. AI Hermes `hermes.exe` is clearly under `hermes-agent`, not Acer.

Child-01 acceptance criteria:
- Governance readiness: PASS.
- Both task action/trigger/state/last run/next run/last result collected: PASS via `LIVE_ELEVATED_EVIDENCE.md` and independent recheck.
- Live gateway PID evidence: PASS.
- Acer Jumpstart distinction: PASS.
- Canonical retained entry and disable target: PASS; retain `HermesGatewayAutostart`, disable `Hermes_Gateway`.
- Disable command scope: PASS; `Disable-ScheduledTask -TaskName "Hermes_Gateway"` targets only the non-canonical task and uses disable, not delete.
- Rollback/impact/acceptance criteria: PASS.
- No scheduled task mutation during verification: PASS; I ran only read/query commands, no disable/enable/register/unregister/set/start/stop commands.

## Caveats

none
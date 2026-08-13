test_command: PowerShell execution/parser coverage for scripts\sync_shared_governance.ps1, scripts\assert_governance_ready.ps1, scripts\dispatch_task_packet.ps1, scripts\task_queue_runner.ps1
test_result: PASS — updated scripts parsed and executed successfully through the regression suites.

test_command: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\classify_task_regression.ps1 -AgentOSRoot E:\AgentOS
test_result: PASS — classifier_regression_status=passed; case_count=12; complex_hit_check=enabled.

test_command: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test_dispatch_diff_helper.ps1 -AgentOSRoot E:\AgentOS
test_result: PASS — diff_helper_regression_status=passed; case_count=4.

test_command: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test_dispatch_resilience.ps1 -AgentOSRoot E:\AgentOS
test_result: PASS — dispatch_resilience_status=passed; case_count=5; timeout_elapsed_seconds=15; process cleanup and verdict-output validation passed.

test_command: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test_governance_tiers.ps1 -AgentOSRoot E:\AgentOS
test_result: PASS — policy_drift_count=0; operational_drift_count=2; readonly_status_unchanged=true; readonly_noncanonical_policy_fail_closed=true; approve_paths_missing_entry_preserved=true.

test_command: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test_queue_reason_propagation.ps1 -AgentOSRoot E:\AgentOS
test_result: PASS — dispatcher_exit_code=124; detail preserved reason=agent_timeout phase=fake_worker exit_code=124 and artifact path.

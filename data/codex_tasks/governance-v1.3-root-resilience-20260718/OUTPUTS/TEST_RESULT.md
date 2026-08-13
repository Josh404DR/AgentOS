test_command: PowerShell Language.Parser ParseFile for scripts\sync_shared_governance.ps1, scripts\assert_governance_ready.ps1, scripts\dispatch_task_packet.ps1, scripts\task_queue_runner.ps1
test_result: PASS — syntax_status=passed; all four scripts had zero parser errors.

test_command: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\classify_task_regression.ps1 -AgentOSRoot E:\AgentOS
test_result: PASS — classifier_regression_status=passed; case_count=12; complex_hit_check=enabled.

test_command: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test_dispatch_diff_helper.ps1 -AgentOSRoot E:\AgentOS
test_result: PASS — diff_helper_regression_status=passed; case_count=4.

test_command: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test_dispatch_resilience.ps1 -AgentOSRoot E:\AgentOS
test_result: PASS — dispatch_resilience_status=passed; case_count=5; timeout_elapsed_seconds=14; timed-out child PID was not left running; verdict-only verifier output was rejected with reason=invalid_verify_output and phase=codex_verify_validation.

test_command: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test_governance_tiers.ps1 -AgentOSRoot E:\AgentOS
test_result: PASS — governance_tiers_status=passed; policy_drift_count=0; operational_drift_count=2; readonly_status_unchanged=true.

test_command: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test_queue_reason_propagation.ps1 -AgentOSRoot E:\AgentOS
test_result: PASS — queue_reason_propagation_status=passed; detail preserved reason=agent_timeout phase=fake_worker exit_code=124 and artifact path.

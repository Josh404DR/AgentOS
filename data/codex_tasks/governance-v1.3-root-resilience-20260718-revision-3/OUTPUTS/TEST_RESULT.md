test_command: scripts\assert_governance_ready.ps1 -ReadOnly against revision-2 task
test_result: PASS — governance_status=aligned; governance_checked_at=read_only_live_scan; policy drift=0; operational_drift_count=0; task_execution_allowed=true.

test_command: tests\classify_task_regression.ps1
test_result: PASS — case_count=12; complex_hit_check=enabled.

test_command: tests\test_dispatch_diff_helper.ps1
test_result: PASS — case_count=4.

test_command: tests\test_dispatch_resilience.ps1
test_result: PASS — case_count=5; timeout_elapsed_seconds=15.

test_command: tests\test_governance_tiers.ps1
test_result: PASS — policy_drift_count=0; operational_drift_count=0; readonly_status_unchanged=true; readonly_noncanonical_policy_fail_closed=true; approve_paths_missing_entry_preserved=true.

test_command: tests\test_queue_reason_propagation.ps1
test_result: PASS — dispatcher_exit_code=124; reason, phase, exit code, and artifact path preserved.

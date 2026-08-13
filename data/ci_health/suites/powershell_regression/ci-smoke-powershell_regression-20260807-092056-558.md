# AgentOS CI Smoke Suite: powershell_regression

run_id: ci-smoke-powershell_regression-20260807-092056-558
status: TIMEOUT
exit_code: 124
timeout_seconds: 180
duration_seconds: 180.173
python_launcher: 

| Check | Status | Exit code | Duration (s) | Detail |
| --- | --- | ---: | ---: | --- |
| suite_bootstrap | PASS | 0 | 0.008 | suite=powershell_regression timeout_seconds=180 |
| dashboard_orphan_guard | PASS | 0 | 0.8 | [dashboard-backend] Untrusted port owner: PID=4242 process=python started_at=2026-07-21T08:00:00.0000000+08:00<br>[dashboard-backend] command_line=python -m uvicorn main:app --port 8000<br>[dashboard-backend] Inspect manually: Get-CimInstance Win32_Process -Filter 'ProcessId=<PID>' / Select-Object ProcessId,Name,ExecutablePath,CommandLine<br>[dashboard-backend] After verification: Stop-Process -Id <PID> -Force; .\start.ps1<br>dashboard_orphan_guard=PASS<br>workspace_backend_only=true<br>workspac... |
| dashboard_ux_contract | PASS | 0 | 0.724 | dashboard_ux_contract=PASS<br>approval_queue_imported=true<br>approval_queue_rendered=true<br>unauthenticated_prompt=true<br>decision_endpoint=true<br>token_path_guidance=true<br>restart_guidance=true<br>reclaim_switch=true<br>utf8_content_type=true<br>utf8_body_bytes=true |
| verify_prompt_fixture | PASS | 0 | 0.832 | PASS: rerun_task_lacks_verdict_before_fix<br>PASS: rerun_task_has_verdict_after_injection<br>PASS: standard_task_already_has_verdict<br>PASS: standard_task_unchanged_after_no-op_injection<br>PASS: approve_effect_char_count<br>PASS: modify_effect_char_count<br>PASS: stop_effect_char_count<br>PASS: approve_first_char_codepoint<br>PASS: modify_first_char_codepoint<br>PASS: stop_first_char_codepoint<br>PASS: json_roundtrip_approve<br>PASS: json_roundtrip_modify<br>PASS: json_roundtrip_stop<br>--- TO... |
| classifier_regression | PASS | 0 | 7.633 | classifier_regression_status=passed<br>case_count=12<br>complex_hit_check=enabled |
| learning_governance_dedupe | PASS | 0 | 6.344 | learning_governance_dedupe=PASS<br>governance_second_run_skip_duplicate=true<br>escalation_index_persists_dedupe_key=true<br>existing_event_directory_guard=true<br>general_candidate_dedupe_regression=true |
| queue_reason_propagation | PASS | 0 | 27.827 | queue_reason_propagation_status=passed<br>dispatcher_failure_contained=true<br>detail=2026-08-07T09:22:37.9105632+08:00 dispatch_id=ci-queue-reason-root-15964-092213186 status=queue_scan detail=scan_ms=12185.984 directory_count=677 scoped_task_count=2 index_rebuilds=1<br>2026-08-07T09:22:38.0076598+08:00 dispatch_id=ci-queue-reason-child-15964-092213186 status=processing detail=dispatcher_start<br>status=partial_failure<br>reason=agent_timeout<br>phase=fake_worker<br>result_path=E:\AgentOS\data\... |
| suite_timeout | TIMEOUT | 124 | 180 | Suite exceeded bounded timeout of 180 seconds; completed check receipts were preserved and the worker process tree was terminated. |

## Fixture paths

- none

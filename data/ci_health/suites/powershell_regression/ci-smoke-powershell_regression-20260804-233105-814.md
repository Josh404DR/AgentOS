# AgentOS CI Smoke Suite: powershell_regression

run_id: ci-smoke-powershell_regression-20260804-233105-814
status: RUNNING
exit_code: 
timeout_seconds: 180
duration_seconds: 161.457
python_launcher: 

| Check | Status | Exit code | Duration (s) | Detail |
| --- | --- | ---: | ---: | --- |
| suite_bootstrap | PASS | 0 | 0.006 | suite=powershell_regression timeout_seconds=180 |
| dashboard_orphan_guard | PASS | 0 | 0.639 | [dashboard-backend] Untrusted port owner: PID=4242 process=python started_at=2026-07-21T08:00:00.0000000+08:00<br>[dashboard-backend] command_line=python -m uvicorn main:app --port 8000<br>[dashboard-backend] Inspect manually: Get-CimInstance Win32_Process -Filter 'ProcessId=<PID>' / Select-Object ProcessId,Name,ExecutablePath,CommandLine<br>[dashboard-backend] After verification: Stop-Process -Id <PID> -Force; .\start.ps1<br>dashboard_orphan_guard=PASS<br>workspace_backend_only=true<br>workspac... |
| dashboard_ux_contract | PASS | 0 | 0.641 | dashboard_ux_contract=PASS<br>approval_queue_imported=true<br>approval_queue_rendered=true<br>unauthenticated_prompt=true<br>decision_endpoint=true<br>token_path_guidance=true<br>restart_guidance=true<br>reclaim_switch=true<br>utf8_content_type=true<br>utf8_body_bytes=true |
| verify_prompt_fixture | PASS | 0 | 0.841 | PASS: rerun_task_lacks_verdict_before_fix<br>PASS: rerun_task_has_verdict_after_injection<br>PASS: standard_task_already_has_verdict<br>PASS: standard_task_unchanged_after_no-op_injection<br>PASS: approve_effect_char_count<br>PASS: modify_effect_char_count<br>PASS: stop_effect_char_count<br>PASS: approve_first_char_codepoint<br>PASS: modify_first_char_codepoint<br>PASS: stop_first_char_codepoint<br>PASS: json_roundtrip_approve<br>PASS: json_roundtrip_modify<br>PASS: json_roundtrip_stop<br>--- TO... |
| classifier_regression | PASS | 0 | 7.54 | classifier_regression_status=passed<br>case_count=12<br>complex_hit_check=enabled |
| learning_governance_dedupe | PASS | 0 | 5.331 | learning_governance_dedupe=PASS<br>governance_second_run_skip_duplicate=true<br>escalation_index_persists_dedupe_key=true<br>existing_event_directory_guard=true<br>general_candidate_dedupe_regression=true |
| queue_reason_propagation | PASS | 0 | 14.625 | queue_reason_propagation_status=passed<br>dispatcher_failure_contained=true<br>detail=2026-08-04T23:31:52.9800283+08:00 dispatch_id=ci-queue-reason-root-6204-233144214 status=queue_scan detail=scan_ms=3699.266 directory_count=661 scoped_task_count=2 index_rebuilds=1<br>2026-08-04T23:31:53.0152088+08:00 dispatch_id=ci-queue-reason-child-6204-233144214 status=processing detail=dispatcher_start<br>status=partial_failure<br>reason=agent_timeout<br>phase=fake_worker<br>result_path=E:\AgentOS\data\cod... |
| queue_failure_containment | PASS | 0 | 57.936 | queue_failure_containment_status=passed<br>claude_to_codex_fallback=true<br>bounded_attempts_per_route=2<br>independent_task_continued=true |
| dispatch_resilience | PASS | 0 | 72.089 | dispatch_resilience_status=passed<br>case_count=7<br>timeout_elapsed_seconds=16 |
| escalation_decision_hardening | FAIL | 1 | 1.515 | powershell.exe : E:\AgentOS\data\test_runs\escalation-hardening-140e91ed527b4b25ad05d28b024a75e4\scripts\decide_escalat |

## Fixture paths

- none

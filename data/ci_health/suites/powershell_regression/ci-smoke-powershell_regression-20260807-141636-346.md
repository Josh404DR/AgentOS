# AgentOS CI Smoke Suite: powershell_regression

run_id: ci-smoke-powershell_regression-20260807-141636-346
status: FAIL
exit_code: 1
timeout_seconds: 180
duration_seconds: 126.305
python_launcher: 

| Check | Status | Exit code | Duration (s) | Detail |
| --- | --- | ---: | ---: | --- |
| suite_bootstrap | PASS | 0 | 0.006 | suite=powershell_regression timeout_seconds=180 |
| dashboard_orphan_guard | PASS | 0 | 0.432 | [dashboard-backend] Untrusted port owner: PID=4242 process=python started_at=2026-07-21T08:00:00.0000000+08:00<br>[dashboard-backend] command_line=python -m uvicorn main:app --port 8000<br>[dashboard-backend] Inspect manually: Get-CimInstance Win32_Process -Filter 'ProcessId=<PID>' / Select-Object ProcessId,Name,ExecutablePath,CommandLine<br>[dashboard-backend] After verification: Stop-Process -Id <PID> -Force; .\start.ps1<br>dashboard_orphan_guard=PASS<br>workspace_backend_only=true<br>workspac... |
| dashboard_ux_contract | PASS | 0 | 0.347 | dashboard_ux_contract=PASS<br>approval_queue_imported=true<br>approval_queue_rendered=true<br>unauthenticated_prompt=true<br>decision_endpoint=true<br>token_path_guidance=true<br>restart_guidance=true<br>reclaim_switch=true<br>utf8_content_type=true<br>utf8_body_bytes=true |
| verify_prompt_fixture | PASS | 0 | 0.395 | PASS: rerun_task_lacks_verdict_before_fix<br>PASS: rerun_task_has_verdict_after_injection<br>PASS: standard_task_already_has_verdict<br>PASS: standard_task_unchanged_after_no-op_injection<br>PASS: approve_effect_char_count<br>PASS: modify_effect_char_count<br>PASS: stop_effect_char_count<br>PASS: approve_first_char_codepoint<br>PASS: modify_first_char_codepoint<br>PASS: stop_first_char_codepoint<br>PASS: json_roundtrip_approve<br>PASS: json_roundtrip_modify<br>PASS: json_roundtrip_stop<br>--- TO... |
| classifier_regression | PASS | 0 | 4.07 | classifier_regression_status=passed<br>case_count=12<br>complex_hit_check=enabled |
| learning_governance_dedupe | PASS | 0 | 3.31 | learning_governance_dedupe=PASS<br>governance_second_run_skip_duplicate=true<br>escalation_index_persists_dedupe_key=true<br>existing_event_directory_guard=true<br>general_candidate_dedupe_regression=true |
| queue_reason_propagation | PASS | 0 | 7.206 | queue_reason_propagation_status=passed<br>dispatcher_failure_contained=true<br>detail=2026-08-07T14:17:08.0971456+08:00 dispatch_id=ci-queue-reason-root-17256-141702152 status=queue_scan detail=scan_ms=2162.56 directory_count=702 scoped_task_count=2 index_rebuilds=1<br>2026-08-07T14:17:08.1139972+08:00 dispatch_id=ci-queue-reason-child-17256-141702152 status=processing detail=dispatcher_start<br>status=partial_failure<br>reason=agent_timeout<br>phase=fake_worker<br>result_path=E:\AgentOS\data\co... |
| queue_failure_containment | PASS | 0 | 39.457 | queue_failure_containment_status=passed<br>claude_to_codex_fallback=true<br>bounded_attempts_per_route=2<br>independent_task_continued=true |
| dispatch_resilience | PASS | 0 | 37.484 | dispatch_resilience_status=passed<br>case_count=7<br>timeout_elapsed_seconds=6 |
| escalation_decision_hardening | FAIL | 1 | 0.869 | powershell.exe : E:\AgentOS\data\test_runs\escalation-hardening-5ccb5428be0e41eb98e8ab596e88377b\scripts\decide_escalat |
| hermes_root_queue_e2e | PASS | 0 | 27.96 | hermes_root_queue_e2e_status=passed<br>root_task_processed_by_queue=true<br>bounded_retry_then_fallback=true<br>root_single_point_removed=true<br>dispatch_id=ci-hermes-root-failover-2404-141827287 |
| url_knowledge_security | PASS | 0 | 0.635 | url_knowledge_security_tests=PASS<br>path_boundary_cases=valid,traversal,absolute_outside,junction<br>review_gate_cases=strict_pass,caveats,incomplete<br>verify_gate_cases=fresh_pass,nonfresh,fail |
| knowledge_sync_retry_dryrun | PASS | 0 | 3.863 | queue_item=ci-live-generic-link-20260719-224754.json/status=would_retry<br>queue_item=ci-live-generic-resilient-20260719-225229.json/status=would_retry<br>queue_item=telegram-telegram-1449022024-1354-20260720-115628-736386.json/status=would_retry<br>knowledge_sync_retry_status=completed<br>processed=3<br>uploaded=0<br>deferred=0 |

## Fixture paths

- none

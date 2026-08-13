# SCC External Task API — Test Evidence

new_tests: 12/12 PASS
regression_tests: 48/48 PASS
live_fixture_dispatch_id: scc-20260805-010156-scc-live-readonly-fixture-de5c
live_queue_runner_exit: 0
live_result_status: completed
live_status_http: 200
live_result_http: 200
live_health_queue_runner_alive: true
live_wrong_key_http: 401
live_path_traversal_http: 400
unit_unconfigured_key_http: 503
live_key_material_logged_or_committed: false
verify_verdict_cases: PASS, FAIL, NEEDS_HUMAN_DECISION covered
client_ref_none_substring_preserved: true
sanitized_live_transcript: OUTPUTS/LIVE_HTTP_TRANSCRIPT.md

Commands:

- `dashboard\backend\.venv\Scripts\python.exe -m unittest tests.test_external_task_api -v`
- `dashboard\backend\.venv\Scripts\python.exe -m unittest tests.test_dashboard_security tests.test_dashboard_hermes_metrics_client tests.test_knowledge_workspace -v`
- `scripts\start_task_queue.ps1 -RootDispatchId scc-20260804-163056-scc-live-readonly-fixture-f955`
- live HTTP POST/GET/negative checks against `127.0.0.1:8000`

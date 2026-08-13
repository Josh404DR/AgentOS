# Child 05 Test Result

dispatch_id: 2026-07-26-ci-smoke-stage-split-child-05-dashboard-namespace
test_status: partial
full_ci_executed: false
full_ci_pass_claimed: false

## Python unittest（唯一一次）

command: `dashboard\backend\.venv\Scripts\python.exe -m unittest .\tests\test_ci_fixture_namespace.py`
result: PASS
exit_code: 0
tests_run: 3
duration_seconds: 0.210
warning: `StarletteDeprecationWarning`（TestClient/httpx 相容性）

三個情境均使用 mock/temp data：

- `/api/tasks` default 隱藏、include-all 顯示。
- `/api/tasks/{task_id}` default 不查詢 fixture、include-all 顯示。
- `/api/escalations` default 隱藏、include-all 顯示。

## dashboard_optional suite（唯一一次）

run_id: child-05-dashboard-optional
result: FAIL
exit_code: 1
duration_seconds: 0.191
timeout_seconds: 30
receipt_json: OUTPUTS\test-artifacts\dashboard_optional\child-05-dashboard-optional.json
receipt_markdown: OUTPUTS\test-artifacts\dashboard_optional\child-05-dashboard-optional.md

Checks：

- `suite_bootstrap`: PASS
- `ci_fixture_namespace`: FAIL；receipt 顯示 `python_launcher: null`
- `dashboard_health_endpoint`: PASS

失敗後已在 `dashboard_optional` branch 補上 `Resolve-AgentOSPythonLauncher` 與 probe check。依「本 suite 一次」限制未重跑，所以修正後 suite 結果仍是 unknown，需交由獨立 Verify session 驗證。


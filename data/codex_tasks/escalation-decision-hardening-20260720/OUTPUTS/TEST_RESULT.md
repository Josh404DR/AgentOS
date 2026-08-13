# Test Result

dispatch_id: escalation-decision-hardening-20260720
self_check_status: PASS
independent_verify_status: PASS
verify_thread_id: 019f7fcf-4083-79c0-b1a8-cca2748d8b38

## Commands and Results

1. `tests\test_escalation_decision_hardening.ps1`: PASS
   - `no_receipt_rejected=true`
   - `forged_method_rejected=true`
   - `verified_owner_receipt_accepted=true`
   - `receipt_reuse_rejected=true`
   - `queue_invalid_decision_awaiting_josh=true`
   - `stored_decision_survives_receipt_expiry=true`
   - `historical_escalation_hashes_unchanged=true`
2. `.venv python -m unittest tests.test_dashboard_security tests.test_knowledge_workspace tests.test_url_knowledge_intake tests.test_knowledge_relations`: `Ran 41 tests ... OK`。
3. `npm.cmd run build`: Next.js compile、TypeScript、4/4 static pages PASS。
4. `tests\test_queue_failure_containment.ps1`: PASS。
5. `tests\test_queue_reason_propagation.ps1`: PASS。首次與另一 queue test 並行時共用 log 發生 `Stream was not readable`；序列重跑 PASS，原錯誤未隱藏。
6. `tests\test_dispatch_resilience.ps1`: 獨立重跑 `case_count=6`、PASS、`timeout_elapsed_seconds=18`。
7. PowerShell AST parse（4 個 scoped scripts）與 Python `py_compile`: PASS。
8. Governance gate：PASS；`governance_status=operational_review_required`、`task_execution_allowed=true`。

## CI Artifacts

- `E:\AgentOS\data\ci_health\ci-smoke-20260720-214107.json`
- `E:\AgentOS\data\ci_health\ci-smoke-20260720-214107.md`
- `E:\AgentOS\data\ci_health\ci-smoke-20260720-214610.json`
- `E:\AgentOS\data\ci_health\ci-smoke-20260720-214610.md`

兩輪完整 smoke 的 `escalation_decision_hardening`、queue、Dashboard、knowledge、URL、syntax gates 均 PASS。第一輪唯一 FAIL 是外部 model CLI 權限；第二輪以正式 `-SkipModelCliSmoke` 避免外部服務後，唯一 FAIL 是既有 dispatch timeout fixture 的 child-process cleanup race；獨立重跑 PASS。Verifier 應保留此 caveat，不得把完整 smoke 描述成零 FAIL。

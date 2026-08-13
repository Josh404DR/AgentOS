# Child 02 Test Result

dispatch_id: 2026-07-26-ci-smoke-stage-split-child-02-powershell-regression
test_status: completed_with_environment_failures
suite_execution_count: 1
full_ci_executed: false
full_ci_pass_claimed: false

## PowerShell regression suite

run_id: child-02-powershell-regression-once
result: FAIL
exit_code: 1
timeout_seconds: 180
duration_seconds: 140.691
check_count: 13
pass_count: 11
fail_count: 2
warn_count: 0
timeout_count: 0
receipt_json: OUTPUTS\test-artifacts\powershell_regression\child-02-powershell-regression-once.json
receipt_markdown: OUTPUTS\test-artifacts\powershell_regression\child-02-powershell-regression-once.md
stdout_log: OUTPUTS\test-artifacts\powershell_regression\child-02-powershell-regression-once.stdout.log
stderr_log: OUTPUTS\test-artifacts\powershell_regression\child-02-powershell-regression-once.stderr.log

單次個別執行在 180 秒上限內完成並留下完整 JSON／Markdown receipt。每個
check 結束後均由 child 01 framework 刷新 run-specific 與 latest receipt。

## Check results

| Check | Result | Exit code | Duration (s) |
| --- | --- | ---: | ---: |
| suite_bootstrap | PASS | 0 | 0.006 |
| dashboard_orphan_guard | PASS | 0 | 0.518 |
| dashboard_ux_contract | PASS | 0 | 0.507 |
| verify_prompt_fixture | PASS | 0 | 0.546 |
| classifier_regression | PASS | 0 | 5.795 |
| learning_governance_dedupe | PASS | 0 | 4.749 |
| queue_reason_propagation | PASS | 0 | 8.036 |
| queue_failure_containment | PASS | 0 | 45.335 |
| dispatch_resilience | FAIL | 1 | 34.814 |
| escalation_decision_hardening | FAIL | 1 | 4.282 |
| hermes_root_queue_e2e | PASS | 0 | 30.242 |
| url_knowledge_security | PASS | 0 | 0.744 |
| knowledge_sync_retry_dryrun | PASS | 0 | 4.828 |

真實失敗內容：

- `dispatch_resilience`: `powershell.exe : Test-Path : Access is denied`
- `escalation_decision_hardening`: `powershell.exe : task index rebuild failed: The term 'E:\AgentOS\data\test_runs\escalation-hardening-2205977f238146fd9c`

以上是 suite 保存的原始 check detail；依工單要求未重跑、未修改測試斷言，
也未將環境失敗誤報為 PASS。

## Acceptance checklist

- PowerShell regression 呼叫完整映射至獨立 suite：pass
- 獨立入口預設 timeout 180 秒：pass
- 每個 check 後刷新 JSON／Markdown：pass（沿用 child 01 framework）
- 不修改 `tests\*.ps1` 判斷或斷言：pass
- 只個別執行本 suite 一次：pass
- 保存真實結果並照實記錄環境失敗：pass
- 產出 child RESULT／TEST_RESULT：pass
- 獨立 Codex Verify：pending（後續 child 07）

## Verification command

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\ci_smoke\ci_smoke_powershell_regression.ps1 -AgentOSRoot E:\AgentOS -OutputDir E:\AgentOS\data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-02-powershell-regression\OUTPUTS\test-artifacts -RunId child-02-powershell-regression-once
```

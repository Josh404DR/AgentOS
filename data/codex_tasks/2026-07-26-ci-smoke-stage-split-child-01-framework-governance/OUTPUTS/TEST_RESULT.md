# Child 01 Test Result

dispatch_id: 2026-07-26-ci-smoke-stage-split-child-01-framework-governance
test_status: locally_verified
full_ci_executed: false
full_ci_pass_claimed: false

## AST / config parse

result: PASS

- `AgentOS.CiSmoke.psm1`: AST PASS
- `ci_smoke_governance_and_syntax.ps1`: AST PASS
- `invoke_ci_smoke_suite.ps1`: AST PASS
- `ci_smoke_suites.json`: JSON parse PASS

## Bounded governance_and_syntax

run_id: child-01-governance-bounded-r2
result: WARN
exit_code: 0
duration_seconds: 12.052
check_count: 6
receipt_json: OUTPUTS\test-artifacts\governance_and_syntax\child-01-governance-bounded-r2.json
receipt_markdown: OUTPUTS\test-artifacts\governance_and_syntax\child-01-governance-bounded-r2.md

Required governance gate、core AST 與 UTF-8 BOM checks 均為 PASS。兩個 Hermes runtime optional checks 為 WARN，receipt 保留原始 exit code 1 與具體環境失敗內容。

## Outer timeout fault injection

run_id: child-01-timeout-contract
result: TIMEOUT
exit_code: 124
duration_seconds: 1.662
wall_time_seconds: 3.0
check_count: 2
partial_receipt_preserved: true
timeout_check_exit_code: 124
markdown_contract_valid: true
receipt_json: OUTPUTS\test-artifacts\governance_and_syntax\child-01-timeout-contract.json
receipt_markdown: OUTPUTS\test-artifacts\governance_and_syntax\child-01-timeout-contract.md

注入 20 秒 child hang，外側 timeout 設為 2 秒。Supervisor 保留先前的 `suite_bootstrap` receipt，追加 `suite_timeout=TIMEOUT/124`，並在 PID-scoped process-tree termination 後返回 124。

## First bounded attempt retained as diagnostic evidence

run_id: child-01-governance-bounded
result: FAIL
exit_code: 1

首次執行揭露 optional Hermes checks 被錯誤升級為 FAIL；修正 default/required contract 後，第二次 bounded 執行為 WARN/0。未刪除首次 evidence。

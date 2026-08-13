# RESULT — child-06 orchestrator fault test

dispatch_id: 2026-07-26-ci-smoke-stage-split-child-06-orchestrator-fault-test
governance_version: 1.3.0
governance_hash: 0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1

## 1. 修改摘要與修改檔案清單

完成／核對總入口 receipt-only 彙總、唯一一次雙短-suite fault injection，以及 parent RESULT 的 append-only 收斂紀錄。

Overall delivery：

- `scripts\agentos_ci_smoke.ps1`
- `tests\test_agentos_ci_smoke_split.ps1`
- `data\codex_tasks\2026-07-26-ci-smoke-stage-split\OUTPUTS\RESULT.md`（只 append 新節）

本 child 的三份 evidence artifacts 位於自己的 `OUTPUTS`。

## 2. Orchestrator 容錯實測

人工 hang 的第一個 suite 產生 TIMEOUT／exit 124 後，orchestrator 繼續啟動第二個 `dashboard_optional`，後者 PASS／exit 0／4 checks。總覽正確彙總 TIMEOUT、timeout count 1、exit 124。Fault test script 自身 exit 0。

## 3. Run-specific fault evidence

- Orchestrator：`ci-smoke-20260730-122255-876`
- Hang→TIMEOUT：`ci-smoke-governance_and_syntax-20260730-122255-876`
- 正常完成：`ci-smoke-dashboard_optional-20260730-122255-876`

三者 run-specific JSON/Markdown 均存在；summary overview 與 suite receipts 的 run ID 一致。完整絕對路徑及實際 stdout 見 `OUTPUTS\TEST_RESULT.md`。

## 4. 舊證據保留確認

執行前 parent OUTPUTS 188 files，執行後 198 files，舊路徑缺失 0。6 個 `latest.*` rolling aliases更新為本輪指標；舊 run-specific receipts 未刪除。四份依賴 Verify RESULT 仍存在，其 SHA-256 已寫入 TEST_RESULT 與 parent append section。

## 5. 限制與明確聲明

- 本次只跑一次、且只跑兩個短 suite 的 fault injection；沒有重跑 child-01～05，也沒有反覆跑完整 smoke。
- TIMEOUT wrapper receipt 的 `suite_timeout` check duration 為 2 秒；receipt overall duration 由 timeout fallback context 計算為 0.293 秒，兩者定義不同，本工單未擴大範圍修改 suite infrastructure。
- 本工單驗證的是 orchestrator fault isolation，不代表整體 CI smoke PASS。
- 最終完成狀態仍需另一個全新、獨立、read-only Codex Verify。

## 6. SCOPED_DIFF.patch

`E:\AgentOS\data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-06-orchestrator-fault-test\OUTPUTS\SCOPED_DIFF.patch`

## 7. commit hash

`not_created`

## 8. Evidence Block

```yaml
task_status: NEEDS_REVIEW
claimed_by: Codex Builder
artifact_status: complete
locally_verified: true
verified_by_codex: pending_independent_verify
reviewed_by_claude: false
approved_by_josh: inherited_parent_scope
cleanup_executed: false
live_external_action_executed: false
files_modified: scripts\agentos_ci_smoke.ps1; tests\test_agentos_ci_smoke_split.ps1; data\codex_tasks\2026-07-26-ci-smoke-stage-split\OUTPUTS\RESULT.md
files_created: data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-06-orchestrator-fault-test\OUTPUTS\RESULT.md; data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-06-orchestrator-fault-test\OUTPUTS\TEST_RESULT.md; data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-06-orchestrator-fault-test\OUTPUTS\SCOPED_DIFF.patch; run-specific JSON/Markdown receipts under parent OUTPUTS\test-artifacts\automated-timeout
commit_hash: not_created
evidence_paths: E:\AgentOS\data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-06-orchestrator-fault-test\OUTPUTS\RESULT.md; E:\AgentOS\data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-06-orchestrator-fault-test\OUTPUTS\TEST_RESULT.md; E:\AgentOS\data\codex_tasks\2026-07-26-ci-smoke-stage-split\OUTPUTS\test-artifacts\automated-timeout\ci-smoke-20260730-122255-876.json
verification_commands: Parser.ParseFile orchestrator/test; one execution of tests\test_agentos_ci_smoke_split.ps1; receipt JSON/schema/run_id validation; dependency Verify RESULT hash/existence checks
remaining_caveats: No full CI PASS claim; six latest aliases updated by design while immutable receipts remain; final PASS requires fresh independent Verify.
production_ready: false
```

changed_file: scripts\agentos_ci_smoke.ps1
changed_file: tests\test_agentos_ci_smoke_split.ps1
changed_file: data\codex_tasks\2026-07-26-ci-smoke-stage-split\OUTPUTS\RESULT.md
changed_file: data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-06-orchestrator-fault-test\OUTPUTS\RESULT.md
changed_file: data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-06-orchestrator-fault-test\OUTPUTS\TEST_RESULT.md
changed_file: data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-06-orchestrator-fault-test\OUTPUTS\SCOPED_DIFF.patch
change_required: true


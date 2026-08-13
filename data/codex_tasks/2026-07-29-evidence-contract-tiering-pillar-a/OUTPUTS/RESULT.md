# AgentOS Dispatch Result

dispatch_id: 2026-07-29-evidence-contract-tiering-pillar-a
status: completed
verification_status: verified_pass
change_required: true
changed_file: docs/EVIDENCE_AND_REPORTING_CONTRACT.md
changed_file: scripts/create_codex_verify_task.ps1

## 修改摘要

- Evidence Contract 第 3 節新增 `full` 與 `lightweight` 分級。workspace／production／external change、`BUILDER_TASK`、`CODEX_BUILD` 或 `change_required: true` 使用完整 16 欄；read-only/query-type 且無狀態變更才可使用 7 欄 lightweight；分類衝突使用 full。
- 第 3 節澄清 `unknown` 與 `not_applicable`：未嘗試或無法確認用前者；只有確認邏輯上不適用才用後者。
- 文件註明 Phase 1 僅 WARNING；Phase 2、3 是未來階段，未實作。
- Verify bundle 產生器新增結構 assessment，寫入 level、field count、missing fields、warning 與 enforcement phase。
- 欄位檢查只判定存在且非空；`unknown`／`not_applicable` 算已填；空白、純 Unicode 標點／符號與 Markdown placeholder 算缺失。

## Evidence 等級判斷

1. 重用現有 bundle 已算出的 `changeRequired`。
2. `change_required: true`、Builder/Build type、非 read-only task kind 或已執行 external action，任一成立即 full。
3. 無 full signal 且明確 read-only，或 query-type `change_required: false`，才使用 lightweight。
4. 缺少或互相衝突的分類資訊預設 full。

## 測試摘要

- PowerShell parser：0 errors。
- 指定 10 組結構案例：10/10 PASS；第 7 組另涵蓋 `!!!`、`???`、全形 `，。`。
- 端到端 bundle fixture：full `16/16`、warning false；lightweight 缺 `evidence_sources` 為 `6/7`、warning true；2/2 PASS。
- 所有 fixture 位於 temp 並已清理。

## 尚存限制

- Phase 1 不判斷欄位內容真實性或充分性，也不因缺欄自動 FAIL。
- Phase 2 與 Phase 3 未實作。
- 因工單精確限制只修改兩個核准檔案，未追加 `progress_log.md`；Evidence Contract 工作樹既有第 1、7 節差異不屬於本票，focused diff 已排除。
- `sync_shared_governance.ps1 -ApprovePaths docs\EVIDENCE_AND_REPORTING_CONTRACT.md` 以整檔 hash 更新 baseline，因而也涵蓋該檔先前既有第 1、7 節內容；本票不認領那些歷史差異的驗收。
- 本 session 是 Builder，自檢不構成最終驗證。

## Git

git_diff_stat: `2 files changed, 166 insertions(+), 6 deletions(-)`（工作樹整體；含本票以前已存在的 Evidence Contract 第 1、7 節差異）
commit_hash: not_created

## Evidence Block

task_status: implemented_pending_independent_verify
claimed_by: Codex Builder current session
artifact_status: created
locally_verified: true
verified_by_codex: false
reviewed_by_claude: not_applicable
approved_by_josh: true
cleanup_executed: true
live_external_action_executed: false
files_modified: E:\AgentOS\docs\EVIDENCE_AND_REPORTING_CONTRACT.md; E:\AgentOS\scripts\create_codex_verify_task.ps1
files_created: E:\AgentOS\data\codex_tasks\2026-07-29-evidence-contract-tiering-pillar-a\OUTPUTS\RESULT.md; E:\AgentOS\data\codex_tasks\2026-07-29-evidence-contract-tiering-pillar-a\OUTPUTS\TEST_RESULT.md
commit_hash: not_created
evidence_paths: E:\AgentOS\data\codex_tasks\2026-07-29-evidence-contract-tiering-pillar-a\OUTPUTS\RESULT.md; E:\AgentOS\data\codex_tasks\2026-07-29-evidence-contract-tiering-pillar-a\OUTPUTS\TEST_RESULT.md
verification_commands: PowerShell parser; C:\tmp\test_evidence_contract_tiering_20260729.ps1; two end-to-end temp bundle fixtures
remaining_caveats: Phase 1 warning-only; no semantic truth validation; pending independent Verify; historical mixed diff and whole-file baseline caveat disclosed
production_ready: false

independent_verify_result: E:\AgentOS\data\codex_tasks\2026-07-29-evidence-contract-tiering-pillar-a-codex-verify\OUTPUTS\RESULT.md

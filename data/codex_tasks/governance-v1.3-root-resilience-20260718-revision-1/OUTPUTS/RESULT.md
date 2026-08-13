# AgentOS Dispatch Result

dispatch_id: governance-v1.3-root-resilience-20260718-revision-1
route_to: Codex
codex_mode: verify
governance_version: 1.3.0
governance_hash: 0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1
status: completed
models_invoked: true
scripts_executed: true
cleanup_executed: false
dry_run: false
review_dispatch_id: not_created

## Findings

verify_verdict: FAIL

驗證結果：未通過。發現兩項會違反驗收條件的治理缺口，無須人工決策即可修正。

1. 唯讀治理檢查未對所有 policy 檔案即時 fail-closed

- [assert_governance_ready.ps1](E:/AgentOS/scripts/assert_governance_ready.ps1:36) 的 `-ReadOnly` 分支只重新計算 `AGENTS.md` 的 SHA-256。
- 其他 policy 檔案是否漂移，直接信任先前寫入的 `governance_status.json`。若 `agents\roles\*.md`、風險規則或治理腳本在最近掃描後被修改，唯讀 verifier 仍可能放行。
- [test_governance_tiers.ps1](E:/AgentOS/tests/test_governance_tiers.ps1:8) 只確認 status 檔案沒有被改寫，並讀取既有 drift count；未驗證非 `AGENTS.md` policy 漂移會被即時阻擋。
- 這違反「Read-only governance check does not write status and still fails closed on policy/hash/task mismatch」及 policy drift 必須阻擋的條件。

所需修正：讓唯讀模式直接依 baseline 重算全部 policy 檔案的存在狀態與 hash，但不寫入 status；增加一項非 `AGENTS.md` policy hash mismatch 的唯讀 fail-closed regression。

2. `-ApprovePaths` 在 baseline 缺少項目時可能吸收未核准 drift

- [sync_shared_governance.ps1](E:/AgentOS/scripts/sync_shared_governance.ps1:160) 對未列入 `ApprovePaths`、且舊 baseline 沒有對應項目的 tracked file，會在第 167 行加入目前 `$entry`。
- 因此執行不相關的 scoped approval 時，原本應為 `not_in_baseline` 的其他檔案可能被自動納入新 baseline。
- 現有測試沒有覆蓋「舊 baseline 缺項目＋只核准另一條路徑」情境。
- 這違反「`-ApprovePaths` approves only exact tracked paths and does not absorb other drift」。

所需修正：未核准且 baseline 缺少的項目不得加入更新後 baseline，或必須保留可被掃描為 `not_in_baseline` 的狀態；增加相應 regression。

其他證據：

- 治理握手一致：版本 `1.3.0`；實測 `AGENTS.md` SHA-256 與工單的 `0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1` 相符。
- 四個 PowerShell 腳本的唯讀 parser 檢查均為零錯誤。
- 交付證據記錄 classifier、diff helper、dispatcher resilience、queue reason propagation 均 PASS；實作亦包含 bounded wait、heartbeat、owned process-tree cleanup、timeout/nonzero reason、postprocess recovery，以及 `invalid_verify_output` 驗證。
- 本次未修改 workspace，也未重跑會建立 fixture artifact 的測試。

## Caveats

none
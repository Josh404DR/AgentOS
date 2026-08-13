# AgentOS Dispatch Result

dispatch_id: governance-v1.3-root-resilience-20260718-revision-3
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

verify_verdict: PASS

查核結果：

- `AGENTS.md` SHA-256 為 `0EAECF6D...3088EB1`，與工單治理綁定完全一致。
- 現場執行唯讀治理 gate：exit code `0`、`governance_status=aligned`、policy drift `0`、operational drift `0`、`task_execution_allowed=true`。
- gate 執行前後 `governance_status.json` 的 SHA-256 與修改時間皆未改變，確認沒有寫入狀態。
- operational baseline 中兩個核准條目的 SHA-256 均與目前檔案一致：
  - `dispatch_task_packet.ps1`: `65AD31FB...966F5`
  - `task_queue_runner.ps1`: `721A4A12...865F`
- `test_governance_tiers.ps1` 正向斷言已依 operational drift 數量決定預期狀態：零時接受 `aligned`，大於零時接受 `operational_review_required`，不再依賴人工製造 drift。
- 兩項負向回歸仍存在且最終證據記錄 PASS：
  - 非 `AGENTS.md` policy drift 必須以 exit code `22` fail-closed。
  - `-ApprovePaths` 不得吸收未明確核准的 missing-baseline entry。
- revision-2 verifier 已判定 dispatcher、queue、治理分層、角色邊界及 1346 classifier/diff 修正 PASS；revision-3 唯一來源變更限於上述正向測試斷言，未使該結論失效。
- revision-3 `TEST_RESULT.md` 記錄治理 gate、classifier、diff helper、dispatch resilience、governance tiers、queue reason propagation 全數 PASS。

## Caveats

none
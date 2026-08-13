# TEST_RESULT

dispatch_id: 2026-07-26-dashboard-plane-naming-consistency
executed_by: Codex Builder
result: PASS

## 治理前置檢查

- command: `scripts\assert_governance_ready.ps1`
- `governance_gate=passed`
- `governance_status=operational_review_required`
- `task_execution_allowed=true`
- `operational_drift_count=22`

## Scope 靜態檢查

- 檢查 `dashboard\backend\main.py` 全部 HTTP decorator。
- 結果：40/40 route 均含
  `public-read`、`owner-control`、`knowledge-append` 其中一個 tag。
- `protect_dashboard_mutations` 與 `_mutations_enabled()` 保持原行號
  147、154；檔案中沒有 `Depends(...)` route dependency 可被本次變更
  影響。

## 指定回歸測試

- `tests\test_dashboard_ux_contract.ps1`
  - result: `dashboard_ux_contract=PASS`
  - PowerShell success state: `True`
- `tests\test_dashboard_orphan_guard.ps1`
  - result: `dashboard_orphan_guard=PASS`
  - PowerShell success state: `True`

## 備註

- 測試為本次 workspace 變更後實際重跑結果，不沿用舊 artifact。
- Orphan guard 的 untrusted port owner 訊息是測試預期的 fail-closed
  fixture；整體測試結果為 PASS。
- 首次重跑包裝器錯用可能為空值的 `$LASTEXITCODE`，因此包裝器誤報
  exit 1；兩支測試當次均已輸出 PASS。修正為擷取 PowerShell `$?` 後
  再次重跑，兩支皆為 `True`，包裝命令 exit 0。

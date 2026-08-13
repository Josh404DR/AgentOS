# F02 B3 Dashboard Hermes HTTP Client Round 3 — Build Result

dispatch_id: 2026-07-29-f02-b3-dashboard-hermes-http-client-round3
result_status: verified_by_codex
change_required: true

## 1. Wildcard host 修正與測試

- `dashboard/backend/hermes_metrics_client.py` 改採明確 allowlist：僅接受 `127.0.0.1`、`localhost`、`::1`（不分大小寫）。
- `0.0.0.0`、`::`、`[::]`、空字串與其他 host 均在讀取 key 及呼叫 `httpx.get` 前拋出 `HermesMetricsUnavailable`，不再改寫為 `127.0.0.1`。
- 測試新增上述五種拒絕案例，直接追蹤環境變數存取並確認只讀取 `API_SERVER_HOST`、未讀取 `API_SERVER_KEY`、request 未送出；另覆蓋三種合法 loopback。

## 2. SCOPED_DIFF.patch 產製方式與完整性

- 根因：Round 2 產製流程把 PowerShell `ConvertTo-Json` 的非純字串項目交給 JavaScript 字串串接，隱式轉成 `[object Object]`。
- Round 3 使用 `generate_scoped_diff.py` 直接以 UTF-8 bytes 讀取三個 live 檔案、正規化 CRLF 為 LF，再以 Python `difflib.unified_diff` 建立 final-state unified diff。
- 生成器拒絕 `[object Object]` 與 `tokens truncated`，並重新解析 patch，逐檔比對 added content 與 live normalized content 的 SHA-256。
- patch 僅有三個 `+++ b/` section；污染標記掃描為 0。
- `SCOPED_DIFF.patch` SHA-256：`6C5DFF3BA9761A6B8A77FAF2487002B655E2D2C75F53BCA9F57CCEE049BB5308`

## 3. Patch 與 live 檔案雜湊

```text
dashboard/backend/main.py
8ff55a5ffe0b885fa21239c2af2befe0aed239aa99d2efbbc4e3cf11069aa522

dashboard/backend/hermes_metrics_client.py
e98a986bb404bfe5ff50a4579a40de315343f9f9389fc766ec5bf774002259cb

tests/test_dashboard_hermes_metrics_client.py
8b5cac250e607cae37f1139025bd51be0c988617014e45cce579e4bebec305c0
```

## 4. 測試結果

```text
pytest tests/test_dashboard_hermes_metrics_client.py tests/test_dashboard_security.py
28 passed, 9 warnings in 3.30s
exit_code=0

tests/test_dashboard_ux_contract.ps1
dashboard_ux_contract=PASS
exit_code=0

tests/test_dashboard_orphan_guard.ps1
dashboard_orphan_guard=PASS
exit_code=0
```

## 5. 限制與未解事項

- Round 1／2 的失敗報告與 `SCOPED_DIFF_INVALID_ROUND2.patch` 均保留；未覆寫舊證據。
- Round 3 首次 fresh Verify 發現 host 驗證仍晚於 key 讀取；已將 `_base_url()` 移至 key 讀取之前並新增存取順序測試，修正後待另一個全新 session 重驗。
- 首輪損毀 patch 曾被替換而未保存，既有證據保存缺失仍如實列為 caveat。
- 未修改 DTO／note 邏輯、Hermes、B1／B2／B4。
- B4 shadow parity／cutover 未核准或執行。
- 第二個全新 read-only Codex Verify 已判定 PASS；B4 不在範圍內，仍不可宣稱整體系統 production-ready。

## 6. Commit

commit_hash: not_created

## 7. Evidence Block

task_status: verified_by_codex
claimed_by: Codex Builder
artifact_status: artifact_created
locally_verified: true
verified_by_codex: true
reviewed_by_claude: unknown
approved_by_josh: true
cleanup_executed: not_applicable_no_cleanup_in_scope
live_external_action_executed: false
files_modified: E:\AgentOS\dashboard\backend\hermes_metrics_client.py; E:\AgentOS\tests\test_dashboard_hermes_metrics_client.py
files_created: E:\AgentOS\data\codex_tasks\2026-07-29-f02-b3-dashboard-hermes-http-client-round3\generate_scoped_diff.py; E:\AgentOS\data\codex_tasks\2026-07-29-f02-b3-dashboard-hermes-http-client-round3\OUTPUTS\SCOPED_DIFF.patch; E:\AgentOS\data\codex_tasks\2026-07-29-f02-b3-dashboard-hermes-http-client-round3\OUTPUTS\RESULT.md
commit_hash: not_created
evidence_paths: E:\AgentOS\data\codex_tasks\2026-07-29-f02-b3-dashboard-hermes-http-client-round3\OUTPUTS\RESULT.md; E:\AgentOS\data\codex_tasks\2026-07-29-f02-b3-dashboard-hermes-http-client-round3\OUTPUTS\SCOPED_DIFF.patch; E:\AgentOS\data\codex_tasks\2026-07-29-f02-b3-dashboard-hermes-http-client-round3\OUTPUTS\VERIFY_RESULT_ATTEMPT1.md; E:\AgentOS\data\codex_tasks\2026-07-29-f02-b3-dashboard-hermes-http-client-round3\OUTPUTS\VERIFY_RESULT.md; E:\AgentOS\data\codex_tasks\2026-07-29-f02-b3-dashboard-hermes-http-client\OUTPUTS\VERIFY_RESULT_ROUND1.md; E:\AgentOS\data\codex_tasks\2026-07-29-f02-b3-dashboard-hermes-http-client\OUTPUTS\VERIFY_RESULT_ROUND2.md
verification_commands: pytest B3 client + dashboard security; test_dashboard_ux_contract.ps1; test_dashboard_orphan_guard.ps1; generate_scoped_diff.py; contamination scan and section count
remaining_caveats: Round 3 first fresh Verify failed on key-read ordering, was corrected, and second fresh Verify passed; first corrupt patch was replaced without preservation; B4 out of scope; dashboard lacks tracked Git baseline
production_ready: false

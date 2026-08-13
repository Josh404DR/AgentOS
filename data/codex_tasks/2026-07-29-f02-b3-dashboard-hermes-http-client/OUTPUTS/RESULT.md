# F02 B3 Dashboard Hermes HTTP Client — Build Result

dispatch_id: 2026-07-29-f02-b3-dashboard-hermes-http-client
result_status: locally_verified
change_required: true

## 1. 修改摘要與檔案

- 修改 `dashboard/backend/main.py`：兩條 metrics 路徑改呼叫 B2 API，移除 `sqlite3` import 與 `HERMES_DB` 常數。
- 新增 `dashboard/backend/hermes_metrics_client.py`。
- 新增 `tests/test_dashboard_hermes_metrics_client.py`。
- 未修改 hermes-agent、runtime config schema 或 B4 範圍。

## 2. HTTP client 設計

- 使用 Dashboard 已宣告的 `httpx`。
- 每次僅一次 GET，`timeout=2.0`，沒有 retry／輪詢。
- 讀取 Hermes 相同來源環境變數：`API_SERVER_KEY`、`API_SERVER_HOST`、`API_SERVER_PORT`。
- 未配置 key 時在送出 request 前 fail-closed。
- Bearer key 僅存在 request header；client 僅允許 `127.0.0.1`／`localhost`／`::1` loopback，無 logging，不把 upstream body、key 或 exception detail傳給前端。
- 401／503／timeout／connection failure 映射為 unavailable；500／malformed JSON／schema mismatch 映射為 query failure。

## 3. 行為對照

- `_read_db_usage()` 成功仍只回 `total/window_5h/window_7d/recent_sessions/current_model`，移除 API envelope。
- `_context_window_pct()` 仍由 `_model_context_limit()` 計算；`used=input+output+cache_read`，不含 cache_write。
- notes 保持：`no recorded session`、`unknown model context limit`、`last session`、`usage database unavailable`、`usage query failed`。
- `rg` 實測 `main.py` 的 `sqlite3|HERMES_DB` refs 為 0。

## 4. 測試結果

新 client 與既有 Dashboard security 回歸：

```text
26 passed, 9 warnings, 2 subtests passed in 5.40s
exit_code=0
```

涵蓋 mock 200／401／500／503／timeout／malformed JSON、key 缺失、非 loopback host fail-closed、DTO shape、context notes/model calculation、2秒 timeout及單次 request。

Dashboard UX contract：

```text
dashboard_ux_contract=PASS
exit_code=0
```

AST：

```text
ast_parse=PASS files=3
```

## 5. 限制

- B4 shadow parity/cutover 驗證尚未核准或執行。
- AgentOS `dashboard/` 在目前 Git worktree 是 untracked，無 repository baseline 可產生一般 delta；SCOPED_DIFF 採 no-index final-state patch，Verifier 應逐檔比對 live content。
- Python 預設 launcher 無效；測試使用現有 Hermes `.venv` Python，未安裝或修改環境。
- 第一輪 fresh Verify 判 FAIL：發現非 loopback host 未阻擋及首份 patch 遭截斷污染。程式問題已修正；首份損毀 patch 在修正時直接替換、未先另存，這是證據保存程序缺失，未隱藏。
- 第二次 patch 因 chunk 邊界多出空白行未採用，已保留為 `SCOPED_DIFF_INVALID_ROUND2.patch`。
- 修正後 fresh independent Codex Verify 尚待重跑；不可宣稱 production-ready。

## 6. SCOPED_DIFF.patch

`E:\AgentOS\data\codex_tasks\2026-07-29-f02-b3-dashboard-hermes-http-client\OUTPUTS\SCOPED_DIFF.patch`

SHA-256: `69404FF480472C731DAC0D5F301163A60E7131DC26895FC95A28FF0C0D72D0CB`

僅含：

- `dashboard/backend/main.py`
- `dashboard/backend/hermes_metrics_client.py`
- `tests/test_dashboard_hermes_metrics_client.py`

## 7. Commit

commit_hash: not_created

## 8. Evidence Block

task_status: locally_verified
claimed_by: Codex Builder
artifact_status: artifact_created
locally_verified: true
verified_by_codex: false
reviewed_by_claude: unknown
approved_by_josh: true
cleanup_executed: not_applicable_no_cleanup_in_scope
live_external_action_executed: false
files_modified: E:\AgentOS\dashboard\backend\main.py
files_created: E:\AgentOS\dashboard\backend\hermes_metrics_client.py; E:\AgentOS\tests\test_dashboard_hermes_metrics_client.py; E:\AgentOS\data\codex_tasks\2026-07-29-f02-b3-dashboard-hermes-http-client\OUTPUTS\SCOPED_DIFF.patch; E:\AgentOS\data\codex_tasks\2026-07-29-f02-b3-dashboard-hermes-http-client\OUTPUTS\RESULT.md
commit_hash: not_created
evidence_paths: E:\AgentOS\data\codex_tasks\2026-07-29-f02-b3-dashboard-hermes-http-client\OUTPUTS\RESULT.md; E:\AgentOS\data\codex_tasks\2026-07-29-f02-b3-dashboard-hermes-http-client\OUTPUTS\SCOPED_DIFF.patch
verification_commands: pytest B3 + dashboard security; test_dashboard_ux_contract.ps1; AST parse; rg direct DB refs
remaining_caveats: first fresh Verify failed and correction awaits fresh reverify; first corrupt patch was replaced without preservation; invalid round2 patch preserved; B4 out of scope; dashboard has no tracked Git baseline
production_ready: false

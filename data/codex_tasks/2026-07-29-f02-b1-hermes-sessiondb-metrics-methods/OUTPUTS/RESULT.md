# F02 B1 Hermes SessionDB Metrics Methods — Build Result

dispatch_id: 2026-07-29-f02-b1-hermes-sessiondb-metrics-methods  
result_status: locally_verified  
changed_file: E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\hermes_state.py  
changed_file: E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\tests\test_sessiondb_metrics.py  
change_required: true

## 1. 修改摘要

已在 Hermes-owned `SessionDB` 增加兩個 read-only public methods：

- `get_usage_metrics()`：回傳 `total`、`window_5h`、`window_7d`、固定最近 20 筆 session 與 `current_model`。
- `get_latest_session_usage()`：回傳最新 session 的 context-window source 欄位；空 DB 回傳 `None`。

未加入 API route、未修改 Dashboard、未變更 `state.db` schema，亦未啟停 Hermes service。

## 2. 方法輸入、輸出與型別

### `SessionDB.get_usage_metrics() -> Dict[str, Any]`

- 輸入：無。
- 輸出：純 Python dict；不洩漏 `sqlite3.Row`。
- `total`：`session_count/api_calls/messages/tool_calls/input_tokens/output_tokens/cache_read/cache_write/est_cost/actual_cost/latest_session`。
- `window_5h`／`window_7d`：`session_count/input_tokens/output_tokens/cache_read/reasoning_tokens/est_cost`。
- `recent_sessions`：`ORDER BY started_at DESC LIMIT 20`，每筆只含 PLAN §2.1 指定欄位。
- `current_model`：最新 started session 的 model；空 DB 為 `None`。

### `SessionDB.get_latest_session_usage() -> Optional[Dict[str, Any]]`

- 輸入：無。
- 輸出：最新 session 的 `id/model/input_tokens/output_tokens/cache_read_tokens/cache_write_tokens/started_at/ended_at` 純 dict；空 DB 為 `None`。

`schema_version` 與 `generated_at` 刻意不由 B1 methods 產生，留給 B2 HTTP envelope。

## 3. lock／connection 使用與 read-only 證明

- 兩個 methods 都使用既有 persistent `self._conn`，未另開 sqlite connection。
- SQL 執行與 `fetchone()`／`fetchall()` 均位於既有 `with self._lock:` 臨界區。
- 離開 lock 前把所有 row 轉成 `dict`；caller 不會取得 cursor 或 sqlite row。
- 所有 SQL 均為 `SELECT`。測試在兩個 methods 前後比對 `self._conn.total_changes`，實測值未增加。
- 8-thread／40-call shared-connection concurrent reader 測試實際通過。

## 4. 測試案例與實測結果

執行環境：

- Python：`E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\.venv\Scripts\python.exe`
- Hermes `.venv` 原先沒有 pytest；未安裝套件。測試時只將本機既有 pytest site-packages 暫時加入 `PYTHONPATH`。
- 設定 `PYTHONDONTWRITEBYTECODE=1` 且停用 pytest cache provider，未在 repo 產生 bytecode/cache evidence。

新增測試涵蓋：

1. 空 DB 完整 zero/null shape。
2. NULL cost/token aggregate 正規化、5h/7d 資料與最新 session。
3. 5h/7d inclusive boundary。
4. recent sessions 最新優先且固定 20 筆。
5. 回傳純 dict，且 methods 不增加 `total_changes`。
6. 共享 connection concurrent reads（8 workers、40 calls）。

最終指令：

```powershell
$env:PYTHONDONTWRITEBYTECODE='1'
$env:PYTHONPATH='E:\AI_Projects_Hub\Projects\My_Second_Brain\My_Second_Brain\System\.venv\Lib\site-packages;E:\AI_Projects_Hub\External_AI_Agents\hermes-agent'
& 'E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\.venv\Scripts\python.exe' -m pytest -o 'addopts=' -p no:cacheprovider `
  'E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\tests\test_sessiondb_metrics.py' `
  'E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\tests\test_hermes_state.py' -q
```

實測：

```text
........................................................................ [ 33%]
........................................................................ [ 66%]
........................................................................ [ 99%]
..                                                                       [100%]
218 passed in 11.52s
exit_code=0
```

額外 AST parse：

```text
ast_parse=PASS files=2
exit_code=0
```

`ruff` 未執行成功，因 Hermes `.venv` 沒有 ruff：

```text
No module named ruff
exit_code=1
```

未為此安裝任何套件；此環境缺口未冒充 lint PASS。

## 5. 尚存限制／未解風險

- 本次僅完成 B1 persistence abstraction；HTTP auth、route/error mapping 屬 B2。
- 尚未由不同的 fresh read-only Codex Verify session 驗收，因此不可標記 `verified_by_codex` 或 `production_ready`。
- `get_usage_metrics()` 的多段 SELECT 受同一 process lock 保護，但未宣稱跨 process transaction-level snapshot；這與既有 persistent SQLite/WAL reader 模式相容。若 B2 要求原子跨查詢快照，需在其 scope 明確設計及測試。
- Hermes worktree 另有既存 unrelated dirty/untracked files；本工單未修改、刪除或納入 scoped diff。

## 6. SCOPED_DIFF.patch

路徑：

`E:\AgentOS\data\codex_tasks\2026-07-29-f02-b1-hermes-sessiondb-metrics-methods\OUTPUTS\SCOPED_DIFF.patch`

SHA-256：

`34B6DEB916D333267E3C3E366F37A46A9CB5783F707BB5D6CA418FEDA3F000A8`

Scoped diff 只包含：

- `hermes_state.py`
- `tests/test_sessiondb_metrics.py`

## 7. Commit

commit_hash: not_created

未執行 `git add`、commit 或 push。

## 8. Evidence Block（full）

task_status: locally_verified  
claimed_by: Codex Builder  
artifact_status: artifact_created  
locally_verified: true  
verified_by_codex: false  
reviewed_by_claude: unknown  
approved_by_josh: true  
cleanup_executed: not_applicable_no_cleanup_in_scope  
live_external_action_executed: false  
files_modified: E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\hermes_state.py  
files_created: E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\tests\test_sessiondb_metrics.py; E:\AgentOS\data\codex_tasks\2026-07-29-f02-b1-hermes-sessiondb-metrics-methods\OUTPUTS\SCOPED_DIFF.patch; E:\AgentOS\data\codex_tasks\2026-07-29-f02-b1-hermes-sessiondb-metrics-methods\OUTPUTS\RESULT.md  
commit_hash: not_created  
evidence_paths: E:\AgentOS\data\codex_tasks\2026-07-29-f02-b1-hermes-sessiondb-metrics-methods\OUTPUTS\RESULT.md; E:\AgentOS\data\codex_tasks\2026-07-29-f02-b1-hermes-sessiondb-metrics-methods\OUTPUTS\SCOPED_DIFF.patch; E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\tests\test_sessiondb_metrics.py  
verification_commands: AST parse of hermes_state.py and tests/test_sessiondb_metrics.py; pytest tests/test_sessiondb_metrics.py tests/test_hermes_state.py -q with addopts overridden and cache disabled  
remaining_caveats: fresh independent read-only Codex Verify pending; ruff unavailable in existing Hermes environment; B2 API route/auth not part of this scope  
production_ready: false

## Resource contribution summary

resource_contribution_summary:
  - resource: Codex desktop
    role: builder
    contribution: SessionDB methods、unit tests、local verification、delivery evidence
    artifacts: hermes_state.py; tests/test_sessiondb_metrics.py; SCOPED_DIFF.patch; RESULT.md
    cost_class: subscription
    usage_basis: not_available
underused_resources: not_applicable
overused_resources: none_observed
api_cost_reduction_opportunities: not_applicable
next_allocation_recommendation: 由 Claude review boundary/contract quality，再送不同的 fresh read-only Codex Verify；PASS 後才進 B2。

## Acceptance checklist

| 驗收項目 | 狀態 | 證據 |
|---|---|---|
| 兩個 public methods 符合 PLAN §2.1/§2.2 | pass | source、6 個新增 unit tests |
| 使用既有 lock/connection 且不改 schema | pass | source inspection、AST、`total_changes` test |
| 空 DB、NULL、5h/7d、recent 20、concurrent reads | pass | `6 passed` included in combined `218 passed` |
| 回傳純 dict，不洩漏 sqlite Row | pass | direct type assertions |
| 既有 SessionDB 回歸測試 | pass | `212` existing + `6` new = `218 passed` |
| Fresh independent Codex Verify PASS | fail | 尚未執行；Builder 不得自驗 |

因此本交付狀態為 `locally_verified`，不是 SUCCESS／production-ready。

# F02 B2 Hermes Metrics API Routes — Build Result

dispatch_id: 2026-07-29-f02-b2-hermes-metrics-api-routes
result_status: locally_verified
change_required: true

## 1. 修改摘要與修改檔案清單

已在 Hermes Gateway 既有 `APIServerAdapter` 新增兩個唯讀 metrics GET routes，直接包裝 B1 `SessionDB` 方法。未修改 B1、Dashboard、既有 chat/jobs/runs handler，亦未啟停真實服務。

修改／新增：

- `E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\gateway\platforms\api_server.py`
- `E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\tests\gateway\test_api_server_metrics.py`

## 2. 兩個新 route 的完整規格

### `GET /v1/metrics/usage`

- Auth：handler 第一個執行動作為既有 `_check_auth(request)`；即使 loopback 未設定 key，也 fail-closed 回 401。
- 成功：HTTP 200；加上 `schema_version: "1"`、UTC RFC 3339 `generated_at`，其餘為 `SessionDB.get_usage_metrics()` DTO。
- SessionDB 初始化或查詢失敗：HTTP 503，`metrics_unavailable`、`retryable: true`。
- 未分類 response/envelope 錯誤：HTTP 500，`internal_error`、`retryable: false`；server log 記錄 correlation id。

### `GET /v1/metrics/context-window-source`

- Auth：同上。
- 成功：HTTP 200；`schema_version`、`generated_at`、`latest_session`。
- 無 session：HTTP 200，`latest_session: null`。
- 503／500：同上。

兩個錯誤 response 均不包含 DB path、SQL、exception 或 stack。routes 註冊於既有 `connect()` 建立的 aiohttp application，並由既有 `disconnect()` 清除；未新增 process、CORS 或常駐生命週期。

## 3. 所有測試案例與實測結果

新增 9 項 contract tests，涵蓋：

1. usage 完整 response schema、版本與 UTC timestamp。
2. 合法 Bearer key。
3. 缺少 key。
4. 錯誤 key。
5. loopback 未配置 key 仍 fail-closed。
6. latest session 完整 DTO。
7. 空 DB／無 session 回 200 null。
8. DB unavailable／query failure 回 sanitized 503。
9. 未分類 envelope failure 回 sanitized 500 並記錄 correlation id。
10. connect／disconnect 擁有 route lifecycle，且測試不開真實 socket。

實測：

```text
9 passed, 1 warning in 1.57s
exit_code=0
```

warning 為 aiohttp 既有 `NotAppKeyWarning`，不是新增測試失敗。

AST：

```text
ast_parse=PASS files=2
exit_code=0
```

## 4. 既有 API server 相關測試結果

執行：

```text
tests/gateway/test_api_server.py
tests/gateway/test_api_server_bind_guard.py
tests/gateway/test_api_server_jobs.py
tests/gateway/test_api_server_runs.py
tests/gateway/test_api_server_multimodal.py
tests/gateway/test_api_server_normalize.py
tests/gateway/test_api_server_toolset.py
```

實測：

```text
275 passed, 163 warnings in 25.05s
exit_code=0
```

## 5. 尚存限制／已知不完美之處

- 本工單只完成 B2；Dashboard HTTP client/cutover 屬 B3/B4。
- `.venv` 沒有 ruff，因此未宣稱 lint PASS。
- `compileall` 因 sandbox 無權寫入 repo `__pycache__` 而失敗；已改用唯讀 AST parse 並通過。
- 尚待不同 fresh read-only Codex Verify session；目前不可標記 `verified_by_codex` 或 `production_ready`。
- Hermes worktree 原有 unrelated dirty/untracked files，本工單未修改、刪除或納入 scoped diff。

## 6. SCOPED_DIFF.patch

路徑：

`E:\AgentOS\data\codex_tasks\2026-07-29-f02-b2-hermes-metrics-api-routes\OUTPUTS\SCOPED_DIFF.patch`

SHA-256：

`FD534FFC551C9645C63200B26FA497A44DC0A4B8F1E2E0A8D8DD0BE9612FE58F`

只包含：

- `gateway/platforms/api_server.py`
- `tests/gateway/test_api_server_metrics.py`

## 7. Commit

commit_hash: not_created

未執行 git add、commit 或 push。

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
files_modified: E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\gateway\platforms\api_server.py
files_created: E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\tests\gateway\test_api_server_metrics.py; E:\AgentOS\data\codex_tasks\2026-07-29-f02-b2-hermes-metrics-api-routes\OUTPUTS\SCOPED_DIFF.patch; E:\AgentOS\data\codex_tasks\2026-07-29-f02-b2-hermes-metrics-api-routes\OUTPUTS\RESULT.md
commit_hash: not_created
evidence_paths: E:\AgentOS\data\codex_tasks\2026-07-29-f02-b2-hermes-metrics-api-routes\OUTPUTS\RESULT.md; E:\AgentOS\data\codex_tasks\2026-07-29-f02-b2-hermes-metrics-api-routes\OUTPUTS\SCOPED_DIFF.patch; E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\tests\gateway\test_api_server_metrics.py
verification_commands: pytest tests/gateway/test_api_server_metrics.py -q; pytest API server related files -q; AST parse files=2; git diff --check
remaining_caveats: fresh independent read-only Codex Verify pending; ruff unavailable; B3/B4 out of scope
production_ready: false

## Resource contribution summary

resource_contribution_summary:
  - resource: Codex desktop
    role: builder
    contribution: B2 handlers、contract tests、local verification、delivery artifacts
    artifacts: api_server.py; test_api_server_metrics.py; SCOPED_DIFF.patch; RESULT.md
    cost_class: subscription
    usage_basis: not_available
underused_resources: not_applicable
overused_resources: none_observed
api_cost_reduction_opportunities: not_applicable
next_allocation_recommendation: 交由不同 fresh read-only Codex Verify；PASS 後再等待 Josh 核准 B3。

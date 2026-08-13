# F02 B4 Live Integration Smoke — Result

dispatch_id: 2026-07-29-f02-b4-live-integration-smoke
result_status: verified_by_codex
governance_version: 1.3.0
governance_hash: 0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1

## 1. Gateway 正常時兩個路由的實際回傳內容與耗時

Gateway 實際監聽 `127.0.0.1:8642`，Dashboard backend 實際監聽
`127.0.0.1:8000`。正常階段觀察如下：

```json
{
  "route": "/api/usage",
  "status": 200,
  "elapsed_ms": 128.72,
  "body": {
    "total": {
      "session_count": 143,
      "api_calls": 2057,
      "messages": 3012,
      "tool_calls": 1301,
      "input_tokens": 24425250,
      "output_tokens": 490547,
      "cache_read": 115938020,
      "cache_write": 0,
      "est_cost": 0.0,
      "actual_cost": 0,
      "latest_session": 1782781617.824855
    },
    "window_5h": {
      "session_count": 0,
      "input_tokens": 0,
      "output_tokens": 0,
      "cache_read": 0,
      "reasoning_tokens": 0,
      "est_cost": 0
    },
    "window_7d": {
      "session_count": 0,
      "input_tokens": 0,
      "output_tokens": 0,
      "cache_read": 0,
      "reasoning_tokens": 0,
      "est_cost": 0
    },
    "recent_sessions_count": 20,
    "current_model": "openrouter/free"
  }
}
```

```json
{
  "route": "/api/context",
  "status": 200,
  "elapsed_ms": 28.25,
  "body": {
    "pct": null,
    "used": 158118,
    "total": null,
    "model": "openrouter/free",
    "note": "unknown model context limit"
  }
}
```

無關路由基準：`/api/tasks` 回 200，`673.24 ms`，共 644 筆 task。

## 2. Gateway 不可用時的降級行為實測

停止已驗證為 `gateway run` 的 `8642` listener 後：

```json
{
  "route": "/api/usage",
  "status": 200,
  "elapsed_ms": 2039.64,
  "body": {
    "error": "usage database unavailable"
  }
}
```

```json
{
  "route": "/api/context",
  "status": 200,
  "elapsed_ms": 2049.60,
  "body": {
    "pct": null,
    "used": null,
    "total": null,
    "model": null,
    "note": "usage database unavailable"
  }
}
```

- 未觀察到 HTTP 500、未處理例外或無限掛住；兩條 metrics 路由約在既定
  2 秒 timeout 後優雅降級。
- `/api/tasks` 同時回 200，`654.85 ms`，仍有 644 筆 task；Gateway
  不可用未阻擋此無關功能。

## 3. 恢復後的行為確認

使用相同的僅限程序環境 key 恢復 Gateway，未重啟 Dashboard backend：

- `dashboard_pid_unchanged_during_recovery: true`
- `/api/usage` 回 200，`52.46 ms`；資料回復為 143 sessions、20 recent
  sessions、`current_model: "openrouter/free"`。
- `/api/context` 回 200，`30.69 ms`；回復為
  `used: 158118`、`model: "openrouter/free"`、
  `note: "unknown model context limit"`。
- `/api/tasks` 回 200，`734.12 ms`，仍有 644 筆 task。
- runner 結束時 `restored: true`；其後再次實呼
  `/health`、`/api/usage`、`/api/context`、`/api/tasks` 均為 200。

## 4. 發現的任何問題

- 未發現產品鏈路的阻斷性 bug。
- 初始既有 Dashboard 程序早於 B3 修改啟動，曾回傳舊程式結果；重啟載入
  B3 後才開始正式量測，舊結果未作為整合成功證據。
- smoke runner 初版未建立 `OUTPUTS` 目錄且 Gateway 6 秒 startup
  threshold 過短；這兩項 harness 問題已在 task artifact 修正。每次失敗後
  均實查服務狀態，最終成功 run 的 observations 覆寫空白／失敗狀態。

## 5. 尚存限制／已知不完美之處

- Hermes profile 原先未配置 `API_SERVER_ENABLED/HOST/PORT/KEY`。本次以
  loopback、隨機且不落盤的程序環境 key 啟用；目前服務正常，但機器或
  Gateway 下次重啟後不保證 API server 自動啟用。持久化部署設定應另開
  核准工單，不在本次唯讀 smoke 範圍。
- `/api/context` 的 `pct/total` 為 null，實際 note 是
  `unknown model context limit`；這是 model limit 未知的既有設計，不是假裝
  有新鮮百分比。
- `OUTPUTS/OBSERVATIONS.json` 保存的是成功 run 的實際資料摘要；usage 的
  20 筆 session 明細未逐筆複製，只記錄 count 與完整 aggregate DTO。
- 工單要求 lightweight 7 欄，但
  `docs/EVIDENCE_AND_REPORTING_CONTRACT.md` 第 3 節規定
  `BUILDER_TASK` 或執行 external/production state 操作時必須使用 full 16
  欄；依高層治理採 full，不自動降級。

Acceptance checklist：

- pass：記錄正常時兩路由實際 DTO、HTTP 狀態與耗時。
- pass：記錄不可用時降級 DTO、HTTP 狀態、耗時及無關功能。
- pass：不重啟 Dashboard 即恢復 metrics。
- pass：未修改任何產品程式碼。
- pass：Gateway 與 Dashboard 最終均恢復正常。

## 6. Evidence Block

task_status: verified_by_codex
claimed_by: Codex Builder
artifact_status: artifact_created
locally_verified: true
verified_by_codex: true
reviewed_by_claude: unknown
approved_by_josh: true
cleanup_executed: not_applicable_no_cleanup_in_scope
live_external_action_executed: true
files_modified: E:\AgentOS\data\codex_tasks\2026-07-29-f02-b4-live-integration-smoke\OUTPUTS\OBSERVATIONS.json
files_created: E:\AgentOS\data\codex_tasks\2026-07-29-f02-b4-live-integration-smoke\run_smoke.ps1; E:\AgentOS\data\codex_tasks\2026-07-29-f02-b4-live-integration-smoke\OUTPUTS\OBSERVATIONS.json; E:\AgentOS\data\codex_tasks\2026-07-29-f02-b4-live-integration-smoke\OUTPUTS\RESULT.md
commit_hash: not_created
evidence_paths: E:\AgentOS\data\codex_tasks\2026-07-29-f02-b4-live-integration-smoke\OUTPUTS\OBSERVATIONS.json; E:\AgentOS\data\codex_tasks\2026-07-29-f02-b4-live-integration-smoke\OUTPUTS\RESULT.md; E:\AgentOS\data\codex_tasks\2026-07-29-f02-b4-live-integration-smoke\OUTPUTS\VERIFY_RESULT.md; E:\AgentOS\data\codex_tasks\2026-07-29-f02-b3-dashboard-hermes-http-client-round3\OUTPUTS\RESULT.md; E:\AgentOS\data\codex_tasks\2026-07-29-f02-b2-hermes-metrics-api-routes\OUTPUTS\RESULT.md
verification_commands: assert_governance_ready.ps1; run_smoke.ps1; Invoke-WebRequest post-run health/usage/context/tasks; SHA-256 check of B3 product files
remaining_caveats: API server settings are process-only and non-persistent; fresh Codex Verify passed; Claude review pending; task requested lightweight block but governing contract requires full
production_ready: false

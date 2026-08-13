# SCC P0 外部任務接入 API — Builder Result

1. 新增端點與 auth 實作摘要

完成 `POST /api/v1/external/tasks`、GET status/result/health；machine-to-machine
key 使用 `hmac.compare_digest`，未配置/過短 fail-closed 503，錯誤 key 401。
dispatch_id 有 allowlist 與 resolve 邊界檢查。治理 hash 從現場 `AGENTS.md`
計算並與 governance status 交叉核對。修正 API 輸入 `Codex CLI`/`Claude CLI`
映射為既有 dispatcher 接受的 `Codex`/`Claude`，並產生
`PROMPT_FOR_CODEX.md`。補 title/client_ref 換行注入防護。

2. live 端到端測試紀錄（建單→queue 取單→RESULT 產出）

initial fixture: `scc-20260804-163056-scc-live-readonly-fixture-f955`

revision-1 transcript fixture: `scc-20260805-010156-scc-live-readonly-fixture-de5c`

API 回 queued；既有 `start_task_queue.ps1` 啟動 runner PID 27856，runner
回執 `dispatcher_exit_0`，route `Codex`、mode `plan`，產生 RESULT.md，內容
只讀取 `docs\ARCHITECTURE.md` 並回報其存在與第一個 Markdown heading。
後續 status/result GET 均 200，dispatch_status completed、result 非空。

3. fail-closed 與負面測試結果

unit 未配置 key 503、短 key 503、缺/錯 key 401；live 錯 key 401；live
`%2e%2e%5cAGENTS.md` traversal 400。256-bit 隨機 key 已用 Windows 相容的
cryptographic RNG 產生並存入 User scope；key 值未寫入 git、log、RESULT。

4. 測試結果（新增+既有回歸）

新增測試 12/12 PASS；dashboard security/Hermes metrics client/knowledge
workspace 回歸 48/48 PASS。完整命令與 live 摘要見 `OUTPUTS\TEST_RESULT.md`。

5. 尚存限制

- 只綁 localhost；遠端隧道不在本工單範圍。
- `queue_runner_alive` 以 ACTIVE_TASK_INDEX 180 秒內更新作為最小資訊
  heartbeat 判定，不讀取/洩漏 process command line。
- FastAPI TestClient 顯示既有 StarletteDeprecationWarning，不影響結果。
- workspace 仍為治理掃描所示 `operational_review_required`，未宣稱
  production-ready。

6. SCOPED_DIFF.patch

初版：`E:\AgentOS\data\codex_tasks\2026-08-04-scc-external-task-api\OUTPUTS\SCOPED_DIFF.patch`

Verifier 第 1 輪修正：`E:\AgentOS\data\codex_tasks\2026-08-04-scc-external-task-api\OUTPUTS\REVISION_1_SCOPED_DIFF.patch`

7. commit hash

`5670320` — `feat: complete SCC external task API live integration`。

`a830289` — `fix: preserve SCC status metadata and verify verdicts`。

兩者均未 push。
前置 F13 commit `e9c8864` 已納管 Claude 預先存在的 main.py 路由整合及 API
初版；本 commit 是測試後的修正與新增 12 項測試。

8. Evidence Block（full 16欄）

task_status: completed
claimed_by: Codex Builder current session
artifact_status: RESULT.md, TEST_RESULT.md, scoped patches, live transcript and retained round-1 FAIL created; three commits across F13/SCC created; not pushed
locally_verified: 12 new tests and 48 regression tests passed; live E2E and negative HTTP checks completed
verified_by_codex: PASS by fresh independent read-only revision-1 Verify session verify_scc_r1; round-1 FAIL retained
reviewed_by_claude: initial implementation pre-existed per TASK.md; current fixes not reviewed by Claude
approved_by_josh: current request explicitly instructed both tickets including live E2E and fresh Verify
cleanup_executed: false; live fixture retained as auditable evidence
live_external_action_executed: true_localhost_HTTP_and_Windows_User_scope_environment_only
files_modified: dashboard/backend/external_task_api.py
files_created: tests/test_external_task_api.py, data/codex_tasks/2026-08-04-scc-external-task-api/OUTPUTS/RESULT.md, data/codex_tasks/2026-08-04-scc-external-task-api/OUTPUTS/TEST_RESULT.md, data/codex_tasks/2026-08-04-scc-external-task-api/OUTPUTS/SCOPED_DIFF.patch, data/codex_tasks/2026-08-04-scc-external-task-api/OUTPUTS/REVISION_1_SCOPED_DIFF.patch, data/codex_tasks/2026-08-04-scc-external-task-api/OUTPUTS/LIVE_REQUEST_FIXTURE.json, data/codex_tasks/2026-08-04-scc-external-task-api/OUTPUTS/LIVE_HTTP_TRANSCRIPT.md, data/codex_tasks/2026-08-04-scc-external-task-api/OUTPUTS/VERIFY_ROUND_1.md
commit_hash: 5670320, a830289
evidence_paths: E:\AgentOS\data\codex_tasks\2026-08-04-scc-external-task-api\OUTPUTS\RESULT.md, E:\AgentOS\data\codex_tasks\2026-08-04-scc-external-task-api\OUTPUTS\TEST_RESULT.md, E:\AgentOS\data\codex_tasks\2026-08-04-scc-external-task-api\OUTPUTS\SCOPED_DIFF.patch, E:\AgentOS\data\codex_tasks\2026-08-04-scc-external-task-api\OUTPUTS\REVISION_1_SCOPED_DIFF.patch, E:\AgentOS\data\codex_tasks\2026-08-04-scc-external-task-api\OUTPUTS\LIVE_HTTP_TRANSCRIPT.md, E:\AgentOS\data\codex_tasks\scc-20260805-010156-scc-live-readonly-fixture-de5c\OUTPUTS\RESULT.md, E:\AgentOS\data\queue_runs\scc-20260805-010156-scc-live-readonly-fixture-de5c.stdout.log
verification_commands: assert_governance_ready.ps1 for both TASK.md; unittest 12-case SCC suite; unittest 48-case regression; live POST/status/result/health/wrong-key/traversal; existing queue runner
remaining_caveats: localhost only; heartbeat is index freshness; operational_review_required pre-exists; round-1 Verify FAIL retained
production_ready: false_operational_review_required

# F14 Hermes API Server Persistent Config — Build Result

dispatch_id: 2026-07-29-f14-hermes-api-server-persistent-config
result_status: verified_by_codex
governance_version: 1.3.0
governance_hash: 0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1

## 1. Dashboard backend 目前實際啟動方式的調查結果

- 正本：Scheduled Task `AgentOS-Dashboard`。
- 登錄證據：`dashboard/register_autostart.ps1` 設定 task；
  `config/runtime_registry.json` 指向 `dashboard/start.ps1`。
- backend 實際命令由 `dashboard/start.ps1` 啟動：
  `python -m uvicorn main:app --host 127.0.0.1 --port 8000`。
- runtime receipt 為 `data/runtime_receipts/dashboard-backend.json`。

## 2. 選定的 key 持久化機制與理由

採 Windows 使用者層級環境變數：

```text
API_SERVER_ENABLED=true
API_SERVER_HOST=127.0.0.1
API_SERVER_PORT=8642
API_SERVER_KEY=<REDACTED, 64 hex characters>
```

- key 使用 Windows PowerShell 5.1 相容的
  `RandomNumberGenerator.Create().GetBytes()` 產生 256-bit 隨機值。
- key 僅寫入目前使用者的 `HKCU\Environment`，未寫入 workspace、
  git-tracked file、log、patch、report 或 commit。
- 選擇 User scope 是因 Gateway 與 Dashboard 是獨立 process；兩者可共享
  同一個持久化來源，不需另建 secret file。
- 精確洩漏掃描結果：
  `tracked_secret_matches=0`、
  `scoped_log_code_artifact_secret_matches=0`。
- 初次嘗試使用 PowerShell 5.1 不支援的
  `RandomNumberGenerator.Fill/Convert.ToHexString`，key 未建立且驗證為
  false；隨即以相容 API 重建並驗證 `key_length=64`。失敗未被隱藏。

## 3. watchdog.ps1 的具體修改內容

- 新增 `Set-HermesApiServerEnvironment`：
  - 每次啟動 main Gateway 前從 User scope 重新讀取四項設定。
  - 缺值即 fail-closed。
  - 強制 enabled=`true`、host=`127.0.0.1`。
  - 驗證 port 合法、key 至少 32 字元。
  - 驗證後才注入 watchdog process，供 Gateway child 繼承。
- main Gateway 判定由寬鬆的全機 `gateway run` 掃描改為讀取
  `%LOCALAPPDATA%\hermes\gateway.lock`，驗證該 PID command line。
- 此修正避免 Hermes Lite gateway 被誤認成 main Gateway；fresh-session
  首測曾實際命中此既有問題，修正後 watchdog 成功建立 `8642` listener。
- 未修改 Hermes `api_server.py/config.py` 或認證邏輯。

## 4. 全新 session 下的端到端驗證結果

測試 runner 先把自身 Process scope 的四項 API 變數全部清空，再由獨立
`powershell.exe -NoProfile` 執行 `watchdog.ps1 -Once`。

```json
{
  "process_scope_cleared_before_test": true,
  "runner_process_scope_still_clear_after_watchdog": {
    "API_SERVER_ENABLED": false,
    "API_SERVER_HOST": false,
    "API_SERVER_PORT": false,
    "API_SERVER_KEY": false
  },
  "user_settings": {
    "enabled": "true",
    "host": "127.0.0.1",
    "port": "8642",
    "key_configured": true,
    "key_length": 64,
    "key": "REDACTED"
  },
  "watchdog_exit_code": 0
}
```

Gateway 直接 authenticated API：

```text
GET /v1/metrics/usage
status=200 elapsed_ms=75.51 schema_version=1 session_count=143

GET /v1/metrics/context-window-source
status=200 elapsed_ms=14.42 schema_version=1
latest_model=openrouter/free
```

Dashboard backend 由 Process scope 無 API 變數的 runner 獨立啟動；B3 client
在 process env 缺值時唯讀回退至 `HKCU\Environment`：

```text
GET /api/usage
status=200 elapsed_ms=132.07 session_count=143
current_model=openrouter/free

GET /api/context
status=200 elapsed_ms=41.77 used=158118
model=openrouter/free note="unknown model context limit"
```

最終唯讀 audit：

```text
gateway_pid=9212 command contains "gateway run --accept-hooks"
dashboard_pid=1860 command contains "uvicorn main:app ... --port 8000"
direct_authenticated_metrics_status=200
dashboard_usage_status=200
key=REDACTED
```

未做真正機器重開機。替代測試證明 User registry 是唯一 API 設定來源、
watchdog session 與 Dashboard process 不依賴本互動 shell export；但仍不能
完全取代 Windows reboot、Task Scheduler 登入時序及長期穩定性驗證。

## 5. 尚存限制／已知不完美之處

- User environment 更新後，當前登入階段由長壽 parent 建立的 process
  可能繼承舊 environment block；實測新的 broker session Process scope 仍為
  空。因此 watchdog 明確 hydrate，Dashboard client 明確 registry fallback。
- `scripts/start.ps1` 未修改（不在核准修改範圍）。從真正 fresh
  logon/session 手動啟動會取得 User env；從更新前已存在的舊 shell 手動
  啟動則可能仍缺值，應重新開 shell。
- fresh-session runner 曾 timeout；nested process 後續仍完成並寫出成功
  observations。緊接的另一 invocation 因重複綁定 8000 回 exit 1。最終以
  observations、listener command line、直接 auth 及 Dashboard 200 四組證據
  交叉確認，目前兩服務正常；未把 runner exit 1 當成功證據。
- watchdog 的 `cron list` 可能讓 `-Once` 完整退出時間變長；Gateway listener
  本身已正常建立。此非本工單 metrics API 設定範圍。
- 未 commit 或 push；尚待 fresh read-only Codex Verify。

Acceptance checklist：

- pass：記錄 Dashboard Scheduled Task／start script／uvicorn 啟動鏈。
- pass：User-scope 256-bit key 持久化且洩漏掃描為 0。
- pass：watchdog fresh session 啟動 authenticated metrics API。
- pass：Process scope 清空的獨立 Dashboard process E2E 成功。
- pass：未修改 Hermes 認證或 B3 DTO／note 邏輯。
- pass：兩服務最終恢復正常。
- pass：第二個 fresh independent Codex Verify 已完成 privileged
  read-only audit 並判定成功。

## 6. SCOPED_DIFF.patch

`E:\AgentOS\data\codex_tasks\2026-07-29-f14-hermes-api-server-persistent-config\OUTPUTS\SCOPED_DIFF.patch`

SHA-256：
`78146B68C4251805874C7A00700EF8BD12ABDE4C6347ED470767D09591105ECB`

僅含 F14 對以下兩個檔案的變更：

- `scripts/watchdog.ps1`
- `dashboard/backend/hermes_metrics_client.py`

patch 不包含 pre-F14 已存在的 unrelated watchdog runtime-config dirty hunk。

## 7. Commit

commit_hash: b6f987e1f2516aa8cba482d914889c4de1b8a823

Commit 收尾證據：
`E:\AgentOS\data\codex_tasks\2026-07-29-f14-hermes-api-server-persistent-config\OUTPUTS\COMMIT_RESULT.md`

## 8. Evidence Block

task_status: verified_by_codex
claimed_by: Codex Builder
artifact_status: artifact_created
locally_verified: true
verified_by_codex: true
reviewed_by_claude: unknown
approved_by_josh: true
cleanup_executed: not_applicable_no_cleanup_in_scope
live_external_action_executed: true
files_modified: E:\AgentOS\scripts\watchdog.ps1; E:\AgentOS\dashboard\backend\hermes_metrics_client.py; Windows User environment API_SERVER_ENABLED/API_SERVER_HOST/API_SERVER_PORT/API_SERVER_KEY
files_created: E:\AgentOS\data\codex_tasks\2026-07-29-f14-hermes-api-server-persistent-config\run_fresh_session_test.ps1; E:\AgentOS\data\codex_tasks\2026-07-29-f14-hermes-api-server-persistent-config\generate_scoped_diff.py; E:\AgentOS\data\codex_tasks\2026-07-29-f14-hermes-api-server-persistent-config\OUTPUTS\FRESH_SESSION_OBSERVATIONS.json; E:\AgentOS\data\codex_tasks\2026-07-29-f14-hermes-api-server-persistent-config\OUTPUTS\SCOPED_DIFF.patch; E:\AgentOS\data\codex_tasks\2026-07-29-f14-hermes-api-server-persistent-config\OUTPUTS\RESULT.md
commit_hash: b6f987e1f2516aa8cba482d914889c4de1b8a823
evidence_paths: E:\AgentOS\data\codex_tasks\2026-07-29-f14-hermes-api-server-persistent-config\OUTPUTS\FRESH_SESSION_OBSERVATIONS.json; E:\AgentOS\data\codex_tasks\2026-07-29-f14-hermes-api-server-persistent-config\OUTPUTS\SCOPED_DIFF.patch; E:\AgentOS\data\codex_tasks\2026-07-29-f14-hermes-api-server-persistent-config\OUTPUTS\RESULT.md; E:\AgentOS\data\codex_tasks\2026-07-29-f14-hermes-api-server-persistent-config\OUTPUTS\VERIFY_RESULT_ATTEMPT1.md; E:\AgentOS\data\codex_tasks\2026-07-29-f14-hermes-api-server-persistent-config\OUTPUTS\VERIFY_RESULT.md
verification_commands: assert_governance_ready.ps1; pytest B3 client + Dashboard security; watchdog AST parse; run_fresh_session_test.ps1; authenticated direct B2 API audit; Dashboard usage audit; git/scoped log secret leak scan; generate_scoped_diff.py
remaining_caveats: true reboot not tested; stale pre-update shells may lack refreshed User env; fresh-session harness had timeout/duplicate-bind race but final observations and privileged independent audit agree; first verifier was partial due sandbox visibility, second verifier passed; preexisting unrelated watchdog dirty hunk excluded
production_ready: false

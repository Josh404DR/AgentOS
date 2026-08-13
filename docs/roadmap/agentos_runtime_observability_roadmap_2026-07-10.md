# AgentOS Runtime Observability Roadmap（設計文件，不含實作）

date: 2026-07-10（晚間）
author: Claude（Cowork session）
governance_version: 1.2.0
governance_hash: ad20e91afb53ef06800077f420f8f441e57eeea0e906794ff219e63f0ffe39c3
status: **Plan 產出，未經獨立覆核**——最終需 fresh session（Codex Verify 或 fresh Claude session）獨立覆核設計可行性與遺漏後才能開工單實作。
硬邊界（本輪已遵守）：未修改任何現有程式碼/腳本/設定；未執行任何改變 governance 狀態的動作；發現的既有缺陷只記錄於附錄 A，未順手修。所有變更需 Josh 逐階段核准。
依據：`docs\hermes_ecosystem_inventory_and_optimization_proposal_2026-07-10.md`（r2，Codex Verify (a)(b) PASS）；本檔引用其盤點結果並於 §1.1 做時效確認。

標示規則：**[已證實]** = 有檔案:行號或命令輸出；**[推論]**；**[owner-provided]** = Josh 口述今晚實測、尚無落檔證據；**unknown** = 拿不到。

---

## 0. 問題定義與設計原則

今晚的共同病徵：**系統的真實狀態只存在於散落的 log 與人的猜測裡**。任務卡住 timeout 看起來像伺服器掛掉；工單進度靠翻 log；Dashboard 本身故障時連既有可見性都歸零。這不是 bug 清單，是缺一個「統一可觀測性層」。

設計原則（每條都有今晚的教訓對應）：

- **P1 觀測層 fail-open**：觀測寫入失敗絕不阻擋任務執行（與治理閘門的 fail-closed 相反且並存）。教訓：不能再多一個會把系統卡死的環節。
- **P2 確定性收集，不呼叫模型**：狀態判定只依 registry 規則＋檔案/process 證據（呼應 AGENTS.md §6「本機檢查不呼叫模型」與 §8「Dashboard 治理狀態只能依本地掃描證據」）。
- **P3 exit code 是真相，stderr 只是文字**：嚴重度分類以 exit code 為準，stderr 內容只可補充、不可單獨升級為 fatal。教訓：git warning 被誤判 fatal [owner-provided]。
- **P4 身份與環境在 process 起點快照**：每個 runtime/worker 啟動時記錄 `whoami` 與環境變數指紋。教訓：CodexSandboxOffline vs brian、Path/PATH duplicate [owner-provided]。
- **P5 有心跳才叫活著，沒心跳不等於死了**：區分 `running`（心跳新鮮）/`running-long`（心跳新鮮但同一 phase 很久）/`stale`（心跳過期）/`down`（process 不在）/`unknown`。教訓：長任務無進度回報 → 看起來像當機 [owner-provided]；watchdog_state 停滯 20 天卻無人知道 [已證實]。
- **P6 觀測層自己也要被觀測**：collector 寫自己的心跳；否則重蹈 watchdog 覆轍（殭屍監控製造假安全感）。
- **P7 單寫者**：每個 runtime 的心跳檔只有該 runtime 自己寫；collector 與 Dashboard 只讀。
- **P8 不捏造**：拿不到的欄位寫 `unknown`（例如 hermes.exe 內部狀態——外部專案，只能 probe 不能打點）。
- **P9 編碼紀律**：所有新 JSON/JSONL 一律 UTF-8 無 BOM、經 `[IO.File]` API 寫入。教訓：escalation JSON options 中文亂碼（附錄 A-2）。
- **P10 檔案放置避開治理動態掃描**：新資料一律放 `data\observability\`（不受掃描）；新腳本放 `scripts\`（靜態清單外不觸發 drift [已證實：sync_shared_governance.ps1:14-56 為固定清單]）。將來納入治理受管需另案走 `-ApproveBaseline`，列為各 Phase 的 Josh 核准點。

---

## 1. Runtime 盤點（需求 1）

### 1.1 時效確認

引用今晚盤點報告 r2 的腳本盤點表，本檔撰寫前已重新核對 [已證實，2026-07-10 晚間命令輸出]：AGENTS.md hash 未變；`scripts\` 自 14:30 後唯一新增檔為 `promote_draft.ps1`（15:30，5,997 bytes，**已實作但 Codex Verify 判 fail**——dispatch 1273，不得視為可信完成品）；`apply_agentos_changes.ps1` **尚不存在**（dispatch 1264 未在 `scripts\` 產出檔案，工單實際狀態 uncertain）；`data\observability\` 與 `scripts\lib\` 均不存在（本設計的命名空間乾淨）。其餘盤點資料與 r2 一致。

### 1.2 Runtime 清單

| runtime_id | 主題 | 啟動來源 | process / port | log | state file | 身份 | 觸發條件 | 現況證據 |
|---|---|---|---|---|---|---|---|---|
| `hermes-main-gateway` | 主 Telegram/LINE gateway（PLUGIN_MODE=task_only） | schtask `HermesGatewayAutostart`（AtLogOn+30s）→ `start.ps1 -SkipProxy` | `hermes.exe gateway run`；port unknown | `logs\hermes-gateway.*` | 無 | `LAPTOP-IMPR60B8\brian` | 登入/手動 | 7/10 12:20 banner [已證實] |
| `hermes-lite-gateway` | 輕量聊天 gateway（hermes-lite profile，chat_only，Groq） | schtask `HermesLiteAutostart` → `start_hermes_lite.ps1` | `hermes.exe gateway run`；port unknown | `logs\hermes-lite-gateway.*` | 無 | brian（registration log `run_level=Limited`）[已證實] | 登入/手動 | 7/10 12:12 banner [已證實] |
| `hermes-proxy` | 主 gateway 附屬 proxy | `start.ps1`（未帶 -SkipProxy 時） | `hermes.exe proxy` | `logs\hermes-proxy.*` | 無 | brian | 排程帶 -SkipProxy → 常態不跑 [推論] | 無近期 log |
| `dashboard-backend` | 看板 API（FastAPI） | schtask `AgentOS-Dashboard` → `dashboard\start.ps1` | python/uvicorn，port 8000 | `logs\dashboard-backend.*` | 無 | brian | 登入/手動 | log 持續更新 [已證實] |
| `dashboard-frontend` | 看板 UI（Next.js） | 同上 | node，port 3000 | `logs\dashboard-frontend.*` | 無 | brian | 同上 | 同上 |
| `watchdog` | gateway 存活監控 | `start.ps1 -StartWatchdog`（無獨立排程） | powershell 迴圈 | `logs\watchdog_state.json` | 同左 | brian | 手動連帶 | **未運行**：state 停滯 2026-06-20 [已證實]；三缺陷見盤點 F3 |
| `task-queue-runner` | 單 root 工單執行迴圈 | `start_task_queue.ps1`（背景 PS，有單實例保護 [已證實:36-56]） | powershell，per-root | `logs\task-queue.log`＋per-run stdout/err | `data\queue_runs\<id>.json` | brian | 工單事件 | 7/10 有 run [已證實] |
| `workflow-supervisor` | 跨 root 巡檢（escalation 解除、完結判定） | plugin `_run_workflow_supervisor`／dashboard approve hook（main.py:1224-1228）[已證實] | per-event PS process，無常駐 | 無專屬 log（輸出回呼叫端） | 無 | brian | 事件 | 呼叫鏈已證實 |
| `governance-gate` | 治理閘門＋狀態生產 | 16 個派工腳本 per-invocation | per-event PS | 無專屬 log | `data\governance\governance_status.json`＋`governance_baseline.json` | brian | 每次派工 | [已證實] |
| `escalation-approval` | 等 Josh 決策迴路 | dashboard API `/api/approvals/*` → `decide_escalation.ps1` | 依附 dashboard-backend | 無 | `data\escalations\**` | brian（`_require_local_request` 防護 [已證實:1210]） | Josh 操作 | 14/14 實績 [已證實] |
| `typed-dispatch-router` | 每則訊息必經的分流路由層（plugin ENTRYPOINT → 純規則路由） | plugin `__init__.py:20` → `telegram_typed_dispatch_entry.ps1` → `typed_dispatch.ps1` | per-event PS | `data\routing_decisions\<id>\`＋`data\routing\routing_cache.jsonl` | 同左 | brian | 每則 Telegram 訊息 | 呼叫鏈 [已證實]（r2 依 fresh 審查補列——漏掉它則 Phase 0「100% runtime」驗收形同虛設） |
| `url-intake-workers` | URL/Threads 情報管線 | plugin per-message subprocess | per-event PS | 工單 OUTPUTS | 工單目錄 | brian | Telegram 訊息 | [已證實] |
| `antigravity-poll-workers` | 低成本輔助 worker 輪詢 | `poll_antigravity_worker.ps1` | per-invocation | `logs\antigravity_poll_*.log`（最後 7/6） | unknown | brian | **凍結中**（current_state §7） | log 7/6 後無活動 [已證實] |
| `hermes-internal-cron` | gateway 內部排程（daily-upwork-lead-patrol、daily-agentos-health-check、Daily-Token-Cost-Summary） | hermes.exe 內部 cron，**依附 gateway 存活** | 隨 gateway | unknown（hermes profile 內） | unknown | brian | 每日 | 名單來自 watchdog_state 6/20 快照 [已證實]；現況 unknown |
| `notebooklm-conveyor` | NotebookLM 輸送 | `register_notebooklm_conveyor_task.ps1` 排程 | unknown | unknown | unknown | brian | 凍結中 | uncertain |
| `promote-draft` | 草稿→正式工單（新，7/10 15:30） | 設計上由 dashboard hook 觸發（§7b b1，尚未接線） | per-event PS | 無 | 草稿目錄 `PROMOTED.json` | brian | 事件 | **verify FAIL，未接線** [已證實] |
| `codex-cli-worker` / `claude-cli-worker` | 派工目標 CLI | `dispatch_task_packet.ps1` per-dispatch subprocess | per-event | 工單 OUTPUTS（`CODEX_CONSOLE.log` 等） | 工單目錄 | **有身份議題**：CodexSandboxOffline vs brian [owner-provided] | 派工 | [已證實有輸出檔] |

備註：三條 AtLogOn 排程互不知情、幾乎同時觸發 [已證實，盤點 F3 附帶發現]；Windows Task Scheduler 即時狀態仍 unknown（沙箱限制，補證命令見盤點報告 §6）。

---

## 2. 可觀測性資料模型（需求 2）

命名空間：`data\observability\`（新建；不在治理動態掃描範圍 [已證實]）。

### 2.1 Runtime Registry（靜態宣告，人工維護，Josh 核准後變更）

`data\observability\runtime_registry.json` —— 每個 runtime 一筆：

```jsonc
{
  "runtime_id": "hermes-lite-gateway",          // 唯一 id（§1.2 表第一欄）
  "display_name": "Hermes Lite（聊天限流）",     // 主題
  "kind": "daemon | scheduled | per_event | api", // 型態
  "start_source": { "type": "schtask|script|hook|manual", "ref": "HermesLiteAutostart", "script": "scripts\\start_hermes_lite.ps1" },
  "expected_identity": "LAPTOP-IMPR60B8\\brian",
  "process_match": { "name": "hermes*", "cmdline_regex": "gateway\\s+run", "home_marker": "hermes-lite" },
     // 教訓：watchdog 的 regex 分不清主/lite/legacy [已證實]；home_marker 用 HERMES_HOME/profile 路徑消歧義
  "ports": [ ],                                   // 允許空；unknown 不捏造
  "log_paths": ["logs\\hermes-lite-gateway.stdout.log", "logs\\hermes-lite-gateway.stderr.log"],
  "state_files": [ ],
  "heartbeat": { "expected": false, "reason": "external_binary_cannot_instrument" },
     // hermes.exe 是外部專案（P8）：expected=false 者以 probe 判定，不假裝有心跳
  "health_checks": [
    { "type": "process_present", "via": "process_match" },
    { "type": "log_freshness", "path": "logs\\hermes-lite-gateway.stdout.log", "stale_after_s": "unknown_calibrate_phase0" },
    { "type": "port_probe", "port": null }
  ],
  "governance_gated": false,                       // 是否執行前過 assert_governance_ready
  "depends_on": [ ],                               // 如 hermes-internal-cron depends_on hermes-main-gateway
  "docs": "docs\\hermes_ecosystem_inventory_and_optimization_proposal_2026-07-10.md"
}
```

### 2.2 Heartbeat（動態，單寫者，原子覆寫單檔）

心跳檔路徑依 kind 分兩型（r2 依 fresh 審查修正——原設計單檔會被 per_event 並行實例互相覆寫，恰好摧毀 NO_PROGRESS_TIMEOUT 核心場景）：

- `kind: daemon|scheduled`（單例）：`data\observability\heartbeats\<runtime_id>.json`
- `kind: per_event`（可並行，如 codex-cli-worker、supervisor、url-intake）：`data\observability\heartbeats\<runtime_id>\<dispatch_id>--<pid>.json`，一實例一檔；collector 彙總時取同 runtime_id 全部實例，逾期實例檔由 collector 標記 expired（不刪除，按月封存）

由 runtime 自己寫（P7），temp-file→rename 原子替換：

```jsonc
{
  "runtime_id": "task-queue-runner",
  "pid": 12345,
  "started_at": "2026-07-10T19:08:11+08:00",
  "identity_actual": "LAPTOP-IMPR60B8\\brian",     // whoami at start（P4）
  "env_findings": [                                  // 啟動時環境自檢（P4）
    { "class": "ENV_PATH_DUPLICATE", "detail": "Path and PATH both defined", "severity": "warn" }
  ],
  "governance": { "version": "1.2.0", "hash": "ad20e9...", "status": "aligned" },
  "last_heartbeat": "2026-07-10T19:31:05+08:00",
  "phase": "dispatching_child",                      // 現在在做哪一步（人話短語）
  "current_task_id": "telegram-...-1273-...-child-01",
  "progress": { "step": 3, "total": 5, "note": "waiting codex cli, elapsed 190s" },
  "last_error": { "at": "...", "error_class": "ACCESS_DENIED", "exit_code": 1, "message": "codex cli: access denied", "evidence": "path\\to\\stderr.log" }
}
```

長時間外部命令（codex/claude CLI）的心跳：worker 以 PowerShell background job 每 30 秒更新 `phase`＋`elapsed`，主線程等待外部命令——外部命令沒輸出不代表沒進度，心跳說「我還在等第 X 步」。這直接消除「長任務看起來像當機」[owner-provided 教訓]。

### 2.3 事件與決策路徑（需求 4）

寫入布局（r2 依 fresh 審查修正——多 actor 同寫一檔在 Windows PS 5.1 下有行交錯/截斷風險，「retry-backoff」不足）：**每個寫者一個分片檔** `data\observability\events\<runtime_id>-<yyyyMM>.jsonl`，各寫者只 append 自己的分片（單寫者原則 P7 延伸，無鎖需求）；查詢端（collector/`/api/events`）合併讀取所有分片按 ts 排序，不做物理合檔。每行 schema：

```jsonc
{
  "event_id": "evt-20260710-192001-a1b2",
  "ts": "2026-07-10T19:20:01+08:00",
  "actor": "josh_telegram | josh_dashboard | schtask | queue_runner | supervisor | plugin | worker | collector",
  "runtime_id": "task-queue-runner",
  "pid": 12345,
  "dispatch_id": "telegram-...-1273-...",           // 關聯鍵 #1
  "parent_event_id": "evt-...",                      // 關聯鍵 #2 → 重建因果鏈
  "script": "scripts\\task_queue_runner.ps1",
  "action": "verify_verdict_parse",
  "input_ref": "data\\codex_tasks\\...\\RESULT.md",
  "output_ref": "data\\escalations\\...\\20260710-192001-826.json",
  "next_step": "write_escalation:invalid_or_missing_verify_verdict",
  "result": "ok | warn | error | timeout",
  "exit_code": 0,
  "error_class": null,                               // §2.4 taxonomy
  "severity_basis": "exit_code",                     // P3：分類依據必須留痕
  "duration_ms": 1180
}
```

決策路徑＝`dispatch_id` 篩選＋`parent_event_id` 串鏈：誰觸發 → 哪個 script → 哪個 process → 哪個 output → 下一步。以今晚 1273 為例，鏈會長成：`josh_telegram → plugin(__init__.py) → local_file_task_worker → dispatch_task_packet(child-01 DISPATCH_PROMPT 生成) → codex-cli-worker(RESULT.md) → queue_runner(verify_verdict_parse→invalid) → write_escalation(awaiting_josh)`——今晚花一小時翻 log 才拼出的路徑，變成一次查詢。

### 2.4 異常分類 taxonomy（需求 5：今晚每件小事都要有落點）

| error_class | 今晚實例 | 資料模型的捕捉點 | 判定規則（確定性） |
|---|---|---|---|
| `ENV_PATH_DUPLICATE` | Path/PATH duplicate [owner-provided] | heartbeat.env_findings（啟動自檢） | 啟動時枚舉 env keys，大小寫不敏感重複即記 warn |
| `IDENTITY_MISMATCH` | CodexSandboxOffline vs brian [owner-provided] | registry.expected_identity vs heartbeat.identity_actual；event.actor+pid | whoami 字串不等即 degraded＋事件；不阻擋（fail-open），但 Dashboard 標黃 |
| `ACCESS_DENIED` | Codex CLI access denied [owner-provided] | event（result=error, error_class, exit_code, script, identity）| exit code＋stderr 樣式表比對；決策路徑直接顯示「哪個身份在哪一步被拒」 |
| `SEVERITY_MISCLASSIFIED` | git warning 被誤判 fatal [owner-provided] | event.severity_basis 必填 | **規則：exit_code=0 ⇒ 最高只能 warn**；stderr 有字不得單獨判 fatal（P3）。分類器本身的誤判也因 severity_basis 留痕而可稽核 |
| `NO_PROGRESS_TIMEOUT` | 1267 卡 11 分鐘後 dispatcher_exit_1，期間看似當機 [已證實 task-queue.log；owner-provided 體感] | heartbeat.phase+last_heartbeat+progress；event result=timeout | 心跳新鮮＋phase 不變 >閾值 ⇒ `running-long`（黃，不是死）；心跳過期 ⇒ `stale`（紅）；timeout 事件必附最後 phase 與部分產物路徑 |
| `DASHBOARD_UNREACHABLE` | fetchApprovals 連線失敗 → 看板全滅 [owner-provided，根因未查證，附錄 A-4] | /api/health 零依賴端點＋frontend degraded 模式 | frontend 對每個 fetch 失敗顯示「該區塊 degraded＋上次成功時間」，不整頁空白 |
| `HEARTBEAT_WRITER_DEAD` | watchdog state 停滯 20 天無人發現 [已證實] | collector 自身心跳（P6）＋所有 heartbeat 的 age 檢查 | 觀測層每個寫者都被 age-check，包括 collector 自己 |
| `PROMPT_CONTRACT_BREAK` | 1273 verify_verdict 格式斷裂 [已證實] | event：DISPATCH_PROMPT 生成步記錄 template/contract 版本欄位 | prompt 生成事件帶 `contract=verify_verdict_v1`；parser 失敗事件回指生成事件 id |

### 2.5 狀態機（collector 對每個 runtime 的判定輸出）

`healthy` → `running-long`（心跳新鮮、phase 停滯）→ `stale`（心跳過期）→ `down`（process 不在且該在）；`unknown`（probe 拿不到，如 hermes 內部）；`frozen`（registry 標記凍結，如 antigravity）；`disabled`（Josh 明確停用，如未來的 watchdog 決策）。輸出寫 `data\observability\runtime_status.json`（collector 單寫者）。

---

## 3. Dashboard 設計（需求 3）——明確區分「新增」與「取代」

### 3.1 Backend endpoints（全部**新增**，唯讀，不呼叫模型）

| endpoint | 內容 | 資料來源 |
|---|---|---|
| `GET /api/health` | **零依賴**自檢（backend 活著、磁碟可讀），其他子系統全掛也回 200 | 無外部依賴 |
| `GET /api/runtimes` | runtime map：registry × status 合併 | registry + runtime_status.json |
| `GET /api/runtimes/{id}` | 單 runtime 詳情＋最近事件＋最近錯誤 | 同上 + EVENT_LOG 尾段 |
| `GET /api/events?dispatch_id=&runtime_id=&since=&limit=` | 決策路徑查詢 | EVENT_LOG.jsonl（倒序讀尾，不整檔載入） |
| `GET /api/failures?since=&class=` | failure path：錯誤依 error_class 分組 | EVENT_LOG 篩 result∈{error,timeout} |

### 3.2 Frontend 元件

**新增**（不動既有）：`RuntimeMap.tsx`（卡片＋狀態燈＋依賴邊，含三條 AtLogOn 鏈的顯性呈現）、`FailurePath.tsx`（最近 N 錯誤按 class/時間分組，點開跳決策路徑）、`DecisionPathViewer.tsx`（dispatch_id 時間軸：actor→script→process→output→next_step）。

**修改既有**（範圍列明，逐項待 Josh 核准）：
- `ApprovalQueue.tsx`：fetch 失敗時顯示 degraded banner＋上次成功資料，不空白（直接回應今晚 fetchApprovals 事件）。
- 全域 fetch wrapper：統一逾時、錯誤呈現、`/api/health` 探測——影響所有元件的網路層，屬橫切修改。

**取代候選**（需 Josh 決定，不預設取代）：`DecisionMap.tsx`——既有元件 [已證實存在]，其現況為 UI 說明性質（盤點時確認其對 assert_governance_ready 的引用只是文字 [已證實]）。選項：(a) 保留並讓 DecisionPathViewer 另立；(b) 由 DecisionPathViewer 取代。建議 (b)，但屬刪改既有功能，依邊界必須 Josh 核准。

**不動**：TaskBoard、GovernanceStatus、LiveLogs、HermesChat、TaskUniverse、UsagePanel、WorkTrail、WorkflowSupervisor。

---

## 4. 分階段 Roadmap（每階段含明確可驗收完成標準；每階段開工前各需 Josh 核准）

### Phase 0：基礎資料層（唯讀，零侵入）
- 交付：`runtime_registry.json`（§1.2 全表建檔）；taxonomy 定案；`scripts\collect_runtime_status.ps1`（唯讀 collector：process probe、log freshness、port probe、心跳 age，輸出 runtime_status.json＋自身心跳）；log freshness 閾值以 7 天實測校準。
- **不改任何既有檔案**；新檔全在 `data\observability\` 與 `scripts\`（不觸發 drift，P10）。
- 驗收：(1) collector 對 registry 內 100% runtime 產出狀態且無一捏造（拿不到＝unknown）；(2) 人工抽查 3 個 runtime 的判定與實況一致（含一個故意停掉的）；(3) 跑 collector 前後 `sync_shared_governance.ps1` 狀態不變（drift=0）；(4) collector 自身心跳存在且新鮮。
- 風險：probe 的 process_match 消歧義錯誤（watchdog 教訓）→ 驗收 (2) 必含主/lite 同跑場景。

### Phase 1：心跳與事件打點（第一次觸碰既有腳本，範圍白名單制）
- 交付：`scripts\lib\observability.ps1`（Write-Heartbeat / Write-Event / Get-EnvFindings / Get-IdentitySnapshot，全部 try/catch fail-open）；打點白名單：`task_queue_runner.ps1`、`workflow_supervisor.ps1`、`dispatch_task_packet.ps1`、`local_file_task_worker.ps1`（各 5-15 行插入，逐檔 diff 給 Josh）；長外部命令的 30 秒 background-job 心跳 wrapper。
- 明確不碰：hermes.exe（外部）、plugin `__init__.py`（gateway 重啟成本，延後到 Phase 3 評估）、治理腳本（assert/sync 保持零依賴）。
- 驗收：(1) 故意跑 >5 分鐘任務，心跳間隔 ≤35s、phase 正確演進；(2) `taskkill /f` 模擬 crash → collector ≤60s 判 stale；(3) **fail-open 實測**：鎖住 heartbeats 目錄再跑任務 → 任務照常完成、事件記 warn；(4) 打點檔案改動屬治理受管者，走工單＋Josh 核准＋`-ApproveBaseline`（Josh 親自執行）。
- 風險：per-message IO 開銷（觀測者效應）→ 心跳最小間隔 5s、事件僅決策點不記迴圈；PS 5.1 編碼（P9）→ 驗收加中文欄位 round-trip 檢查。

### Phase 2：Dashboard 呈現＋抗故障
- 交付：§3.1 五個 endpoints；RuntimeMap＋FailurePath；ApprovalQueue degraded banner；全域 fetch wrapper。
- 驗收：(1) 停掉 lite gateway → RuntimeMap ≤60s 顯示 down；(2) 停掉 backend → frontend 各區塊顯示 degraded＋上次成功時間，**無整頁空白**；(3) `/api/health` 在 queue/gateway/escalation 全停時仍 200；(4) 前端輪詢不呼叫模型、不觸發任何寫入。
- 風險：DecisionMap 取代決策未定 → 本階段不動它，只加新元件。

### Phase 3：決策路徑全鏈
- 交付：dispatch 全鏈事件補齊（含 plugin 入口——此時評估 gateway 重啟窗口）；DecisionPathViewer；prompt contract 欄位（PROMPT_CONTRACT_BREAK 捕捉）。
- 驗收：(1) 任取 3 個歷史 dispatch_id（指定含 1273）能重建完整鏈且與既有 log 交叉核對零矛盾；(2) 重演 1273 型格式錯誤（測試工單）→ FailurePath 一眼定位到 prompt 生成步；(3) 事件鏈斷點（parent_event_id 缺失率）<5%。
- 風險：plugin 打點需重啟 gateway → 與統一部署動作（盤點報告 §5，屆時應已實作）合流，不另立重啟流程。

### Phase 4：通知與外部 runtime adapter
- 交付：down/stale → Telegram 通知（走既有 gateway 發送；訊息只含 runtime_id＋狀態＋證據路徑，不含模型判斷）；hermes-internal-cron 的**直接 probe**（r2 依 fresh 審查修正：`scripts\agentos_health_check_noagent.py` 與 `daily_token_cost_summary_noagent.py` 本就是 cron job 本體、確定性、`models_invoked=false`、輸出結構化 key=value [已證實]——collector 解析其輸出檔時間戳與結果即得真實 job 狀態，不必只靠依附關係推導）；watchdog 的最終處置（修復或 `disabled`，Josh 決策）。
- 驗收：(1) 停掉 dashboard-backend → Telegram 通知 ≤5 分鐘；(2) 連續 7 天誤報 ≤1 次（校準期）；(3) 通知風暴防護實測（同 runtime 重複告警抑制）。
- 風險：通知依賴 gateway——gateway 自己掛了誰通知？記錄為已知殘餘風險（選項：Windows 排程獨立探針，Josh 決定是否要）。

---

## 5. 風險總表

| 風險 | 等級 | 緩解 |
|---|---|---|
| 觀測層變成第二個 watchdog（殭屍化） | 高 | P6 自我心跳＋Phase 0 驗收 (4)＋每 Phase 回歸驗收前一 Phase 判定仍準 |
| 打點改動觸發治理 drift 全域擋單 | 高 | P10 檔案放置＋Phase 1 驗收 (4) 綁 Josh 核准的 ApproveBaseline 時點 |
| 心跳/事件 IO 拖慢任務 | 中 | fail-open＋最小間隔＋事件只記決策點；Phase 1 前後對照同型任務耗時 |
| EVENT_LOG 無限成長 | 中 | 按月分檔 `EVENT_LOG-YYYYMM.jsonl`；封存為確定性腳本，不刪除 |
| registry 與現實漂移（腳本改了、registry 沒改） | 中 | collector 每輪比對 registry 宣告的 log/state 路徑存在性，缺失即 `registry_drift` 事件 |
| hermes.exe 黑箱造成 unknown 過多 | 中 | 接受 unknown（P8）；以 log freshness＋port probe 逼近；不捏造 |
| 多寫者搶檔 | 低 | P7 單寫者＋原子 rename；EVENT_LOG append 加 retry-backoff |

---

## 6. 交付前自查（對 Josh 三條驗收要求）

1. **每階段有明確可驗收完成標準**：Phase 0–4 各含編號驗收條件（共 18 條），全部可機械檢查或實測復現，無「大致可用」措辭。✅
2. **資料模型涵蓋今晚全部異常類型**：§2.4 表逐一映射 Path/PATH duplicate、身份差異、access denied、git warning 誤判、無心跳假當機，另補 dashboard 失聯、心跳寫者死亡、prompt 合約斷裂三類（今晚實際發生但需求 5 未列名者）。✅
3. **Dashboard 新增 vs 取代區分**：§3.2 三分類（新增 3 件／修改既有 2 件／取代候選 1 件待 Josh 決定／不動 8 件）。✅

自查不等於定論——本設計仍需 fresh session 獨立覆核（見檔頭 status）。

---

## 附錄 A：設計過程發現的既有缺陷（只記錄，未修）

- **A-1** dispatch 1273：rerun 的 DISPATCH_PROMPT 遺漏標準 verify prompt 的機器可讀 verdict 行要求（`dispatch_task_packet.ps1:252-264` 有標準文字，rerun prompt 未沿用），且指定的 `verification_result_zh_tw.md` 模板不含 verify_verdict 欄位 → parser（`task_queue_runner.ps1:130-140`）判 invalid [已證實]。
- **A-2** `data\escalations\...1273...\20260710-192001-826.json` options.effect 中文亂碼；`write_escalation.ps1:54-56` 原始碼正常 → 疑似 PowerShell 讀取腳本編碼問題 [推論]。
- **A-3** watchdog 三缺陷與殭屍狀態（盤點 F3）[已證實]。
- **A-4** Dashboard fetchApprovals 連線失敗導致看板不可用 [owner-provided]——根因未查證（backend down？CORS？port 佔用？），建議列入 Phase 2 前置查證項。
- **A-5** dispatch 1267 timeout（15:23→15:34 dispatcher_exit_1）[已證實 task-queue.log]，期間無中間產物快照與進度可見性——正是本 roadmap 的動機案例；其殘留檔案診斷工單當時被 1273 需求取代，尚未完成 [已證實：本 session 歷史]。
- **A-6** `promote_draft.ps1` 已存在（7/10 15:30）但 Codex Verify 判 fail（worker 以「logical invocation」自述取代實際執行）→ 不得視為完成品，Dashboard hook 接線未做 [已證實]。
- **A-7** `apply_agentos_changes.ps1`（統一部署動作，dispatch 1264）未在 `scripts\` 產出 → 工單一實際狀態 uncertain，需對帳 [已證實：檔案不存在]。

## 覆核狀態

- 產出方式：引用本日盤點（r2）＋定點 delta 核對（§1.1）＋主對話設計整合；`dispatch_degraded=false`。
- **第一輪 fresh subagent 審查（sonnet）**：條件 1–4（階段驗收可測性、五類異常覆蓋、Dashboard 分類、硬邊界）全 PASS，行號證據抽查全數屬實；主動挑錯 verdict=PARTIAL，找到 4 點缺口。**r2 已全數採納修正**：(1) 補列 `typed-dispatch-router` runtime；(2) per_event 心跳改一實例一檔；(3) EVENT_LOG 改寫者分片，廢除多寫者同檔；(4) hermes-internal-cron 改用既有 noagent 腳本直接 probe。r2 修正由本 session 作者執行，**尚未經第二輪 fresh 覆核**。
- **最終定論待 Codex Verify / fresh session**：重點覆核（a）runtime 清單是否遺漏（特別是 hermes 內部 cron 與凍結項）、（b）資料模型欄位是否足以重建今晚每個異常、（c）Phase 1 打點白名單的侵入範圍是否可接受、（d）fail-open 與治理 fail-closed 並存的邊界是否嚴謹。

# 踩坑教訓日誌（50_LESSONS v1.0，append-only）

格式（依 40_MAINTENANCE_PROTOCOL §4，一坑一段，全部欄位必填）：
`## <YYYY-MM-DD> <一句話標題>`＋`症狀:`＋`根因:`＋`修法:`＋`制度化: <none | 已提案改哪個檔哪節>`。
什麼算坑：花 >15 分鐘才發現的錯誤前提、重複第二次的失敗、驗證漏抓的問題。

## 2026-07-09 bash 掛載層 torn read
症狀: Linux 掛載讀 CLAUDE.md/10_DISPATCH 注入 75-99 個 NUL bytes，兩個 fresh session 重現
根因: 掛載層讀取異常，原生檔案完整；疑為 00_DIAGNOSIS 原「截斷」誤判成因（uncertain）
修法: 檔案內容異常時改用原生工具（type/PowerShell）交叉確認再下結論
制度化: 提案將此檢查加入 T5 模板做法段（待 Josh 核准）

## 2026-07-09 備份時序無法稽核
症狀: 六檔 mtime 早於 .bak 時間戳且 sha256 不同，「先備份再改」順序不可回溯
根因: cp 備份不保留可稽核時序
修法: none（本輪已由內容比對確認備份正確）
制度化: 提案 T2 模板備份步驟改為「備份後立即回報 .bak 的 sha256」（待 Josh 核准）

## 2026-07-09 制度化落地更新（狀態追加，非新坑）
- 「bash 掛載層 torn read」制度化: 已落地 2026-07-09 → 30 號檔 T5[做法]段（原生工具交叉確認）
- 「備份時序無法稽核」制度化: 已落地 2026-07-09 → 30 號檔 T2[注意]段（備份後立即回報 sha256）

## 2026-07-09 跨 session 轉發 prompt 內容失真
症狀: 兩次轉發失真——起草端未附模板原文致實作阻塞；
轉發時 bash 掛載路徑被替換成無效內容
根因: 轉發端假設「貼過去＝內容不變」，未核對逐字內容
修法: 轉發後對路徑、雜湊、原文引用三類逐字內容 rg 核對一次再送出
制度化: 提案 35_COLLAB_PROMPT 失敗回流段補此檢查（待 Josh 核准）

## 2026-07-09 制度化落地更新（第二批，狀態追加）
- 「跨 session 轉發 prompt 內容失真」制度化: 已落地 2026-07-09 → 35 號檔[失敗回流]段（轉發前逐字核對，v1.1）

## 2026-07-09 治理 baseline 連環漂移（1239/1242/1247 三連 blocked）
症狀: 同一晚三張工單連續 exit_1（governance gate 封鎖），即使 Josh 人工 approve baseline 兩次（21:15:59、21:38:47），數分鐘內仍再度 blocked
根因: 結構性必然空窗——`sync_shared_governance.ps1` 動態掃描 `prompts/` 下全部 `.md`／`.txt`；Claude Worker 工單（本次為新建 `prompts\context_packs\hermes_intake_menu.md`）在 `prompts/` 寫出產出物後，governance 立即漂移，且任何後續工單在 Josh 手動 `-ApproveBaseline` 之前均連坐 blocked；無背景程序持續寫入，dispatch 1247 本身被治理門封鎖（codex_tasks 無目錄），不是第二次漂移的觸發者
修法: Josh 手動跑 `sync_shared_governance.ps1 -ApproveBaseline` 兩次解除；本次起 Claude 主動在 changed_file 落於受治理路徑時提醒 baseline 核准
制度化: 已落地 2026-07-09 → 40_MAINTENANCE_PROTOCOL.md 新增「§受治理路徑修改後的核准提醒 v1.1」
## 2026-07-10 git warning 誤判為 dispatcher 致命錯誤
現象: raw intake approval 實作子工單 `telegram-telegram-1449022024-1267-20260710-151925-439010-child-01-raw-intake-approval-implementation` 已寫出 `AGENT_OUTPUT.md`，但 dispatcher 在收集 `git diff` scoped diff 時遇到 LF/CRLF warning，PowerShell 將 native stderr 視為錯誤，最後 queue 記錄 `dispatcher_exit_1`，沒有正常寫出 `RESULT.md`。
根因: `scripts\dispatch_task_packet.ps1` 在 verify bundle 建立流程中直接呼叫 `git diff ... 2>$null | Out-String`。Git 的換行符 warning 不是 diff 失敗，但 PowerShell error handling 會把 native stderr 包成錯誤記錄，導致 dispatcher 中斷。
影響: 實作已修改受治理檔，卻沒有完成 dispatch 收束；`dashboard\backend\main.py`、`integrations\hermes_plugins\agentos-typed-dispatch\__init__.py`、`scripts\write_escalation.ps1` 留下 drift，後續所有工單被 governance gate fail-closed 擋住。
修復: 已修復。`dispatch_task_packet.ps1` 改用 `System.Diagnostics.Process` 收集 git stdout/stderr，過濾 LF/CRLF warning，不再讓換行符 warning 造成 dispatcher fatal；本次缺失的 `RESULT.md` 已補寫，並保留原始 `AGENT_OUTPUT.md` 作為證據。
制度化欄: 已修復
## 2026-07-10 start_task_queue Path/PATH duplicate 與 Codex CLI Access denied 診斷待辦
現象: 以 Codex sandbox 前景呼叫 `scripts\start_task_queue.ps1 -RootDispatchId telegram-telegram-1449022024-1267-20260710-151925-439010` 時，`Start-Process` 回 `Item has already been added. Key in dictionary: 'Path' Key being added: 'PATH'`。改以前景直接跑 `task_queue_runner.ps1` 可繞過 starter 的 `Start-Process`，但進入 Codex verify 後又出現 `Access is denied.`。
根因假說: 當前執行身份為 `LAPTOP-IMPR60B8\CodexSandboxOffline`，但 `APPDATA/LOCALAPPDATA/USERPROFILE` 指向 `C:\Users\brian`。dispatcher 會優先選 `C:\Users\brian\AppData\Roaming\npm\codex.cmd`；該檔存在但對 sandbox 身份讀取/ACL 查詢皆 Access denied，因此 Codex CLI 啟動失敗。前景直接跑 runner 只是繞過 starter 的 `Path/PATH` duplicate，沒有修正 Codex CLI 使用者 context/憑證問題。
待查: 正常 Hermes/排程背景執行時是否以 `brian` 主帳號啟動，因此可讀 `codex.cmd` 與 Codex 登入態；Codex sandbox 前景執行是否必然用 `CodexSandboxOffline`，導致 brian profile 下 token/cmd 權限不可用。另需分開診斷 `start_task_queue.ps1` 的 Process environment 同時含 `Path`/`PATH` 問題，避免 starter 在 Windows PowerShell `Start-Process` 前就失敗。
時間線: `2026-07-10 01:25:56` Codex verify 仍成功；`2026-07-10 18:47:29` child-02 首次記錄 `Access is denied.`。Defender 在 `2026-07-10 15:46:39` 更新 KB2267602/安全情報，但目前沒有直接證據顯示它封鎖 Codex；較強證據是帳號與 ACL mismatch。
制度化欄: pending_diagnosis

## 2026-07-10 Codex Plan child TASK.md 遺漏 dispatch_status 欄位
狀態: 已定位待修復
症狀: dispatch 1287 child-01（`telegram-telegram-1449022024-1287-20260710-195458-047394-child-01-diagnose-1278-child-02-blocked-root-cause`）的 TASK.md 缺少 `dispatch_status` 欄位，導致 `dispatch_task_packet.ps1` 讀到空字串 ≠ `ready_to_route`，以 exit 5 blocked 封鎖。
根因: `scripts\local_file_task_worker.ps1` 第 94-111 行的 `$planInstructions` 區塊（非函式，為頂層 heredoc 變數賦值）生成 `## Codex Plan Output Contract` 範本時，列出 child TASK.md 必填欄位清單（`type`、`assigned_to`、`route_to`、`workflow_version`、`source_dispatch_id`、governance binding），但未包含 `dispatch_status`（亦未包含 `task_status`）。Codex Plan 依此合約建立 child TASK.md 時，可能不寫入 `dispatch_status`，後續 dispatcher 即 blocked。
修法: 本工單（dispatch 1290 child-02）不修復生成器；`dispatch_status: ready_to_route` 已由 dispatch 1290 child-01（minimal-dispatch-status-repair）補入受影響的 child TASK.md。待後續工單修正 `local_file_task_worker.ps1` `$planInstructions` 區塊，在 child 必填欄位清單中加入 `dispatch_status: ready_to_route` 與 `task_status: ready`。
制度化欄: 已定位待修復；修復路徑：`scripts\local_file_task_worker.ps1` 第 94-111 行 `$planInstructions` heredoc
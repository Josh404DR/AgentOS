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

## 2026-07-28 Revision bundle 的 change_required 疑似時序 race
症狀: `operational-drift-triage-revision-1` 的 RESULT.md 已明確寫 `changed_file:`/`change_required: true`，同一次讀取生成的 `VERIFY_BUNDLE.md` 卻寫 `change_required: false`，導致一輪不必要的 Verify FAIL。
根因: 未完全定位。Josh 用 `-Force` 重新生成 bundle 後 `change_required` 正確變為 `true`，排除是 regex/邏輯本身分岔（同一段程式碼、同一份檔案內容，兩次跑出不同結果）。懷疑是 bundle 生成當下讀到的 RESULT.md 內容早於 Claude Worker 完整寫入完成的時間點（builder 有一次因 OAuth token 過期的失敗 attempt，之後 bounded retry 才寫入真正內容）。
修法: 用 `-Force` 重新產生 bundle 即可修正；未追加程式碼層防呆。
制度化: 提案——`New-CodexVerifyTask`/`create_codex_verify_task.ps1` 的自動觸發時機，應確認讀到的 RESULT.md 是「這次 attempt 真正完成」的版本（例如比對檔案 mtime 與 attempt 完成時間），而非單純看 exit code。待 Josh 核准後排入 `create_codex_verify_task.ps1` 修改。

## 2026-07-28 Revision context 遺漏原票 TEST_RESULT.full.md
症狀: `operational-drift-triage-revision-1` 的 Verify bundle 只帶原票 TASK.md/RESULT.md 做「Original Ticket Context」，沒帶原票的 `TEST_RESULT.full.md`（實際 gate 證據所在），導致 Verifier 看不到補寫表格的數據來源。
根因: `create_codex_verify_task.ps1` 的 `$originalContextPaths` 組裝邏輯（約行 356-367）當初只加了 TASK.md 與 RESULT.md 兩個路徑，未考慮內容型 revision（修正對象是 RESULT.md 本身內容）需要原票的完整測試證據佐證。
修法: 已修復——優先納入原票 `TEST_RESULT.full.md`，缺少則 fallback `TEST_RESULT.md`。
制度化: 已落地 2026-07-28 → `create_codex_verify_task.ps1` 行 356-380。

## 2026-07-28 Codex 8 群摘要掩蓋了 13/22 路徑查無來源工單的事實
症狀: `operational-drift-triage` revision-1 第一版只交出「8 群摘要」（群名+數量，合計 22），未附逐路徑證據；獨立逐一比對後發現 22 個路徑中有 13 個在整個 `data\codex_tasks\` corpus 裡完全找不到任何工單宣稱動過，只有 1 個真正 hash 綁定驗證通過。
根因: 分群式摘要容易讓「數字加總對得上」掩蓋「逐項證據缺失」；AC 要求逐路徑表格正是為了防止這種聚合層級的假通過感。
修法: 用 subagent 重新逐路徑查證據，改寫 RESULT.md 為誠實的 22 列表格（含 no_dispatch_found 分類），不再套用先前的 8 群敘事。
制度化: 提案——任何要求「逐項」證據的驗收條件，Verify 端應明確檢查列數是否等於要求數量、且每列是否有可追溯佐證，而非接受「群組加總=總數」就視為滿足。待 Josh 核准後可考慮寫入 `10_DISPATCH_RULES.md` 或 Verify child 的 prompt 模板。

## 2026-07-28 第三種 Codex 自產 Verify 格式不滿足獨立驗證
症狀: 至少 3 張票（`global-jsonl-append-lock`、`dashboard-plane-naming-consistency`、`operational-drift-triage`）的 OUTPUTS 底下有一份 Codex 自己在同一 session 內產生的 `VERIFY_RESULT.md`，自稱「第 N 個全新 read-only Codex Verify session」判定 PASS，但證據路徑指回同一張票自己的 OUTPUTS，並非由 `create_codex_verify_task.ps1` 建立的獨立子工單。
根因: Codex 在 plan-mode session 內部會自行模擬多輪「獨立驗證」敘事，但這些輪次都發生在同一次模型呼叫/session 脈絡裡，不符合 AGENTS.md「驗證不自驗」要求的 fresh session 盲審。
決定: 2026-07-28 Josh 授權 Claude 自行決定——**不承認**此格式為滿足 AGENTS.md 驗證要求的證據；已知 3 張票一律須另外走標準 `create_codex_verify_task.ps1` pipeline 產生真正獨立的 `-codex-verify` 子工單，`dashboard-plane-naming-consistency` 已依此重新產生 bundle。
制度化: 待辦——`global-jsonl-append-lock` 尚未補跑；長期應在 Codex plan-mode 的 prompt 模板加一條明確禁止語（不得在同一 session 內自稱「獨立 Verify」），避免此格式再次出現。

## 2026-07-28 Git commit 邊界政策：Verify PASS 後即 commit
症狀: `scripts\task_queue_runner.ps1` 等共用檔案疊了多張票的未進版控變更，`git diff -- <path>` 天生分不出哪段屬於哪張票，造成 scoped diff 反覆被指控「範圍外變更」。
決定: 2026-07-28 Josh 授權 Claude 自行決定——採納「每張票 Verify PASS 後立即 commit 該票 changed_file 清單」為往後政策，降低下一張票 scoped diff 混入舊票變更的機率。
制度化: 尚未寫入正式流程腳本（例如讓 `task_queue_runner.ps1` 在記錄 PASS 後自動 `git add`+`commit` changed_file 清單）；目前僅為政策方向，具體自動化留待後續工單，且屬「會改變驗證/交付邊界」的變更，正式落地前建議再讓 Josh 過目一次自動 commit 的確切範圍與訊息格式。
# AgentOS 能力補齊計劃（2026-07-30）

依據：`docs\CAPABILITY_ASSESSMENT_2026-07-30.md`（實掃repo的五項能力分析）
目標：五項能力全達標——手機Telegram可完整指揮，系統自主跑、卡住會回報、知識與教訓能進工單。
原則：每階段獨立可用、獨立驗證（沿用Build→fresh Verify紀律）；優先走
headless queue自動鏈派工，不再走桌面板貼prompt。

## 總覽

| 階段 | 內容 | 開發量(estimate) | 對應缺口 | 前置 |
|---|---|---|---|---|
| P0 | 啟用F07手機核准 + 運行狀態確認 | 零開發，設定+驗證 | Q5一半 | 無 |
| P1 | 知識候選→工單草稿自動化 | 小（1張Build票） | Q1最後一哩 | 無 |
| P2 | 卡住回報迴路（推播+回話成票） | 中（1 Plan + 2-3 Build） | Q5另一半+Q6插件 | P0 |
| P3 | 學習候選閉環 + 分級自動核准 | 中，需Josh授權範圍 | Q2、Q3 | P2 |

## P0 — 啟用F07手機核准（先做，零開發）

1. Josh手動：設定Windows User-scope環境變數
   `AGENTOS_OWNER_TELEGRAM_ID=<你的Telegram user id>`，重啟Hermes
   Gateway（機制與F14相同，watchdog會hydrate）。
2. 開1張唯讀驗證票：確認agentos-typed-dispatch plugin實際已載入、
   `[待核准]`/`[確認]`指令端到端可用、非owner身分被拒。
   同時補掃hermes-agent側Telegram平台能力（上次評估的unknown區）。
3. 完成判準：手機發`[確認 <task_id> approve <code>]`能真的完成一筆
   escalation決策，AUDIT.jsonl有紀錄。

## P1 — 知識候選→工單草稿自動化

現況：candidate匯出止於`data\knowledge_candidates\*.json`
（`candidate_only`，明文不派工）。

改法：新增確定性腳本（或擴充`task_queue_runner`前端）監看
`knowledge_candidates\`，新candidate自動產生draft TASK.md進queue，
**但掛escalation gate**——你在Telegram收到「有新知識候選票，核准嗎」
才會真的執行。這樣兼顧自動化與你的最終控制權。

- 1張Build票 + fresh Verify。風險低（只產生draft，不自動執行）。
- 完成判準：Telegram丟一個URL→知識節點→候選→你手機核准→工單
  自動執行，全程不碰電腦。

## P2 — 卡住回報迴路（你要的節點圖插件本體）

現況：DispatchFlow前端有pause/resume/retry，但卡住不會主動通知；
escalation只能在Dashboard或（P0後）用確認碼回覆既有選項；你無法
用一句話直接糾正agent。

拆票（先開1張Plan票給Codex，比照F02模式）：
- B1：主動推播——workflow卡住（escalation產生、工單FAIL、queue
  停滯超過閾值）時，經gateway.send_message推Telegram，附當前狀態
  摘要與工單id。
- B2：回話成票——你回覆`[修正 <task_id>] <一句話指示>`，plugin把
  它轉成修正工單（revision ticket）進queue，走既有governance gate。
- B3：控制指令橋接——`[暫停/繼續/重試 <workflow_id>]`橋接到
  DispatchFlow既有的`controlWorkflow` API。
- 完成判準：模擬一次工單FAIL→手機收到通知→回一句修正→系統產生
  revision票並執行→手機收到完成通知。閉環全程離開電腦。

## P3 — 學習閉環與分級自動核准（需Josh授權邊界）

- 學習閉環：`collect_learning_candidates.ps1`偵測到的LC-*候選，
  比照P1自動產生draft修正票（現在只升級給你看）。
- 分級自動核准：定義白名單類型（例如唯讀調查票、artifact-only票）
  自動核准+事後Telegram報備；Risky清單維持100%人工。
  **這條需要你明確劃授權範圍才動工，AI不自行定義白名單。**

## 順帶收尾（不阻塞，任一階段空檔可做）

- F12：progress_log歸檔trim補一個單獨commit（機械性）。
- F13：`dashboard\backend\`納入git追蹤（根治patch工具不穩）。
- watchdog常駐自癒目前`enabled: false`，是否啟用留待P0驗證後決定。
- B5全域盲驗：F02鏈路已全PASS+commit，可做可不做。

## 風險與誠實揭露

- hermes-agent本體仍未掃描；P0的驗證票會補這塊。
- P2的B2「一句話成票」是新攻擊面（任何能傳訊給bot的人？）——
  設計上必須沿用F07的owner-only constant-time身分驗證，非owner
  訊息一律不產票。
- 所有開發量為estimate；P2實際拆幾張票以Plan票產出為準。

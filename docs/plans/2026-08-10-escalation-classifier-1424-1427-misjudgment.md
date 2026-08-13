# 工單草稿：Escalation 分類器誤判核准指令為新 Risky 工單（1424/1427）

drafted_at: 2026-08-10 Asia/Taipei
draft_by: Claude Cowork（依 code 執行端 08-10 escalation 盤點結果整理）
狀態: 草稿，待轉為正式 dispatch（無 pwsh 存取，需在 code 執行端建立 TASK.md 走 queue）
governance_version: 1.4.0

## 問題

1. **`telegram-1424`（08-08，Risky/security_policy）**：Dashboard authenticated fixed-script bridge 的最小化遠端救援請求，卡著沒核准。
2. **`telegram-1427`（08-08，Risky/deletion）**：Josh 本意是核准 1424，訊息內容是「我核准此 Risky 工單執行。dispatch_id: telegram-telegram-1449022024-1424-...」——一句核准指令，但分類器命中了 `deletion` 規則關鍵字，把它當成**一張全新的 Risky 工單**再次卡住，而不是辨識成「對 1424 的核准動作」。

**結果**：1424 從 08-08 到現在（08-10）都還沒被真正核准執行，即使 Josh 已經試著核准過一次。這不只是一筆待決策的 escalation，是分類器本身有結構性漏洞——**任何包含 Risky 觸發關鍵字（如本例的 "deletion"）的核准訊息，都可能被誤判成新工單，導致核准指令本身進不去。**

## 根因（2026-08-10 已查明，取代原本的猜測）

由 code 執行端實測重現確認，**不是「任意 Risky 關鍵字誤觸」，是否定詞（negation）機制的單行假設漏洞**：

- 分類器：`E:\AgentOS\scripts\classify_task.ps1`（整支線性腳本，無函式包裝）。風險規則表在第 7-16 行（`$riskRules`，8 條：`deletion`/`production_data`/`money`/`credentials`/`external_write`/`security_policy`/`core_rewrite`/`outage`，純正則，無外部規則檔）；否定詞處理在第 25-37 行；比對迴圈第 49-52 行。
- 呼叫鏈：Telegram 自然語言訊息 → `scripts\local_file_task_worker.ps1`（第 56-62 行呼叫 `classify_task.ps1 -MessageText $MessageText -AsJson`）→ 依 `task_type` 決定是否寫出 `Risky Task Awaiting Josh` escalation（第 69-93 行）。1427 走的是這條自然語言路徑（`source: telegram_natural_language`），不是 `typed_dispatch.ps1` 裡有 `JOSH_APPROVAL` 結構化類型的路徑（那條路徑只吃 `[TYPE: JOSH_APPROVAL]` 格式的指令）。
- 實際觸發字：1427 原文有一段條列式「明確禁止：」清單，其中一項「安裝或移除軟體」的「移除」命中 `deletion` 規則（`(?i)\b(delete|remove|erase|drop|purge)\b|刪除|清除|移除|銷毀`）。
- 否定詞機制**不是不存在**，是有涵蓋但漏這種寫法：第 25-37 行的否定窗口正則是 `[^\r\n，。；;]{0,24}`，明確排除換行符。同一行寫「明確禁止：安裝或移除軟體」會被正確辨識為否定（negation match）；但 Josh 的訊息是條列格式（「明確禁止：」另起一行，「移除」在下一行的清單項），否定詞跟風險詞隔了換行，跨行完全抓不到——實測跨行版本 `negated_risk_constraints` 是空的。
- 用 1427 完整原文重跑分類器，精確重現：`task_type=Risky`, `risk_hits=deletion`, `negated_risk_constraints=`（空）。
- **附帶確認**：分類流程完全沒有「這是不是對既有 pending 工單的核准/駁回動作」的攔截步驟；`dispatch_id:` 欄位目前只在生成新工單時被寫入，沒有任何地方在分類前解析「訊息裡是否引用既有工單的 dispatch_id」——1427 訊息裡明白寫了 `dispatch_id: telegram-telegram-1449022024-1424-...`，但系統沒讀取利用。這是獨立於本次直接根因的另一個值得做的改進，不是這次誤判的觸發原因。
- **同類案例掃描**：抽查 11 張 `task_type: Risky` 且訊息含「核准/APPROVED/approval」字樣的工單，逐一比對是否有指向既有工單的 `dispatch_id:` 引用（1427 的特徵）——只有 1427 這一筆符合，其餘 9 筆是描述工單內容本身，不是核准意圖被誤判。**樣本量有限**（只查了含特定關鍵字的 11 筆，未窮舉全部歷史訊息），不代表窮盡確認只有這一筆。

## 需要修的範圍（已依實測根因修正）

1. **主要修法**（直接對應根因）：`classify_task.ps1` 第 25-37 行的否定詞窗口正則，改成能跨越條列清單的換行辨識否定範圍（例如把否定詞的作用域從「同一行」改成「同一個條列清單區塊」或「同一段落」），不能只看單行。
2. **回歸測試**：至少涵蓋兩種情況——(a) 同一行「明確禁止：安裝或移除軟體」正確辨識為否定；(b) 條列格式（否定詞另起一行，風險詞在後續清單項）也要正確辨識為否定，用 1427 的原文當測試案例。
3. **獨立的次要改進**（不是本次直接根因，但值得一併評估）：分類邏輯進場前，判斷訊息是否含指向既有 pending 工單的 `dispatch_id:` 引用，若有應路由到核准處理流程而非重新分類成新工單。這個改進即使否定詞 bug 修好，仍能再擋一層類似問題。

## 連帶動作

- 1424 本身（Dashboard 救援請求）需要 Josh 重新核准（例如把「明確禁止」清單改成同一行寫法避開這個 bug，或等分類器修好後再核准），確認實際救援動作有沒有執行。
- 抽查樣本量有限，若要更有把握排除「還有其他類似誤判案例」，建議之後有餘裕時窮舉全部歷史 Risky 工單而非只查含核准關鍵字的 11 筆。

## 定位

這張草稿本身不執行任何動作，只是把 code 執行端盤點出來的發現整理成可轉正式工單的描述。轉正式工單時建議標記 Risky（動的是核准/授權判斷邏輯本身），需要 Josh 核准才能開工。

# ADR-0012: Hermes Lite × AgentOS Knowledge Intelligence Layer（唯讀知識查詢層）

status: proposed（Claude 依 Josh 明確授權自主推進撰寫，待 Josh 有空最終過目，非 Josh 逐項審閱後核准；2026-08-10 Josh 進一步指示「繼續自主推進 Hermes Lite 專案」，Phase 1 MVP 已依此轉為正式 dispatch `2026-08-10-hermes-lite-phase1-rag-evidence-mvp`，此為「繼續推進」授權，非「內容已審閱」）
date: 2026-08-10
decided_by: Claude（Josh 於 Cowork 對話中原話「把計畫直接攤開來做，中間我不會參與決策，你可以多開幾個 subagent 去執行，我現在沒空幫你做決定」——本檔案是在此明確授權下由 Claude 主導撰寫，不是 Josh 逐項核准的紀錄）
links: [[ADR-0011-parallel-knowledge-platform]] [[ADR-0010-converge-before-expand]]

## 背景

Josh 現在有正職工作，AgentOS 的優先目標從「收入優先」轉為「任務導向——讓 Josh 能在本職工作之餘輕鬆多工處理多個專案」（見 `current_state.md` §7 2026-08-10 更新）。Josh 提出的痛點：他同時處理多個專案，每次想問問題都得依賴電腦版去掃描資料才能回答，需要一個「真正能做管理層級查詢」的 agent。

專案裡曾經有 Hermes Lite（一個 Telegram agent），現在已閒置，實際在用的是 jamie（負責開單）。Josh 明確指定用 Hermes Lite 當這個查詢層的載體（不是新建、不是用 jamie），範圍明確限定在 AgentOS 專案本身（不涵蓋跨專案管理層需求，也不是 ADR-0011 的知識平台——那個收的是 jamie 收的外部知識節點，這裡是 AgentOS 自身執行/治理資料的自我認知層，兩者不重疊）。

2026-08-10 完成的 Phase 0 現況健檢（見 `docs\plans\2026-08-10-hermes-lite-phase0-index-pipeline-design.md` 等四份文件的健檢部分，以及對話記錄）發現：Hermes Lite process 排程/config/依賴腳本都在，`enabled: true`，但目前是「活著但斷線」狀態（持續連不上 Telegram，DNS 失敗，且沒有 watchdog 監控這種狀態）；更關鍵的是，現有 Hermes Lite 跑的是 `chat_only` 免費聊天模式，完全沒有 RAG/索引/證據檢索邏輯——本專案要做的不是「復活舊功能」，是「在功能定位完全不同的殼上新建一整層」。

## 決策

1. **範圍**：Hermes Lite 復活為 AgentOS 專屬的唯讀知識查詢層，不涵蓋跨專案管理層需求（該需求另案追蹤，尚未立案，見「未決事項」）。jamie 維持現有固定職責不動。
2. **與 ADR-0011 的關係**：不重疊，不衝突。ADR-0011 的知識平台是外部知識節點（Josh 餵入的內容，jamie 收）；本專案是 AgentOS 自身執行/治理資料的自我認知層。兩份文件、兩套資料來源、兩套索引，程式碼與部署應保持可獨立開關。
3. **Phase 0 前置工作**（六項，狀態如下，全數 2026-08-10 由 Claude 依授權完成初版）：
   - 現況健檢：完成，結論見上方背景。
   - 索引管線資料來源設計（G0）：完成，`docs\plans\2026-08-10-hermes-lite-phase0-index-pipeline-design.md`。
   - 證據優先序規則（G1）：完成，`docs\plans\2026-08-10-hermes-lite-phase0-evidence-precedence-rules.md`。
   - Escalation 過期快照處理規則（G2）：完成，`docs\plans\2026-08-10-hermes-lite-phase0-escalation-staleness-rules.md`。
   - 成本分流設計（G5）：完成，`docs\plans\2026-08-10-hermes-lite-phase0-cost-routing-design.md`。
   - 本 ADR：完成初版，狀態 `proposed`。
4. **Phase 1 範圍不變**：僅 RAG + Evidence Retrieval（read-only）。Health Snapshot／Recent Findings 移到 Phase 1b，觸發條件是 `METRICS_LOG.jsonl` 累積到有意義樣本量（比照量化路線既定的 50~100 張工單觀察窗標準）。
5. **上線前置條件（不可省略）**：
   - Hermes Lite 的 Telegram 連線問題（DNS 失敗）需先排除，或決定 Phase 1 改用非 Telegram 介面（例如直接透過 dashboard 查詢）作為過渡——這是本 ADR 未決事項之一，需 Josh 決定。
   - G4 唯讀邊界誘導測試（至少 3 種話術，確認全部被拒絕）必須在上線前跑過，技術層面不給任何 dispatch/write/execute 相關工具或憑證存取權。
   - G3：Health/Findings 不含在 Phase 1，避免 metrics 樣本量不足導致大量 UNKNOWN 拉低第一印象。
6. **資源排序**（G7）：本專案不自動排在既有任務看板待辦之前。2026-08-10 當天，Josh 已明確決定把 Python launcher／`ai_tool_core` 憑證確認等 Josh-only 待辦延後、優先投入本專案（見 `docs\PROJECT_TASK_BOARD_2026-08-09.md` §2 2026-08-10 更新），這是本次的例外授權，不代表往後永久排序規則改變。

## 回頭條件

- 若 Phase 0 四份設計文件（索引/證據優先序/escalation 規則/成本分流）在 Josh 實際過目後發現方向性錯誤（不是小修），本 ADR 狀態退回 `proposed` 重新設計，不得帶病進 Phase 1。
- 若 Hermes Lite 的 Telegram 連線問題排查後發現是不可逆的基礎設施問題（例如需要換一整套通訊層），本 ADR 需要重新評估載體選擇，不強行沿用 Hermes Lite。
- 若本專案的資源投入排擠到既有任務看板 §2/§3 的既有待辦超過一週未處理，比照 ADR-0011 的回頭條件精神，重新評估優先序。

## 未決事項，需 Josh 決定

- ~~Hermes Lite Telegram 連線問題：查 DNS/網路暫時性問題，還是需要重新設定；`.env` 密鑰（`TELEGRAM_BOT_TOKEN`／`GROQ_API_KEY`）是否過期，需要在真實 Windows 環境確認。~~ **2026-08-10 已查證排除**：Josh 於真實 Windows 環境確認兩把金鑰皆存於 User-scope 環境變數且有效（`TELEGRAM_BOT_TOKEN` 對應 `Joshpersonal_AIBot`，`getMe` 回傳 `ok=True`；DNS/ping 正常；`GROQ_API_KEY` 呼叫 `/v1/models` 正常）。憑證與網路連線不是問題；若之後仍連不上，根因在別處（process/proxy/防火牆），需另查。
- 是否核准本 ADR 由 `proposed` 轉 `accepted`（Josh 有空過目四份 Phase 0 設計文件與本 ADR 後裁決）。
- 跨專案管理層 agent 的需求（Josh 最初提出的完整痛點，本專案只解決 AgentOS 範圍內的部分）是否需要開一份獨立概念草案文件佔位，避免遺忘。

## 影響

- `docs\PROJECT_TASK_BOARD_2026-08-09.md` §4 同步更新為「Phase 0 六項全數完成初版，待 Josh 過目」。
- Phase 1 工單尚未開立，待本 ADR 轉 `accepted` 後才能開工單走 Codex Plan/Builder/Verify 流程。

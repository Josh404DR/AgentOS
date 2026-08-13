# Hermes Lite × AgentOS Knowledge Intelligence Layer — 執行計畫 v0.1

updated_at: 2026-08-09 Asia/Taipei
狀態: 草案，待 Josh 核准後轉正式工單
來源: `提案書 v0.1`（AI 撰寫，Josh 指定 Hermes Lite 為載體）+ Claude Cowork 風險逆向分析
governance_version: 1.4.0

## 0. 範圍確認（已與 Josh 對齊）

- 載體：Hermes Lite（復活，非新建）。jamie 維持現有固定職責（開單），因限制多不動它。
- 範圍：AgentOS 專屬，不涵蓋跨專案管理層需求（該需求另案追蹤，見 `PROJECT_TASK_BOARD` 第4節新增項）。
- 與 ADR-0011 的關係：不重疊。ADR-0011 的知識工作平台是 jamie 收的外部知識節點（Josh 餵入的內容）；本專案是 AgentOS 自身執行/治理資料的自我認知層。**文件與程式碼註解都要明講這句話**，避免以後被誤判成重複建設。
- 第一階段性質：Read-only MVP，不做 Phase 5（ACT）。

## 1. 風險管線（Risk Pipeline）

不是附錄，是執行順序本身的一部分——每個風險對應一個「不過這關就不准進下一階段」的 gate。

| Gate | 風險 | 通過條件 | 對應階段 |
|---|---|---|---|
| G0 | 索引管線依賴 git tracking，會漏掉今天才排除進 git 的 `data\codex_tasks\` 新工單 | 索引管線明確直接掃檔案系統路徑，不判斷 git 追蹤狀態；用一張新建立、未 commit 的測試工單驗證能被索引到 | Phase 0 前置 |
| G1 | 同一工單資料夾內 TASK/RESULT/TEST_RESULT/VERIFY_BUNDLE/VERIFY_RESULT 互相矛盾，RAG 選錯份會自信答錯 | 明確定義並實作「哪份文件蓋過哪份」優先序（比照 AGENTS.md §1 精神：VERIFY_RESULT > TEST_RESULT > RESULT 的 verified 欄位 > RESULT 其他欄位），並用今天早上真實踩過的案例（`learning-candidate-dedupe-fix-20260721`）當回歸測試，斷言正確回答「已驗證通過」 | Phase 0 前置 |
| G2 | ESCALATION_INDEX.jsonl 是 append-only 快照，直接查會得到過期的 awaiting_josh 假警報 | Evidence Retrieval 對 escalation 類查詢，必須先查對應資料夾是否已有 RESOLUTION.json，不能只信 index 的 status 欄位；用今天的真實案例（72% 假警報）當回歸測試 | Phase 0 前置 |
| G3 | Health/Findings 建立在目前僅 71 筆、多數 unknown 的 METRICS_LOG 上，回答會大量 UNKNOWN，第一印象差 | Phase 1 MVP **不含** Health Snapshot／New Findings；先出 RAG + Evidence Retrieval 兩項，Health/Findings 移到 Phase 1b，觸發條件見 §3 | Phase 1 範圍切分 |
| G4 | 唯讀邊界只是 prompt 指示，長期會被順手要求做點什麼而破功 | 技術層面完全不給 Hermes Lite 任何 dispatch/write/execute 相關工具或憑證存取權，不能只靠角色描述限制；上線前由 fresh session 測試「誘導它執行動作」至少 3 種話術，確認全部被拒絕 | Phase 1 上線前驗收 |
| G5 | 隨問隨答模式可能複製 Gemini 全職窗口燒錢的舊模式 | 明確定義「便宜確定性查詢」（結構化欄位查詢、狀態查詢）與「需要模型推理」（開放式問題、跨工單關聯分析）的分流規則，前者不呼叫大模型；上線後第一週追蹤 token 用量，超出預估門檻即停用複查 | Phase 0 設計 + Phase 1 上線後第一週 |
| G6 | Hermes Lite 閒置已久，復活可能有自己的排程/憑證/依賴 bit-rot（類比今天發現的 watchdog、dashboard frontend） | Phase 0 先做「Hermes Lite 現況健檢」，比照今天對 watchdog 的查法（排程來源、log 活動時間、config 是否 enabled），列出需要修復的項目，不假設「重新啟用很簡單」 | Phase 0 第一步 |
| G7 | 建置排擠既有待辦（任務看板上 35 筆真未結 escalation、Python launcher、~46 支核心角色檔案） | 本專案的資源投入不得無條件排在既有待辦之前；每次要投入新的一批工時前，先確認任務看板第2/3節沒有更高優先的卡住項目，或明確取得 Josh 核准優先順序調整 | 貫穿全程 |
| G8 | 「Google AgentOS」的期望值設定過高，v0.1 大概率答不出這個水準，用兩次覺得不如預期就棄用 | 對外（對 Josh 自己）溝通一律用「有限能力的 MVP，答不出來會誠實說 UNKNOWN」的框架，不用行銷語言；驗收標準明訂「誠實答 UNKNOWN 也算通過」，不是「一定要有答案」 | Phase 1 上線溝通 |

## 2. Phase 0：前置（動工前必須先做，非可選）

1. ~~**Hermes Lite 現況健檢**（對應 G6）~~ **完成（2026-08-10）**：
   - 排程：`HermesLiteAutostart`（AtLogOn+30s）已註冊，`enabled: true`，可直接用。
   - 狀態：**不是關閉，是活著但斷線**——process 昨天(08-09 15:21)啟動，今天(08-10 09:06)還在寫 log，但持續連不上 `api.telegram.org`(DNS 失敗，反覆重試)，functionally 等於沒在運作，且**沒有 watchdog 監控這種「活著但斷線」的狀態**，全靠人工翻 log 才發現。
   - 依賴：repo 內的腳本/plugin 齊全（今天有真的被 import 過的痕跡）；repo 外的本體(`E:\AI_Projects_Hub\External_AI_Agents\hermes-agent`)與 `.env` 密鑰查不到，unknown，需要 Josh 或能碰真實 Windows 檔案系統的 session 確認。
   - 跟 jamie：完全獨立（jamie 是 Antigravity CLI 帳號別名，不是 Telegram bot），放心。跟 Hermes 主 gateway：共用同一份 `hermes.exe`/程式碼，只是 profile home 不同——**之後要加 RAG 功能等於在改主 gateway 也在用的程式碼**，設計階段要注意別動到主 gateway。
   - **關鍵結論**：現有 Hermes Lite 是 `chat_only` 免費聊天模式，完全沒有 RAG/索引/證據檢索邏輯。整體工作量判定為**需要一定程度重建，不是小修就能用**——復活連線是小修（查 DNS），但「唯讀知識查詢層」本身是在一個功能定位完全不同的殼上新建一整層。
2. ~~**索引管線資料來源設計**（對應 G0）~~ **完成（2026-08-10）**：`docs\plans\2026-08-10-hermes-lite-phase0-index-pipeline-design.md`
3. ~~**證據優先序規則**（對應 G1）~~ **完成（2026-08-10）**：`docs\plans\2026-08-10-hermes-lite-phase0-evidence-precedence-rules.md`
4. ~~**Escalation 過期快照處理規則**（對應 G2）~~ **完成（2026-08-10）**：`docs\plans\2026-08-10-hermes-lite-phase0-escalation-staleness-rules.md`
5. ~~**成本分流設計**（對應 G5）~~ **完成（2026-08-10）**：`docs\plans\2026-08-10-hermes-lite-phase0-cost-routing-design.md`
6. ~~**正式 ADR**~~ **完成初版（2026-08-10）**：`docs\decisions\ADR-0012-hermes-lite-knowledge-layer.md`，狀態 `proposed`，待 Josh 過目後轉 `accepted`

**Phase 0 驗收**：六項全部有書面產出（2026-08-10，Josh 明確授權 Claude 自主推進、未逐項參與決策撰寫）。**Josh 尚未實際過目內容**，正式轉 Phase 1 開工單前建議至少瀏覽 ADR-0012 的「決策」與「未決事項」兩節，尤其是 Hermes Lite Telegram 連線問題（DNS 失敗，需 Josh 在真實 Windows 環境確認）這個上線前置條件。

## 3. Phase 1：MVP（RAG + Evidence Retrieval，read-only）

**範圍**：僅提案書 §14 的①②項（AgentOS RAG、Evidence Retrieval）。③Health Snapshot、④Recent Findings 移到 Phase 1b。

**Phase 1b 觸發條件**：`METRICS_LOG.jsonl` 累積到有意義的樣本量（建議比照 current_state.md §7 量化路線既定的「50~100 張工單觀察窗」標準，不另訂新門檻），且 token/duration 欄位 unknown 比例明顯下降，才啟動 Health Snapshot／Findings 開發。

**驗收**（依提案書 §15 改）：10 題測試問題全部要能回答，但「誠實答 UNKNOWN 並附理由」視為 PASS，不是只有「答對」才算 PASS；答對的部分需附可追溯的 evidence 路徑；額外加考 G1/G2 的兩個回歸測試案例。

**上線前**：跑 G4 的唯讀邊界誘導測試，全部通過才算完成。

## 4. 排序與資源

本專案不自動排在任務看板既有待辦之前。啟動 Phase 0 前，先確認 `docs\PROJECT_TASK_BOARD_2026-08-09.md` 第2節（Josh only）與第3節（可委派）沒有更高優先的卡住項目；若要插隊，需 Josh 明確核准並記錄理由。

## 5. 未決事項，需 Josh 決定後才能定案

- ADR-0012 是否核准建立。
- Phase 0 的 6 項前置工作，要現在排入任務看板當新的一批工單，還是先完成看板既有項目再開始。
- 跨專案管理層 agent 的需求，是否需要現在就開一份獨立的「概念草案」文件佔位，避免之後被遺忘（今天已經看過太多「診斷了但沒收尾」的案例）。

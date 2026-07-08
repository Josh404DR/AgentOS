# Hermes 點子庫 — 跨任務洞察與決策記錄

更新方式：附加寫入，不覆蓋，每筆記錄標註日期與來源。

---

## 2026-06-17
Source: Josh / prior AgentOS testing notes

### [測試結論] AgEnD 系統穩定性
- AgEnD 對長任務會靜默失敗（no-op），不留任何錯誤記錄。
- 短任務分段注入成功率明顯高於一次性長提示。
- 結論：目前不適合用 AgEnD 跑正式客戶任務，定位為受控沙盒實驗場。

### [測試結論] 提示詞才是穩定性的真正來源
- 三輪測試（含拿掉治理文件、拿掉身份背景）結果幾乎一致。
- 篩選準確度主要來自三條具體標準 + 強制階段化紀律格式。
- 結論：不需要依賴特定框架或治理文件，提示詞寫得夠具體就能穩定複製。

### [架構缺口] 現有正式系統三個最大洞
- Task Runner 後面缺執行器（只準備不執行）。
- Delivery Package 驗證是橡皮章（只查檔案存在不查內容）。
- SQLite 狀態跟 task_state.json 狀態用詞不一致，需人工對齊。

### [商業模式] 過程展示型免費試做平台
- 免費展示的是決策過程（為什麼選這個案子、踩了什麼坑）。
- 最終可部署的成果才是付費解鎖的部分。
- 不是刻意做殘缺版，是誠實分開「過程透明」與「成果交付」。
- 每次免費試做即使不成交，決策記錄都會累積進案例庫。

### [待驗證] 三個 agent 分工的交接機制
- 找案源 → 準備 → 執行三層之間，狀態交接格式還沒定案。
- 待確認：是靠檔案傳遞、資料庫欄位，還是靠 Hermes 中介觀察。

---

## 2026-06-23
Source: Hermes / Checkpoint 01-10 Stabilization Phase

### [測試結論] 三智體協議編碼邊界
- 在 Windows 環境下，繁體中文摘要 (ZH-TW) 的 Mojibake 問題極其頑固。
- 結論：強制實施「ASCII 為唯一事實來源 (Canonical)」，中文摘要僅作為選用顯示層且必須具備自動回退機制。

### [風險提醒] CLI 進程殘留
- 觀察到 Claude CLI 在自動化呼叫後可能留下多個 `claude.exe` 駐留進程（目前維持在 9 個）。
- 結論：在進入生產環境前，需驗證進程是否會無限增長，必要時需加入 `taskkill` 清理邏輯。

### [架構缺口] 日誌 Token 成本通膨
- `progress_log.md` 的 Append-only 模式導致上下文加載成本隨時間線性增長（目前已達 ~10,000 Tokens/次）。
- 下一步：需設計「Log Archival / Snapshot」機制，將過往細節歸檔，僅保留精簡狀態摘要作為我的主要記憶區。

### [已解決] 主動協作驗證流
- 成功測試「Hermes 匯報 → Codex 驗證 → 共同提交」的自動化協作閉環，減少了 Operator 手動介入的負擔。
- 結論：此模式應作為未來 AgentOS 內部維護任務的標準 SOP。

## 2026-06-23
Source: Josh (via Telegram)

### [決策結論] AgentOS 中央知識彙整架構
- 決策：Hermes (Gemini) 應作為多渠道輸入（Telegram/LINE）的統一彙整點。
- 邏輯：不論訊息來源，Hermes 負責識別、提取並將其結構化寫入 `HERMES_NOTES.md`。
- 意義：確保 `HERMES_NOTES.md` 成為 AgentOS 的唯一事實來源（Single Source of Truth），避免知識碎片化。
- 下一步：建立 `data/inbox/` 目錄，作為 LINE 等其他接口的落地區，由 Hermes 定時掃描並歸檔。

---

## 2026-06-23
Source: Codex / Hermes Telegram model routing update

### [RESOLVED] Telegram model switch aliases
- Updated the external Hermes gateway implementation so `/model status` reports the current active model instead of trying to switch to a model named `status`.
- Added built-in short aliases for common routing lanes:
  - `/model gemini` and `/model gemini-flash` -> Gemini Flash preview lane for normal coordination.
  - `/model gemini-pro` -> Gemini Pro lane for harder reasoning.
  - `/model gemini-lite` -> Gemini Flash Lite lane for cheaper/lightweight work.
  - `/model ollama`, `/model local`, `/model qwen8b`, `/model qwen-local` -> local Ollama `qwen3:8b` at `http://localhost:11434/v1`.
- `/model status` intentionally reports token/rate-limit fields as `not_available_in_gateway` or `not_reported_by_provider` when Hermes has no reliable counter.
- Verification: Codex ran the focused Hermes test set and got `6 passed`.

### [RISK] Model status must not overclaim quota data
- Hermes can switch models at the gateway/session layer, but it does not yet have a reliable cross-provider token usage and remaining-rate-limit counter.
- Until that counter exists, reports must distinguish active model state from quota state.

---

## 2026-07-05
Source: Josh / AgentOS governance alignment

### [治理更正] Source of Truth 邊界
- 本紀錄取代 2026-06-23 將 HERMES_NOTES.md 稱為唯一事實來源的舊說法。
- E:\AgentOS\AGENTS.md 是共同治理正本。
- current_state.md 保存目前狀態。
- data\memory\HERMES_NOTES.md 只保存歷史洞察與跨任務筆記，從屬 AGENTS.md，不得覆寫治理規則或即時證據。

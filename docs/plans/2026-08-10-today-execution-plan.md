# 2026-08-10 今日執行計畫

updated_at: 2026-08-10 Asia/Taipei
維護者: Claude Cowork
依據: `docs\PROJECT_TASK_BOARD_2026-08-09.md` §6「今日優先序」、`current_state.md` §7 2026-08-10 更新（任務導向新方向）
governance_version: 1.4.0

本文件把今日優先序拆成可直接執行的步驟。Josh-only 項目附具體指令；可委派項目附可直接貼給 code 執行端的派工說明。做完一項就回來這份文件打勾、記結果，不開新文件。

---

## 一、Josh-only（今天先做，成本低/損耗持續累積）

### 1. scc-ai-tool-core 5 筆 escalation 重試
- 現況：Codex 額度已於 08-08 12:06 PM 重置，但 5 個資料夾卡了超過 35 小時沒人重試，都還沒有 `RESOLUTION.json`。
- 動作：走 Telegram 或 dashboard 的 owner 驗證流程重試（純文字指令系統不會接受）。
- 完成標準：5 個資料夾各自產生 `RESOLUTION.json`，或明確記錄仍失敗的新根因。
- 做完後回報：哪幾個資料夾、結果如何，我來更新任務看板 §2。

### 2. `E:\ai_tool_core` OAuth 憑證外露確認
- 現況：08-07 稽核發現 `client_secret.json`／`token.json` 明碼存在，狀態未知是否已進版控或外流。這是另一個專案、涉及帳密，不能委派。
- 動作：
  1. 確認這兩個檔案是否曾被 `git add`/commit 過（`git log --all --full-history -- client_secret.json token.json`，在該專案目錄下執行）。
  2. 若曾進版控，需研判是否要 rotate 憑證（Google Cloud Console 重新產生 OAuth client secret）。
  3. 確認 `.gitignore` 現在有沒有排除這兩個檔案，沒有的話補上。
- 完成標準：明確結論「未外流/已外流」+ 已處理或待處理的具體動作。
- 做完後回報結果，我來記錄進任務看板。

### 3. Python launcher 修復
- 現況：`data\codex_tasks\2026-07-06-python-runtime-repair` 卡 `approval_required` 超過一個月，07-29 稽核確認仍是壞的（`py -3.13` 因 WindowsApps 路徑問題失敗）。
- 動作：在你的 Windows 環境跑：
  ```
  winget install -e --id Python.Python.3.13 --scope user
  ```
- 完成標準：跑完後開新終端機執行 `py -3.13 --version`，能正常回傳版本號。
- 做完後把終端機輸出貼回來，我核對驗收條件、關掉那張工單。

---

## 二、可委派給 code 執行端（今天可以同時派出去，不用等 Josh-only 做完）

以下每項都是獨立派工，彼此不互相依賴，可以同時開。派工時附上下方「派工重點」欄位內容即可，細節已在對應文件裡。

### 4. README.md Source of Truth 清單清理
- 派工重點：移除清單裡已標記 `planned-not-implemented` 的文件項目；硬編碼 `governance_status` 已在先前修過，這次只處理清單本身。
- 完成標準：README.md 更新後不再列出未實作文件；commit 訊息註明對應本執行計畫項次 4。

### 5. `docs\temp_routing_rules.txt` 歸檔
- 派工重點：這份檔案一個月前就標記待辦。移到 `docs\archive\`（或專案既有的歷史文件慣例位置），並在原路徑留一行指向新位置的說明（如果既有慣例是直接刪除+git history 保留，則按既有慣例做，不用另建 stub）。
- 完成標準：`docs\temp_routing_rules.txt` 不再以「待處理」狀態出現在 40_MAINTENANCE_PROTOCOL.md §3。

### 6. CI `pytest_dependency` 修復
- 現況：dashboard backend venv 沒裝 pytest，08-07 起多次全部 FAIL。
- 派工重點：在對應 venv 執行 `pip install pytest`（或按專案既有 requirements 管理方式補進 requirements 檔，不要只裝一次性解掉這次症狀）。
- 完成標準：下一次 CI 跑 `pytest_dependency` 不再全部 FAIL。

### 7. P-1：Verify isolation 機械化證明
- 背景：`50_LESSONS.md` 07-28 記錄 Codex 曾在同一 session 內自產假的「獨立 Verify」。Josh 已裁決此項可與其他工作並行，不必排在後面。
- 派工重點：證明四件事——Verify 必須獨立 dispatch 建立、有獨立 execution identity、原始 Worker 不能自產有效 PASS、RESULT 可追溯對應的 verify dispatch。要做成系統結構限制（例如 dispatch 建立機制本身檢查），不是 prompt 層規則。
- 完成標準：一份設計文件 + 至少一個可重現的反例測試（模擬 Worker 嘗試自產 Verify，系統應拒絕）。

### 8. P-3：歷史資料信任分類
- 背景：Self-Evolution v0.2 Phase -1 前提工作，獨立於該提案也有價值。
- 派工重點：對 RESULT/Retry/Escalation 歷史資料標記三類——已知污染區間（`learning-candidate` dedupe bug 07-19~07-21、`ci-queue-01-always-fail` 07-27 起）標 Excluded，無法確認標 Unknown，其餘標 Trusted。輸出格式建議：一個可查詢的分類索引檔（不是散在各處的註解）。
- 完成標準：分類索引檔涵蓋目前所有歷史記錄，且能被後續工具（含 Hermes Lite 的 Evidence Retrieval）引用。

### 9. Escalation 佇列 35 筆重新盤點
- 現況：08-09 即時查有 35 筆非測試污染、無 `RESOLUTION.json` 的項目（08-08 早上是 9 筆，一天內增加，疑似當天大量 commit/CI 活動產生）。
- 派工重點：比照任務看板 §7.2 的模式逐一分類根因，抓出真正需要 Josh 決策的項目 vs 可自動關閉的雜訊。工作量較大，排在項次 4-8 之後派工。
- 完成標準：35 筆全部有明確分類（需決策/可關閉/已解決但未同步索引），需決策的項目彙整成一份給 Josh 的清單。

---

## 三、今天不做（需要 Josh 先決定，不是執行問題）

### 10. Hermes Lite Phase 0 核准
- 這不是「今天做完」的項目，是「今天可以做的決定」：是否核准 `docs\plans\2026-08-09-hermes-lite-knowledge-layer-執行計畫.md` 的 Phase 0 六項前置工作 + 建立 ADR-0012。
- 如果核准，Phase 0 六項前置工作本身可以委派派工（不搶今天項次 4-9 的資源，等它們告一段落或有餘裕再排）。

### 11. ~46 支核心角色/治理檔案稽核
- 風險較高（動的是權限邊界定義），刻意不塞進今天，建議另開一輪，比照 08-08 那次「先看 diff、查工單、無工單先問」的流程。

---

## 四、驗收與收尾

每項做完後：
1. 回報結果（Josh-only 項目：貼實際輸出；委派項目：commit hash + 驗證方式）。
2. 我獨立核對（讀實際檔案/git log，不只信轉述），更新任務看板 §1（已完成）與對應項目狀態。
3. 若發現新的未結案問題，比照 close-the-loop 規則記錄，不要口頭帶過。

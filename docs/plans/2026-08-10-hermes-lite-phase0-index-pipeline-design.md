# Hermes Lite 知識查詢層 — 索引管線資料來源設計（Phase 0 前置 #2，對應 G0）

updated_at: 2026-08-10 Asia/Taipei
狀態: 草案，待 Josh 核准後併入 Phase 0 驗收清單
依據: `docs\plans\2026-08-09-hermes-lite-knowledge-layer-執行計畫.md` §1 G0、§2 第2項
governance_version: 1.4.0

## 0. 這份文件要解決什麼

G0 風險：如果索引管線用 `git ls-files` 或任何「判斷檔案是否被 git 追蹤」的邏輯來決定要不要索引某個檔案，2026-08-09 把 `data\codex_tasks\` 加進 `.gitignore` 之後，**所有新建立的工單資料夾都不會被索引到**（舊的 2379 個已追蹤檔案不受影響，但新工單從今天起全部進不去）。

結論先講：索引管線一律直接用檔案系統 API（`Get-ChildItem` / `os.walk` 等）掃描指定路徑，**完全不呼叫 `git`、不檢查 `.gitignore`、不判斷任何 git 追蹤狀態**。本文件的其餘部分是這條結論的具體規格。

現有可參考的正確先例：`scripts\rebuild_active_task_index.ps1` 已經是用 `Get-ChildItem -LiteralPath $TasksRoot -Directory` 直接掃檔案系統（第67-71行），沒有碰 git，索引管線應該延續同一模式，不要另創一套邏輯。

## 1. 要索引的資料來源清單（AgentOS 自身資料，不含 jamie 外部知識節點）

| # | 路徑 | 內容 | 索引單位 | 備註 |
|---|---|---|---|---|
| 1 | `data\codex_tasks\<task_id>\TASK.md` | 工單需求 | 每個 task_id 一份文件 | 含未 commit 的新工單 |
| 2 | `data\codex_tasks\<task_id>\PROMPT_FOR_CODEX.md` | 派工詳細指示（若存在） | 同上 | 非必存在 |
| 3 | `data\codex_tasks\<task_id>\STATUS.md` | 執行狀態（若存在） | 同上 | |
| 4 | `data\codex_tasks\<task_id>\OUTPUTS\RESULT.md` | 執行結果 | 同上 | |
| 5 | `data\codex_tasks\<task_id>\OUTPUTS\TEST_RESULT.md` | 測試結果 | 同上 | |
| 6 | `data\codex_tasks\<task_id>\OUTPUTS\VERIFY_BUNDLE.md` | 驗證包 | 同上 | |
| 7 | `data\codex_tasks\<task_id>\OUTPUTS\VERIFY_RESULT.md` | 驗證結果（優先序最高，見 G1 文件） | 同上 | |
| 8 | `data\codex_tasks\<task_id>\OUTPUTS\DELIVERY.md` | 交付說明（若存在） | 同上 | |
| 9 | `data\escalations\<escalation_id>\*.json` | escalation 原始事件 | 每個 escalation_id 一份 | 不含 `ESCALATION_INDEX.jsonl` 本身（G2 另有規則，見下） |
| 10 | `data\escalations\<escalation_id>\RESOLUTION.json` / `RESOLUTION-*.json` | 是否已解決的權威來源 | 同上 | G2 gate 依賴此檔存在與否，索引管線必須把它當一級欄位獨立標記，不能只當普通文字 |
| 11 | `data\escalations\<escalation_id>\DECISION-*.json` | Josh 決策記錄 | 同上 | |
| 12 | `data\learning_candidates\LC-*.json` | 學習候選案例 | 每檔一份 | |
| 13 | `data\metrics\METRICS_LOG.jsonl` | 量化指標（逐行 JSON） | 每行一份記錄 | G3：目前樣本少，先索引但不建 Health Snapshot 功能 |
| 14 | `docs\**\*.md`（含 `docs\decisions\ADR-*.md`） | 治理文件、ADR、計畫文件 | 每檔一份 | 排除 `docs\decisions\_layout.json` 等非文件性質檔案 |
| 15 | `current_state.md` | 現況快照 | 單一文件 | 更新頻繁，每次全文重索引（見 §3） |
| 16 | `AGENTS.md` | 正本治理文件 | 單一文件 | |
| 17 | `docs\PROJECT_TASK_BOARD_2026-08-09.md`（及未來同類看板檔） | 任務看板 | 單一文件 | 檔名含日期，索引管線需支援 glob（`docs\PROJECT_TASK_BOARD_*.md`）取最新一份，不寫死檔名 |

**明確排除**（不索引）：`data\dashboard_auth\**`（含密鑰）、`.env`／`*.env`、`archive\**`（除非之後有人明確要求檢索歷史存檔）、`AgentOS_export*.zip`、`logs\*.log`、`data\codex_tasks\**\OUTPUTS\CODEX_CONSOLE.log`（大量原始 console log，價值低成本高）。

## 2. 索引管線規格：直接掃檔案系統

### 2.1 硬性規則

1. **只用檔案系統 API**：`Get-ChildItem` / `Test-Path` / `os.walk` / `os.scandir`，或等效 API。**禁止**在索引管線程式碼中出現 `git ls-files`、`git status`、`git diff --name-only`，或任何解析 `.gitignore` 的邏輯。
2. **判斷「要不要索引某檔案」只看兩件事**：(a) 檔案路徑是否落在 §1 清單定義的來源路徑與副檔名規則內；(b) 是否命中 §1 的排除清單。**不看**這個檔案有沒有被 git 追蹤、有沒有被 `.gitignore` 排除。
3. 掃描路徑一律用 `E:\AgentOS\` 為根的絕對路徑（或執行環境對應的掛載路徑），不依賴目前工作目錄。

### 2.2 邊界情況處理

**(a) 新建立但尚未 commit 的工單**
- 直接 `Get-ChildItem -Directory data\codex_tasks` 拿到的資料夾清單，天然就包含未 commit 的新資料夾（檔案系統不知道也不管 git 狀態）。這是 G0 gate 本身要驗證的行為，見 §5 驗收測試。

**(b) 被 `.gitignore` 排除但實際存在的檔案**
- 同上，`.gitignore` 只影響 `git add`/`git status` 的行為，不影響檔案系統可見性。索引管線走檔案系統 API，天然不受影響。**唯一需要注意的是**：如果索引管線的執行環境是透過「先 `git clone`/`git checkout` 出一份乾淨副本再掃描」的方式取得檔案（例如 CI 拉一份新 checkout），那份副本會缺少未 commit 的檔案——**索引管線必須直接對 `E:\AgentOS` 工作目錄本身掃描，不能對著 git checkout 出來的副本掃**。這點要寫進部署設定，不能只在程式碼層面正確。

**(c) 正在被寫入中的檔案（避免讀到半寫入 JSON）**
- 規則：讀取 `.json` / `.jsonl` 檔案時，一律包在 try/parse 裡；parse 失敗時：
  1. 不拋錯中斷整個索引批次，記一筆 `index_skip`（含檔案路徑、錯誤訊息、當下 mtime），跳過該檔案本次索引。
  2. 下一輪增量索引（見 §3）會依 mtime 判斷該檔案已變動，重新嘗試讀取；如果檔案已經寫完，下一輪就會成功索引。
  3. 連續失敗超過 3 輪（預設，可調）才升級為需要人工看的警告，寫進索引管線自己的 log，不寫進知識庫本身。
- 對於「原子寫入」的來源（例如 `rebuild_active_task_index.ps1` 本身就是 temp file + `Move-Item` 的寫法），這類半寫入視窗極短，重試機制已足夠；不需要額外加檔案鎖。
- `.md` 文字檔沒有 parse 失敗的問題（純文字一定能讀），但仍建議讀取時捕捉 IO 例外（檔案被其他程序獨佔鎖定時的 `IOException`），同樣走「跳過+下一輪重試」邏輯，不中斷整批索引。

## 3. 增量索引 vs 全量重建

### 3.1 判斷依據：mtime，純確定性邏輯，不呼叫 LLM

- 索引狀態記錄檔（例如 `data\dashboard_index\hermes_index_state.json`，比照 `ACTIVE_TASK_INDEX.json` 的結構）對每個已索引檔案記錄：`path`、`mtime_utc_ticks`、`content_hash`（可選，SHA256，用於 mtime 因時鐘跳動失準時的保險）、`indexed_at`。
- 每次索引執行（無論排程觸發或手動觸發）：
  1. 對 §1 清單的每個來源路徑做 `Get-ChildItem`（含子目錄），取得目前檔案清單與各自 mtime。
  2. 與狀態記錄檔比對：
     - 檔案不在狀態記錄中 → **新增**，需要索引。
     - 檔案在狀態記錄中但 mtime 較新 → **變更**，需要重新索引。
     - 檔案在狀態記錄中但目前掃描不到 → **刪除**，從知識庫移除對應條目。
     - 其餘 → 跳過，不重新讀取內容。
  3. 只對「新增」與「變更」的檔案做內容讀取、分塊、embedding（或其他索引處理）；只對「刪除」的檔案做移除。
- 全量重建（忽略狀態記錄，全部重新索引）只在以下情況觸發：狀態記錄檔遺失或損毀、索引 schema 版本變更、人工明確要求（例如懷疑增量索引漏東西時的排查手段）。日常排程一律走增量。

### 3.2 成本控制

- 步驟 1（列檔案清單、比對 mtime）是純檔案系統操作，不讀取檔案內容、不呼叫任何模型，成本可忽略；`data\codex_tasks` 底下即使有數千個工單資料夾，`Get-ChildItem` 加 mtime 比對也是毫秒到秒級。
- 只有真正「新增或變更」的檔案才進入內容處理（讀檔、分塊、embedding）流程，這一步才有實質成本，但範圍已被 mtime 比對縮小到「這次真的變了什麼」。
- 索引管線本身（列清單、判斷增量、寫狀態記錄）**不得呼叫任何 LLM**；只有 embedding 產生（如果採用向量檢索方案）或後續的 RAG 問答才會用到模型，那是查詢時的成本，不是索引時的成本，兩者要在實作與監控上分開計算，避免和 G5 的成本分流設計混在一起看不清楚。
- 排程頻率建議：先用「每 N 分鐘跑一次增量索引」（N 待 Phase 1 實測調整，起始值建議 5-15 分鐘）或「Hermes Lite 收到查詢前先跑一次輕量增量索引」兩種模式擇一，不在本文件內定案，留給 Phase 1 實作時依實測延遲與資源狀況決定。

## 4. 索引管線與 git 狀態完全無關——這句話要出現在程式碼裡

實作時，索引管線的模組/腳本檔頭註解必須包含類似這段話（中英皆可）：

```
本索引管線直接掃描檔案系統路徑，不依賴、不查詢、不解析 git 追蹤狀態或 .gitignore。
判斷「是否索引某檔案」只看檔案是否落在設定的來源路徑清單且未被明確排除，與該檔案
是否被 git 追蹤、是否被 commit 無關。這是 2026-08-10 修正的已知風險（G0），變更此
行為前必須先讀 docs\plans\2026-08-10-hermes-lite-phase0-index-pipeline-design.md。
```

Code review checklist 加一條：索引管線的 PR/工單如果出現 `git ls-files`、`git status`、或讀取 `.gitignore` 內容的程式碼，一律視為違反 G0，退回重寫。

## 5. 驗收測試（G0 gate，Phase 0 完成前必須跑過且留存證據）

### 測試目的
證明「新建立、尚未 commit 的工單資料夾」能被索引管線索引到，不受 `.gitignore` 影響。

### 步驟

1. 在 `E:\AgentOS\data\codex_tasks\` 底下建立一個新資料夾，命名建議 `2026-08-10-g0-index-pipeline-smoke-test`（日期用實際執行當天，避免和真實工單撞名）。
2. 在該資料夾內建立最小可辨識內容的 `TASK.md`，內容包含一個容易搜尋的獨特字串，例如：
   ```
   # G0 索引管線煙霧測試

   dispatch_id: g0-index-pipeline-smoke-test-<執行時間戳>
   task_status: draft

   本工單僅用於驗證 Hermes Lite 索引管線能否索引到尚未 commit 的新工單資料夾（G0 gate）。
   驗證關鍵字：ZEBRA-G0-SMOKE-MARKER-<執行時間戳>
   ```
   關鍵字要包含時間戳，避免和之前跑過的測試混淆。
3. **確認此時檔案確實未被 git 追蹤**：執行 `git status --porcelain data\codex_tasks\2026-08-10-g0-index-pipeline-smoke-test`，預期看不到任何輸出（因為整個 `data\codex_tasks\` 已在 `.gitignore` 中，新資料夾應完全不出現在 git 的追蹤或未追蹤清單裡）；也可跑 `git check-ignore -v <路徑>` 確認命中 `.gitignore` 的規則，作為「這確實是會被 git 忽略的檔案」的證據。
4. 觸發一次索引管線的增量索引執行（依 Phase 1 實作後的實際觸發方式，例如手動跑索引腳本，或等排程週期）。
5. 向 Hermes Lite 查詢方式（Telegram 或直接呼叫 RAG 查詢介面均可）詢問一個會命中該關鍵字的問題，例如：「有沒有工單提到 ZEBRA-G0-SMOKE-MARKER-<執行時間戳>？」
6. 檢查索引狀態記錄檔（`data\dashboard_index\hermes_index_state.json` 或實際採用的路徑）裡是否出現這個新 `TASK.md` 的條目，作為不依賴問答介面的第二種獨立驗證方式。

### 預期結果（全部符合才算 PASS）

- 步驟 3 確認該檔案是 git 忽略/未追蹤狀態（排除「其實有被 git 追蹤所以才查得到」這個偽陽性）。
- 步驟 5 的查詢能正確找到並引用這份新工單，回答中附可追溯的檔案路徑（`data\codex_tasks\2026-08-10-g0-index-pipeline-smoke-test\TASK.md`）。
- 步驟 6 的索引狀態記錄檔裡有該檔案的條目，`indexed_at` 時間晚於檔案建立時間。
- 測試完成後，把這個測試資料夾保留（不刪除），作為之後 regression 用的固定 fixture；如果之後要清理，先把驗證結果記錄到 Phase 0 驗收文件，再視需要決定是否移除。

### 失敗時的處理

- 若步驟 5/6 找不到新工單：先檢查索引管線程式碼是否意外呼叫了 git 相關指令或誤讀了 `.gitignore`（回頭檢查 §4 的 checklist）；若程式碼確認沒有 git 依賴，再檢查是掃描路徑設定錯誤還是增量索引的 mtime 比對邏輯有 bug。
- 這個測試視為 Phase 0 → Phase 1 的硬性 gate，未通過不得宣稱 G0 已解決。

## 6. 與其他 Gate 的邊界

- 本文件只處理「索引管線掃到哪些檔案」（G0）。「同一工單內多份文件互相矛盾時聽誰的」是 G1，「escalation 快照過期」是 G2，兩者各自另有文件，不在此文件展開，但 §1 表格已標註 G1/G2 相關檔案（`VERIFY_RESULT.md`、`RESOLUTION.json`）在索引時需要獨立標記為一級欄位，供 G1/G2 的優先序邏輯使用。

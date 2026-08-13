updated_at: 2026-08-10 Asia/Taipei
狀態: 草案，待 Josh 核准（Phase 0 前置第4項，對應 G2）
來源：`docs\plans\2026-08-09-hermes-lite-knowledge-layer-執行計畫.md` §1 G2 + `dashboard\backend\main.py::_list_escalations()` 既有實作
governance_version: 1.4.0

# Hermes Lite Phase 0 — Escalation 過期快照處理規則（G2）

## 0. 這份文件要解決什麼

`ESCALATION_INDEX.jsonl` 是 **append-only** 快照：每次事件只會新增一行，舊行永遠不會被修改或刪除。這代表：

1. 同一個 `task_id` 可能在 index 裡出現多次（同一工單先被標記 `awaiting_josh`，後續被覆核、重試、或分類 metadata 補寫，都是新增一行，不是改舊行）。
2. index 裡一筆記錄的 `status` 欄位只反映「這行被寫入當下」的狀態，不反映「現在」的狀態。工單早就被 Josh 決策、或有其他方式解決之後，index 本身不會回頭更新那一行的 `status`。

今天（2026-08-10）這個 session 對現有 escalation 佇列做過一次盤點，發現大量標記 `status: awaiting_josh` 的項目，資料夾裡其實已經有 `RESOLUTION.json`——換句話說，**如果 Hermes Lite 對「還有哪些 escalation 在等 Josh 處理」這類查詢直接信 index 的 `status` 欄位，會產生大量假警報**。這份文件把當時盤點用的規則，轉寫成 Hermes Lite 查詢邏輯必須遵守的規範，並附一個可直接拿來當測試的回歸案例。

## 1. 既有解法：dashboard 後端 `_list_escalations()`

Dashboard 團隊在 `dashboard\backend\main.py` 的 `_list_escalations()`（約第1157行起）已經解決過同一個問題，且是「跑在真實資料上、Josh 每天在用」的程式碼，不是理論設計。Hermes Lite 的 Evidence Retrieval 對 escalation 類查詢**必須複用同一套判斷邏輯**（可以是直接 import/呼叫這支函式，也可以是獨立實作但邏輯要對齊——見 §5 的建議）。它的核心步驟：

1. **讀取 index 全文，reversed（由新到舊）走訪**，用一個 `seen` set 對 `task_id` 去重——只取每個 `task_id` 在 index 裡「最新出現的那一行」，忽略更早的重複行。
   - 理由：append-only，較新的行代表較新的狀態；只加總或只取第一筆都是錯的。
2. **對每個去重後的 `task_id`，去 `data\escalations\<safe_id>\` 資料夾找 `RESOLUTION.json`**（`safe_id` 是把 `task_id` 裡的非 `[A-Za-z0-9_.\-]` 字元換成 `-` 後的資料夾名稱）。
   - 有 `RESOLUTION.json` 且內容有效 → 這筆 escalation 已經有人工/系統紀錄的解決方案，不是「還在等 Josh」。
   - 但注意：程式碼裡有一段特別處理——如果 `resolution_type` 是 `owner_decision` 或 `verified_owner_decision` 但不是通過 `DECISION-*.json` + 簽章驗證出來的（見下一步），視為「非證據等級」的舊式/model-authored 紀錄，**仍然顯示為 awaiting_josh**，不能直接信任 `RESOLUTION.json` 檔案本身寫了什麼。
3. **同資料夾找 `DECISION-*.json`（依檔名排序取最新），驗證簽章**（`AUTH.verify_escalation_decision_record`），並比對 `DECISION-*.json` 裡的 `escalation_created_at` 是否等於 index 該行的 `created_at`——**這一步必須用解析後的時間物件比較，不能用字串直接比對**（見 §2 的踩坑記錄）。比對相符才代表這份決策記錄綁定的就是這一筆 escalation 事件，可以拿來覆蓋 index 的 `status`。
4. 也會讀 `ESCALATION_INDEX_CLASSIFICATION.jsonl`（另一個 append-only 分類索引）取得 `environment`（`ci`/`runtime`）與 `is_fixture` 標記；`is_fixture` 判斷優先序：index 本行自帶的 `is_fixture` 欄位（若為 bool）> 分類索引裡的紀錄 > 預設用 `environment == "ci"` 推斷。
5. 最終回傳的每筆結果，同時保留 `status`（判斷後的顯示狀態）與 `index_status`（index 原始欄位），方便追溯，不覆蓋原始資料。

## 2. 已知踩坑：時間戳記字串比對 bug（今天修復）

`_list_escalations()` 裡原本有一行用字串 `!=` 直接比對 `escalation_created_at` 和 index 的 `created_at`。這兩個時間戳記語意上是同一個瞬間，但**格式不同**：

- index 寫入的 `created_at` 常常沒有小數秒（例：`2026-07-26T16:49:26+08:00`）。
- `DECISION-*.json` 的 `escalation_created_at` 是 PowerShell/.NET 產生，帶 7 位小數秒即 100 奈秒精度（例：`2026-07-26T16:49:26.0000000+08:00`）。

原本的字串比對永遠判定「不相等」，導致一份已驗證的決策紀錄永遠無法對應回它所要解決的 escalation 事件——實質上讓「已解決」的判斷邏輯失效，任何走這條路徑的案例都會被誤判成仍在等 Josh。

**修復方式**：新增 `_normalize_iso_fraction()` 把小數秒補齊/截斷成6位（microseconds），再用 `datetime.fromisoformat()` 解析成時間物件比較（`_same_instant()`，約第1137行）。若任一值缺失或解析失敗，fail closed（回傳不相等），不會靜默判定為相符。

**寫入這份文件的規則**：Hermes Lite 未來若要實作任何「比對兩個時間戳記是否代表同一事件」的邏輯（不限於 escalation），**一律先解析成時間物件（datetime / 等價型別）再比較，禁止對 ISO 時間戳記字串做直接 `==`/`!=` 比較**。這是今天真實發生過、且已經在 production 程式碼裡修好的教訓，不是假設性風險。

## 3. Hermes Lite 對 escalation 類查詢的具體處理規則

Evidence Retrieval 模組收到「escalation 狀態」相關查詢時（例：「還有哪些工單在等 Josh 決策？」「XXX 這個 escalation 現在是什麼狀態？」），必須依下列順序處理，禁止跳過任何一步直接讀 index 的 `status` 欄位當答案：

### 3.1 資料來源

- 主索引：`data\escalations\ESCALATION_INDEX.jsonl`（append-only）。
- 分類索引：`data\escalations\ESCALATION_INDEX_CLASSIFICATION.jsonl`（append-only，補充 `environment` / `is_fixture`）。
- 每筆 escalation 的實體資料夾：`data\escalations\<safe_id>\`，其中 `safe_id` = `task_id` 經 `re.sub(r"[^A-Za-z0-9_.\-]+", "-", task_id)` 轉換。

### 3.2 去重規則（同一 task_id 多筆記錄）

- 讀 `ESCALATION_INDEX.jsonl` 全文，**由檔案尾端往前（reversed）逐行走訪**。
- 用 `task_id` 當 key 去重：第一次遇到某個 `task_id`（也就是它在檔案中最靠後、時間上最新的一筆）才保留，之後再遇到同一 `task_id` 一律跳過。
- **禁止**：正序走訪取第一筆；對同一 `task_id` 的多筆記錄做任何形式的加總、平均、或合併欄位。

### 3.3 現況判斷規則（是否真的還 awaiting_josh）

對去重後留下的每一筆記錄，依序檢查：

1. 到 `data\escalations\<safe_id>\` 找 `RESOLUTION.json`。不存在 → 暫定「未解決」，進第2步做最終判斷前的例外檢查。存在 → 讀取內容。
2. 若 `RESOLUTION.json` 存在但 `resolution_type` 屬於 `owner_decision` / `verified_owner_decision`，**不得直接信任**，必須進一步在同資料夾找 `DECISION-*.json`（若有多筆，取檔名排序後最新一筆），並：
   - 驗證簽章/來源可信（若 Hermes Lite 無法存取簽章驗證邏輯，至少要確認 `DECISION-*.json` 存在且可解析；無法驗證簽章時，查詢結果必須誠實標註「解決狀態未經簽章驗證」而不是直接當成已解決）。
   - 比對 `DECISION-*.json` 的 `escalation_created_at` 與 index 該行的 `created_at` 是否為**同一時間瞬間**（解析成時間物件比較，見 §2；禁止字串比對）。不相符 → 這份決策記錄不屬於這一筆事件，視為未解決。
3. 判斷結果：
   - 有相符且可信的解決紀錄（`RESOLUTION.json` 非 owner_decision 類，或有相符驗證過的 `DECISION-*.json`）→ 回答「已解決」，並附上證據路徑（`RESOLUTION.json` 或 `DECISION-*.json` 的實際檔案路徑）。
   - 沒有 → 回答「仍在等 Josh 處理」，並附上 index 裡的 `created_at` / `reason` / `source` 供追溯。
   - 查不清楚（檔案存在但解析失敗、簽章無法驗證等）→ 誠實回答 UNKNOWN，不得猜測，依 G8 的「誠實答 UNKNOWN 也算通過」原則。

### 3.4 Fixture / 測試污染資料排除

- 判斷 `is_fixture`（優先序，與 `_list_escalations()` 一致）：
  1. index 本行自帶 `is_fixture` 欄位若為 bool，直接採用。
  2. 否則查分類索引 `ESCALATION_INDEX_CLASSIFICATION.jsonl` 裡對應 `task_id` 的紀錄。
  3. 都沒有 → 用 `environment == "ci"` 推斷（`environment` 欄位同樣先看本行、再看分類索引，預設 `runtime`）。
- **凡 `is_fixture == true` 的記錄，一律排除在「有多少 escalation 在等 Josh」這類統計/列舉類查詢之外**，除非使用者明確要求「包含測試資料」或「fixture」。
- 若使用者查詢的就是某個特定 fixture task_id，仍要回答，但答案裡要明確標註「這是 fixture/測試資料，非真實案例」，避免使用者誤以為是真實 escalation。

### 3.5 禁止事項

- 禁止只讀 index 最後一行判斷某 task_id 現況（必須全檔 reversed 去重）。
- 禁止把 index 的 `status` 欄位當作最終答案，未先查 `RESOLUTION.json`/`DECISION-*.json`。
- 禁止用字串比對兩個 ISO 時間戳記來判斷是否為同一事件。
- 禁止把 `is_fixture` 資料計入「真實待處理」的統計類回答。

## 4. 回歸測試案例（基準：今天的真實假警報現象）

不需要精確重現今天盤點時的統計數字（例如具體百分比），但要能重現「index 說 awaiting_josh、實際已解決」這個現象本身，並斷言 Hermes Lite 給出正確答案。

### 4.1 測試 fixture 設計

在測試環境（非正式 `data\escalations\`，用隔離的測試資料夾或 mock 掛載）建立：

```
data/escalations/ESCALATION_INDEX.jsonl 追加一行：
{"task_id":"2026-08-10-regression-stale-index-demo","source":"simple_fail","reason":"test_stale_status","artifact_path":".../20260810-120000-000.json","created_at":"2026-08-10T12:00:00.0000000+08:00","status":"awaiting_josh"}

data/escalations/2026-08-10-regression-stale-index-demo/RESOLUTION.json：
{
    "task_id": "2026-08-10-regression-stale-index-demo",
    "resolution_type": "josh_decision",
    "decision": "approve",
    "resolved_at": "2026-08-10T13:00:00+08:00",
    "resolved_by": "Josh",
    "summary": "Regression fixture: resolved via Dashboard, index never rewritten.",
    "evidence": [],
    "josh_action_required": false,
    "recommended_status": "resolved"
}
```

（`resolution_type` 刻意選 `josh_decision`，不是 `owner_decision`/`verified_owner_decision`，這樣不會觸發 §3.3 步驟2 的「需要 DECISION-*.json 簽章驗證」分支，測的是最基本的「index 過期、RESOLUTION.json 才是真相」路徑；若要同時涵蓋簽章驗證路徑，需額外一組帶 `DECISION-*.json` 且 `escalation_created_at` 用不同小數秒精度寫入的 fixture，專門回歸測 §2 的時間比對 bug。）

### 4.2 斷言

- 查詢「`2026-08-10-regression-stale-index-demo` 現在是什麼狀態？」
  - **必須**回答「已解決」（或等義措辭），**不得**回答「仍在等 Josh 處理」。
  - 答案必須附上證據路徑（指向 `RESOLUTION.json` 的實際檔案路徑）。
- 查詢「還有哪些 escalation 在等 Josh 處理？」
  - 回傳清單裡**不得**出現 `2026-08-10-regression-stale-index-demo`。

### 4.3 時間戳記比對 bug 專用回歸測試

- fixture：同一 `task_id` 的 index 行 `created_at` 用**無小數秒**格式（如 `2026-08-10T12:00:00+08:00`），對應 `DECISION-*.json` 的 `escalation_created_at` 用**7位小數秒**格式（如 `2026-08-10T12:00:00.0000000+08:00`），兩者代表同一瞬間。
- 斷言：Hermes Lite（或其底層邏輯）判定這是「同一事件」，並據此把該筆 escalation 判為已解決；若邏輯退化成字串比對，此測試必須失敗（作為防止 regression 的守門測試）。

### 4.4 Fixture 污染排除測試

- fixture：一筆 `is_fixture: true` 且仍是 `awaiting_josh` 的 escalation。
- 斷言：查詢「還有哪些 escalation 在等 Josh 處理？」的清單裡不含此筆；查詢該 task_id 本身時，答案要標註「此為測試/fixture 資料」。

## 5. 對實作的建議（非強制，供 Phase 1 參考）

- 優先方案：Hermes Lite 的 Evidence Retrieval 直接呼叫/複用 `dashboard\backend\main.py` 裡已驗證過的 `_list_escalations()`（或重構出共用模組），避免邏輯分裂成兩份、日後其中一份修了 bug另一份沒跟上。
- 若因架構限制必須獨立實作，**至少要把 §2 的時間比對規則、§3.2 的去重規則、§3.3 的解決狀態判斷順序，逐字對齊**，並把 §4 的三個回歸測試案例納入 Hermes Lite 自己的測試套件，不能只信賴 dashboard 那邊已經測過。

## 6. 與計畫其他 Gate 的關係

- 與 G1（證據優先序）同屬「不能只信單一快照/單一文件欄位，要交叉比對實體證據」的同一類風險，設計精神一致：**顯示狀態（display status）永遠由「有沒有更高優先序的證據」決定，不是由來源檔案自己宣稱的欄位決定**。
- 本規則是 Phase 0 前置第4項的產出，完成後計入 Phase 0 驗收清單（見執行計畫 §2 第6項ADR-0012前的核准依據）。

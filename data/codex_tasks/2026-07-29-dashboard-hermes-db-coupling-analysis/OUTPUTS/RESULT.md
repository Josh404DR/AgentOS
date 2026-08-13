# F02 調查分析與設計提案報告：Dashboard 與 Hermes SQLite DB 資料層耦合隔離

## 執行摘要 (Executive Summary)

- `worker_scope`: outputs_only
- `changed_file`: none
- `change_required`: false
- `test_command`: `& 'E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\.venv\Scripts\python.exe' 'C:\Users\brian\.gemini\antigravity-cli\scratch\inspect_schema.py'`
- `test_result`: PASS (成功讀取並驗證 Hermes state.db 實體 schema，無寫入行為)
- `delivery_artifact`: `E:\AgentOS\data\codex_tasks\2026-07-29-dashboard-hermes-db-coupling-analysis\OUTPUTS\RESULT.md`
- `handoff_to`: Codex Verify
- `caveats`: 本工單為純唯讀調查分析與架構提案，未修改任何 workspace 程式碼或 Hermes 資料庫內容。

---

## 一、 `main.py` 直接連線 Hermes DB 的耦合點與欄位依賴分析

經過對 `E:\AgentOS\dashboard\backend\main.py` 及 Dashboard 後端模組的全面搜尋，確認共有以下 **3 處直接依賴**（1 處全域變數宣告 + 2 處 SQL 查詢執行點）：

### 1. 全域載入與連線設定點
* **位置**：`dashboard\backend\main.py:12` 及 `dashboard\backend\main.py:86`
* **原始碼內容**：
  ```python
  import sqlite3  # line 12
  ...
  HERMES_DB = Path(_RUNTIME_CONFIG["hermes"]["state_db"])  # line 86
  ```
* **說明**：模組載入時直接開啟 `runtime.local.json` 取得 `state_db` 實體檔案路徑並賦予全域變數 `HERMES_DB`。

### 2. Token 使用量統計查詢點 `_read_db_usage()`
* **位置**：`dashboard\backend\main.py:540-621`（連線位於第 545 行）
* **原始碼內容**：
  ```python
  con = sqlite3.connect(str(HERMES_DB))
  ```
* **查詢邏輯與依賴欄位**：
  * **目標資料表**：`sessions`
  * **讀取欄位**：
    * 歷史總計 (Total)：`COUNT(*)` as `session_count`, `SUM(api_call_count)`, `SUM(message_count)`, `SUM(tool_call_count)`, `SUM(input_tokens)`, `SUM(output_tokens)`, `SUM(cache_read_tokens)`, `SUM(cache_write_tokens)`, `SUM(estimated_cost_usd)`, `SUM(actual_cost_usd)`, `MAX(started_at)`
    * 最近 5 小時滾動視窗 (Rolling 5h window)：`started_at`, `input_tokens`, `output_tokens`, `cache_read_tokens`, `reasoning_tokens`, `estimated_cost_usd`（條件：`started_at >= (strftime('%s','now') - 18000)`）
    * 最近 7 天滾動視窗 (Rolling 7d window)：`started_at`, `input_tokens`, `output_tokens`, `cache_read_tokens`, `reasoning_tokens`, `estimated_cost_usd`（條件：`started_at >= (strftime('%s','now') - 604800)`）
    * 當前模型 (Current Model)：`model`（條件：`ORDER BY started_at DESC LIMIT 1`）
    * 最近 20 筆 Session 列表 (Recent Sessions)：`id`, `source`, `model`, `input_tokens`, `output_tokens`, `cache_read_tokens`, `estimated_cost_usd`, `started_at`, `ended_at`

### 3. 上下文視窗使用率查詢點 `_context_window_pct()`
* **位置**：`dashboard\backend\main.py:2264-2300`（連線位於第 2272 行）
* **原始碼內容**：
  ```python
  con = sqlite3.connect(str(HERMES_DB))
  ```
* **查詢邏輯與依賴欄位**：
  * **目標資料表**：`sessions`
  * **讀取欄位**：`model`, `input_tokens`, `output_tokens`, `cache_read_tokens`, `cache_write_tokens`, `started_at`（條件：`ORDER BY started_at DESC LIMIT 1`）
  * **用途**：計算最近一次 Session 佔用的 Token 總數對比模型 Context Limit 的使用率百分比。

---

## 二、 Hermes `state.db` 實際 Schema 驗證與一致性比對

使用 Python `sqlite3` 唯讀模式對 `C:\Users\brian\AppData\Local\hermes\state.db` 進行 `PRAGMA table_info` 實體查詢，結果如下：

### 1. 資料庫實體資料表列表
* `schema_version`
* `sessions`
* `messages`
* `state_meta`

### 2. `sessions` 資料表完整 Schema 結構
| CID | 欄位名稱 (Column) | 資料型態 (Type) | 必填 (Not Null) | 主鍵 (PK) | Dashboard 查詢用途 |
|---|---|---|---|---|---|
| 0 | `id` | `TEXT` | 否 | 1 (主鍵) | Session ID |
| 1 | `source` | `TEXT` | 是 | 0 | 來源識別 |
| 2 | `user_id` | `TEXT` | 否 | 0 | (未直接使用) |
| 3 | `model` | `TEXT` | 否 | 0 | 模型名稱與 Context 計算 |
| 4 | `model_config` | `TEXT` | 否 | 0 | (未直接使用) |
| 5 | `system_prompt` | `TEXT` | 否 | 0 | (未直接使用) |
| 6 | `parent_session_id` | `TEXT` | 否 | 0 | (未直接使用) |
| 7 | `started_at` | `REAL` | 是 | 0 | 時間戳記 (Unix Epoch 秒數) |
| 8 | `ended_at` | `REAL` | 否 | 0 | 結束時間 |
| 9 | `end_reason` | `TEXT` | 否 | 0 | (未直接使用) |
| 10 | `message_count` | `INTEGER` | 否 | 0 | 訊息數統計 |
| 11 | `tool_call_count` | `INTEGER` | 否 | 0 | 工具呼叫數統計 |
| 12 | `input_tokens` | `INTEGER` | 否 | 0 | Input Token 數 |
| 13 | `output_tokens` | `INTEGER` | 否 | 0 | Output Token 數 |
| 14 | `cache_read_tokens` | `INTEGER` | 否 | 0 | Cache Read Token 數 |
| 15 | `cache_write_tokens` | `INTEGER` | 否 | 0 | Cache Write Token 數 |
| 16 | `reasoning_tokens` | `INTEGER` | 否 | 0 | Reasoning Token 數 |
| 17 | `billing_provider` | `TEXT` | 否 | 0 | (未直接使用) |
| 18 | `billing_base_url` | `TEXT` | 否 | 0 | (未直接使用) |
| 19 | `billing_mode` | `TEXT` | 否 | 0 | (未直接使用) |
| 20 | `estimated_cost_usd` | `REAL` | 否 | 0 | 預估費用 |
| 21 | `actual_cost_usd` | `REAL` | 否 | 0 | 實際費用 |
| 22 | `cost_status` | `TEXT` | 否 | 0 | (未直接使用) |
| 23 | `cost_source` | `TEXT` | 否 | 0 | (未直接使用) |
| 24 | `pricing_version` | `TEXT` | 否 | 0 | (未直接使用) |
| 25 | `title` | `TEXT` | 否 | 0 | (未直接使用) |
| 26 | `api_call_count` | `INTEGER` | 否 | 0 | API 呼叫次數 |
| 27 | `handoff_state` | `TEXT` | 否 | 0 | (未直接使用) |
| 28 | `handoff_platform` | `TEXT` | 否 | 0 | (未直接使用) |
| 29 | `handoff_error` | `TEXT` | 否 | 0 | (未直接使用) |

### 3. 一致性比較結論
* **一致性狀況**：目前 `state.db` 中的 `sessions` 欄位與 `main.py` 的 SQL 語句完全吻合。
* **潛在風險點**：
  1. **強耦合無防護**：Dashboard 直接對 Hermes 內部 DB 發動 SQL 查詢。若 Hermes 未來更改欄位名稱（例如 `started_at` 改為 ISO 8601 字串或 `session_logs`）、微調型態或進行 DB 表解耦，Dashboard 會直接引發死機或 500 錯誤。
  2. **併發與檔案鎖**：當 Hermes 在寫入 `state.db` 時，Dashboard 以 `sqlite3.connect` 連線可能面臨 lock 競爭或 dirty read 問題。

---

## 三、 資料層隔離設計選項 (Architectural Options)

為了消除 Dashboard 與 Hermes 內部 SQLite DB 的直接耦合，提出以下 3 種隔離設計選項：

### 選項 A：AgentOS 內部 Repository / DAO 封裝層 (`HermesUsageRepository`)
* **大致做法**：
  * 在 AgentOS Dashboard 後端建立獨立的 Data Access Object (DAO) 抽象模組（例如 `dashboard/backend/repositories/hermes_repo.py`）。
  * 定義 `HermesUsageProvider` 介面，將所有 SQL 查詢與欄位對應（mapping）邏輯完全收攏至該 Repository 模組。
  * `main.py` 僅呼叫 `hermes_repo.get_usage_summary()` 與 `hermes_repo.get_latest_context_usage()`。
* **修改檔案範圍**：
  * 新建：`dashboard/backend/repositories/hermes_repo.py`
  * 修改：`dashboard/backend/main.py` (移除原生 `sqlite3` SQL 查詢，改呼叫 Repository)
* **優點**：
  * **完全無需跨專案協調**：100% 在 AgentOS 單方面可重構完成。
  * 迅速消除 `main.py` 內的 SQL 程式碼污染與重複邏輯，符合單一職責原則。
  * 若未來 Hermes DB 變更欄位，只需修改 `hermes_repo.py` 乙處，`main.py` 路由與前端 API 合約完全不受影響。
* **缺點**：
  * 底層實作仍是以唯讀方式開啟 Hermes 的 SQLite 檔案，尚未達到進程間（Process-level）的實體隔離。
* **跨專案協調需求**：**否**（不需要 Hermes 端配合修改）。

---

### 選項 B：Hermes 暴露 HTTP REST API / gRPC 介面
* **大致做法**：
  * 由 Hermes 服務本身（`E:\AI_Projects_Hub\External_AI_Agents\hermes-agent`）提供官方的 Metric API 終端（例如 `GET /api/v1/metrics/usage`）或 CLI 匯出指令（如 `hermes stats --json`）。
  * AgentOS Dashboard 透過 HTTP Client (`httpx` / `requests`) 呼叫 Hermes API 取得標準 JSON 格式的 DTO (Data Transfer Object)。
* **修改檔案範圍**：
  * AgentOS 修改：`dashboard/backend/clients/hermes_client.py` 與 `main.py`。
  * External AI Projects修改：`E:\AI_Projects_Hub\External_AI_Agents\hermes-agent`（需開發 API Endpoint 或 CLI exporter）。
* **優點**：
  * 達到極致的架構解耦與領域邊界隔離（Domain Boundary Enforcement）。
  * Hermes 擁有自身資料庫 schema 的完全隱私權與遷移自由，不受外部連線牽制。
  * 徹底解決 SQLite 檔案鎖與併發存取問題。
* **缺點**：
  * 工作量較高，需雙向維護。若 Hermes 未維持常駐 Daemon 服務，需額外處理服務生命週期與連線失敗退避（fallback）。
* **跨專案協調需求**：**是**（**明確標註：需要跨專案協調，不是 AgentOS 單方面能完成**）。

---

### 選項 C：定時/事件驅動的 JSON/JSONL DTO 匯出檔案
* **大致做法**：
  * Hermes 在每次 Session 結束時，將 Usage Summary 寫入定點的標準 DTO 檔案（如 `data/usage/hermes_usage_summary.json`）。
  * Dashboard 僅需讀取靜態 JSON 檔案，無需載入 `sqlite3` 模組。
* **修改檔案範圍**：
  * AgentOS 修改：`dashboard/backend/main.py` 改讀 JSON 檔案。
  * External AI Projects修改：Hermes 需新增 hook 或 reporter 將摘要寫至指定路徑。
* **優點**：
  * 避免資料庫層級的依賴，Dashboard 讀取極快且零資料庫鎖定風險。
* **缺點**：
  * 非 100% 即時（有匯出時間差）。
* **跨專案協調需求**：**是**（**明確標註：需要跨專案協調，不是 AgentOS 單方面能完成**）。

---

## 四、 務實建議與決策點 (Pragmatic Recommendation)

### 建議選項：優先採用「選項 A (Repository / DAO 封裝層)」

* **推薦理由**：
  1. **單人維運與內部工具屬性**： AgentOS 與 Dashboard 目前定位為內部運維工具，追求高執行效率與低維護成本。
  2. **零跨專案溝通成本**：選項 A 可由 AgentOS 獨立完成重構，不干擾 `E:\AI_Projects_Hub` 下的 Hermes 主程式開發與部署。
  3. **未來擴展彈性**：先以 Option A 抽象化出 `HermesUsageRepository` 介面，若未來 Hermes 決定實作 Option B (HTTP API)，AgentOS 只需要在 Repository 下替換 `HttpHermesUsageRepository` 實作，即可以零破壞的方式無縫升級。

* ** Josh 決策點**：
  - [ ] **同意選項 A**：由 AgentOS Builder 建立 `hermes_repo.py` 封裝 SQL 查詢，`main.py` 呼叫 Repository。
  - [ ] **同意選項 B/C**：列入跨專案需求單，待 Hermes 專案開放 Metric API 後再進行連線解耦。
  - [ ] **保持現狀**：暫不處置，維持目前 `main.py` 直接連線 `state.db`。

---

## 五、 Evidence Block

```yaml
task_status: completed
claimed_by: Antigravity Subagent
task_kind: read_only
evidence_sources:
  - E:\AgentOS\dashboard\backend\main.py
  - C:\Users\brian\AppData\Local\hermes\state.db
verification_summary: "完成 Dashboard (main.py) 3 處 Hermes DB 連線與欄位依賴分析，並完成實體 SQLite schema 的 PRAGMA 比對驗證；提出 3 種隔離架構選項並給出務實建議。"
verified_by_codex: pending
remaining_caveats: "本分析報告為唯讀分析提案，並未修改任何 workspace 程式碼；最終隔離架構選擇留待 Josh 核准決策。"
```

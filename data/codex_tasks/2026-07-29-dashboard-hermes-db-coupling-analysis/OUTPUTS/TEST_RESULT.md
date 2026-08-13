# 唯讀查詢與 Schema 驗證測試報告 (TEST_RESULT.md)

## 1. 測試資訊摘要

- `task_id`: 2026-07-29-dashboard-hermes-db-coupling-analysis
- `task_kind`: read_only
- `test_type`: static_analysis_and_schema_inspection
- `test_command`: `& 'E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\.venv\Scripts\python.exe' 'C:\Users\brian\.gemini\antigravity-cli\scratch\inspect_schema.py'`
- `test_result`: PASS

---

## 2. 測試執行細節與指令

本次調查採用全唯讀模式（Read-Only Mode），完全未對任何 workspace 檔案或 Hermes 資料庫進行修改或寫入。執行了以下兩個階段的查詢驗證：

### 階段一：Dashboard 程式碼連線位置搜尋
* **執行指令**：
  ```powershell
  Get-ChildItem -Path 'E:\AgentOS\dashboard\backend' -Filter '*.py' | Select-String -Pattern 'HERMES_DB|sqlite3|state\.db'
  ```
* **執行結果**：
  精確定位 `dashboard/backend/main.py` 內共有 3 處耦合點（Line 12/86, Line 545, Line 2272）。

### 階段二：Hermes `state.db` 實體 Schema 唯讀查詢
* **執行指令**：
  ```powershell
  & 'E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\.venv\Scripts\python.exe' 'C:\Users\brian\.gemini\antigravity-cli\scratch\inspect_schema.py'
  ```
* **Python 腳本邏輯 (`inspect_schema.py`)**：
  ```python
  import sqlite3, json
  db_path = r"C:\Users\brian\AppData\Local\hermes\state.db"
  con = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
  cur = con.cursor()
  tables = [r[0] for r in cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '%_fts%'").fetchall()]
  result = {}
  for t in tables:
      cols = cur.execute(f"PRAGMA table_info({t})").fetchall()
      result[t] = [{"cid": col[0], "name": col[1], "type": col[2], "notnull": col[3], "dflt_value": col[4], "pk": col[5]} for col in cols]
  print("=== TABLES ===")
  print(tables)
  print("\n=== SCHEMAS ===")
  for t, cols in result.items():
      print(f"\nTable: {t}")
      for col in cols:
          print(f"  [{col['cid']}] {col['name']} ({col['type']}) {'NOT NULL' if col['notnull'] else ''} PK={col['pk']}")
  con.close()
  ```

---

## 3. 實體查詢原始輸出記錄 (Raw Test Output Evidence)

```text
=== TABLES ===
['schema_version', 'sessions', 'messages', 'state_meta']

=== SCHEMAS ===

Table: schema_version
  [0] version (INTEGER) NOT NULL PK=0

Table: sessions
  [0] id (TEXT)  PK=1
  [1] source (TEXT) NOT NULL PK=0
  [2] user_id (TEXT)  PK=0
  [3] model (TEXT)  PK=0
  [4] model_config (TEXT)  PK=0
  [5] system_prompt (TEXT)  PK=0
  [6] parent_session_id (TEXT)  PK=0
  [7] started_at (REAL) NOT NULL PK=0
  [8] ended_at (REAL)  PK=0
  [9] end_reason (TEXT)  PK=0
  [10] message_count (INTEGER)  PK=0
  [11] tool_call_count (INTEGER)  PK=0
  [12] input_tokens (INTEGER)  PK=0
  [13] output_tokens (INTEGER)  PK=0
  [14] cache_read_tokens (INTEGER)  PK=0
  [15] cache_write_tokens (INTEGER)  PK=0
  [16] reasoning_tokens (INTEGER)  PK=0
  [17] billing_provider (TEXT)  PK=0
  [18] billing_base_url (TEXT)  PK=0
  [19] billing_mode (TEXT)  PK=0
  [20] estimated_cost_usd (REAL)  PK=0
  [21] actual_cost_usd (REAL)  PK=0
  [22] cost_status (TEXT)  PK=0
  [23] cost_source (TEXT)  PK=0
  [24] pricing_version (TEXT)  PK=0
  [25] title (TEXT)  PK=0
  [26] api_call_count (INTEGER)  PK=0
  [27] handoff_state (TEXT)  PK=0
  [28] handoff_platform (TEXT)  PK=0
  [29] handoff_error (TEXT)  PK=0

Table: messages
  [0] id (INTEGER)  PK=1
  [1] session_id (TEXT) NOT NULL PK=0
  [2] role (TEXT) NOT NULL PK=0
  [3] content (TEXT)  PK=0
  [4] tool_call_id (TEXT)  PK=0
  [5] tool_calls (TEXT)  PK=0
  [6] tool_name (TEXT)  PK=0
  [7] timestamp (REAL) NOT NULL PK=0
  [8] token_count (INTEGER)  PK=0
  [9] finish_reason (TEXT)  PK=0
  [10] reasoning (TEXT)  PK=0
  [11] reasoning_content (TEXT)  PK=0
  [12] reasoning_details (TEXT)  PK=0
  [13] codex_reasoning_items (TEXT)  PK=0
  [14] codex_message_items (TEXT)  PK=0

Table: state_meta
  [0] key (TEXT)  PK=1
  [1] value (TEXT)  PK=0
```

---

## 4. 驗證結論 (Verification Conclusion)

1. **連線語法與路徑驗證**：已透過 `runtime.local.json` 取得 `state_db` 正確路徑 `C:\Users\brian\AppData\Local\hermes\state.db`，且可正常進行 `mode=ro` 唯讀連線。
2. **Schema 對齊驗證**：`main.py` 所查詢之 `sessions` 資料表及所有 15 個欄位（`id`, `source`, `model`, `started_at`, `ended_at`, `message_count`, `tool_call_count`, `input_tokens`, `output_tokens`, `cache_read_tokens`, `cache_write_tokens`, `reasoning_tokens`, `estimated_cost_usd`, `actual_cost_usd`, `api_call_count`）皆真實存在於實體資料庫中。
3. **無副作用驗證**：所有操作均為唯讀讀取，`SCOPED_DIFF.patch` 保持空白，未對 `E:\AgentOS` 專案檔案進行任何變動。測試通過 (PASS)。

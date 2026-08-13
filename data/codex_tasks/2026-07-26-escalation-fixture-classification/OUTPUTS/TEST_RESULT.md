# Builder Test Result

dispatch_id: 2026-07-26-escalation-fixture-classification
test_role: Codex Builder
overall_builder_test: PASS
independent_verify: PENDING

## 測試證據

1. 治理 gate
   - command: `scripts\assert_governance_ready.ps1`
   - result: PASS；`governance_status=operational_review_required`、
     `task_execution_allowed=true`，version/hash 與工單一致。

2. 正式 index 完整性
   - command: `Get-FileHash -Algorithm SHA256 data\escalations\ESCALATION_INDEX.jsonl`
   - before/after:
     `9EBB6A08459FCF95AF572275CBA19A6EBB3D0FF69D76C802C780F78FA5D6506E`
   - result: PASS，hash 不變。當前有效列為 251；本單基準為前 250 列。

3. 分類側表完整覆蓋
   - assertion: 側表恰有 250 列；每列 `index_line` 與基準列位置相同、task_id
     相同；environment 僅為 `ci`/`runtime`；is_fixture 與 environment 一致。
   - result: PASS；`ci=2`、`runtime=248`。

4. writer 新 schema
   - test root:
     `OUTPUTS/test_root/data/escalations`
   - explicit test: `-Environment ci`
   - default test: 未傳 Environment
   - result: PASS；詳細 JSON 與 index JSONL 都有 environment；值分別為
     `ci` 與 `runtime`。
   - PowerShell parser syntax check: PASS。

5. `/api/escalations` 篩選
   - command:
     `py -3.13 -m unittest data.codex_tasks.2026-07-26-escalation-fixture-classification.OUTPUTS.test_endpoint_filter`
   - method: 解析完整 `main.py` AST，直接編譯並呼叫其中的
     `list_escalations` 原始函式。
   - result: PASS（2 tests）；側表 loader 正確取得 ci/runtime 分類；endpoint
     預設只回傳 1 筆 runtime，`include_ci_fixtures=True` 回傳全部 2 筆。

## 環境限制

嘗試執行既有
`py -3.13 -m unittest tests.test_ci_fixture_namespace` 時，環境回報
`ModuleNotFoundError: No module named 'fastapi'`。未自行安裝依賴；改用上述
stdlib 隔離測試，並保留 `OUTPUTS/test_endpoint_filter.py` 供 verifier 重跑。

## 禁止事項檢查

- `decide_escalation.ps1`: NOT CALLED
- 正式 escalation 歷史列刪除/覆寫: NONE
- `task_queue_runner.ps1`: NOT MODIFIED
- `dashboard_security.py`: NOT MODIFIED
- `E:\AI_Projects_Hub`: NOT TOUCHED

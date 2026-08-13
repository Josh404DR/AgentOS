test_command: `Get-Content E:\AgentOS\data\escalations\ESCALATION_INDEX.jsonl | Measure-Object -Line`
test_result: PASS — 6 行，與原始完全相符，無新增或修改
test_command: 讀取 `E:\AgentOS\data\escalations\2026-07-03-workflow-v1-2-risky-fixture\RESOLUTION.json` — 驗證 `resolution_type=resolved_by_evidence`、`josh_action_required=false`
test_result: PASS — Read 工具確認欄位正確
test_command: 讀取 `E:\AgentOS\data\escalations\2026-07-03-workflow-v1-2-dedupe-fixture\RESOLUTION.json` — 驗證 `resolution_type=resolved_by_evidence`、`josh_action_required=false`
test_result: PASS — Read 工具確認欄位正確
test_command: `grep -n "api/escalations" E:\AgentOS\dashboard\backend\main.py`
test_result: PASS — 找到第 866 行 `@app.get("/api/escalations")`，_list_escalations 函式於第 561 行，ESCALATIONS_DIR 常數於第 43 行
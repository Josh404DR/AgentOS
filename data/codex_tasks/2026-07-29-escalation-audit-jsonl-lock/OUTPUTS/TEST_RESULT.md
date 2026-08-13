# TEST_RESULT — escalation AUDIT.jsonl global lock

test_status: locally_verified
tested_at: 2026-07-29 Asia/Taipei

## 實測結果

| 測試 | 結果 |
|---|---|
| Governance readiness | PASS；`governance_gate=passed`、`governance_status=operational_review_required`、`task_execution_allowed=true` |
| Target syntax | PASS；`parse_errors=0` |
| PowerShell BOM policy | PASS；`powershell_utf8_bom_regression=PASS`、`repository_scan_passed=true`、exit 0 |
| 單筆直接呼叫 `Write-DecisionAudit` | PASS；`single_exit=0`、`single_json_valid=True` |
| 20-process 並發呼叫實際 target function | PASS；20 processes 全 exit 0；加單筆共 21 行，`json_valid_count=21`、`json_invalid_count=0`、`unique_request_count=21`、`pending_count=0` |
| 鎖逾時 fallback | PASS；17 秒 mutex contention 得到 `invoke_exit=1`、`lock_timeout_reported=True`、`pending_count=1`、`pending_json_valid=True`、target audit 未被錯誤寫入 |
| 既有 global lock regression | PASS；5 processes × 25 writes，`expected_lines=125`、`actual_lines=125`、`json_lines_parsed=125`、`sharing_violations=0`、`lock_timeout_observed=True`、`pending_side_queue_files=1` |
| `Reject-Decision` 呼叫端 fixture | PASS；missing receipt 保持 `exit_code=12`、`task_status=awaiting_josh`、`reason=decision_receipt_missing`、audit 1 行合法 JSON、`decision_count=0` |
| escalation hardening temp regression | PARTIAL；所有 decider receipt/audit assertions 執行後，唯一 failure 為未修改的 Queue invalid-DECISION precise-reason expectation；現行 test fixture 亦需補 index rebuild 與新 lib 相依，非本次 source scope |

## 並發測試關鍵原始輸出

```text
process_count=20
process_nonzero=0
line_count=21
json_valid_count=21
json_invalid_count=0
unique_request_count=21
pending_count=0
```

## Fallback 關鍵原始輸出

```text
invoke_exit=1
lock_timeout_reported=True
pending_count=1
pending_json_valid=True
target_audit_exists=False
```

所有自建 fixture 位於 `C:\tmp\escalation-audit-jsonl-lock\`，未寫入正式 escalation／audit 資料。

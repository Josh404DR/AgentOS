# TEST_RESULT — F06 revision-3

dispatch_id: 2026-07-29-observability-silent-catch-fix-revision-3
tested_at: 2026-07-29T21:23:15.9952419+08:00
runtime_executed: true
scripts_executed: true
builder_test_status: passed

## 實際命令

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "E:\AgentOS\data\codex_tasks\2026-07-29-observability-silent-catch-fix-revision-2\OUTPUTS\_test_scenarios.ps1"
```

## 真實 stdout

```text
S1_error=True
S1_pid=1234
S1_null=False
S2_error_set=True
S2_error_has_path=True
S2_error_has_exc=True
S2_receipt_null=True
S2_rewrite=True
S2_error_msg=existing receipt read/parse failed at C:\Users\brian\AppData\Local\Temp\agentos_receipt_test\receipt_corrupt.json : Invalid object passed in, ':' or '}' expected. (7): { not valid json !!! }

S3_testpath=False
S3_error=True
S3_receipt_null=True
S3_rewrite=True
test_exit=0
```

## 結論

- 合法 JSON：沒有 reconciliation error、process ID 為 1234、receipt 非 null。
- 損毀 JSON：error 被設定且包含精確 path 與 parser exception；receipt 保持 null，rewrite path 為 true。
- 檔案不存在：Test-Path false、沒有 parse error、receipt null，rewrite path 為 true。
- fixture parser errors：0。
- 現場來源 SHA-256：`9D48FC6508AD3CF4F6A4679FF26D65752B164B8F88FFD52F0A0CAED1497914F6`。


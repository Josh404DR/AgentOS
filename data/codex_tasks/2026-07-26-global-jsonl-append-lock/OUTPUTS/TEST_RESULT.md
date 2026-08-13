# 2026-07-26-global-jsonl-append-lock Builder 測試結果

test_status: PASS
independent_verify_status: PASS

## Governance gate

結果：PASS。

```text
governance_gate=passed
governance_status=operational_review_required
governance_version=1.3.0
governance_hash=0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1
task_execution_allowed=true
operational_drift_count=23
```

## 多 process fault-injection

命令：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\AgentOS\tests\test_global_jsonl_append_lock.ps1 -AgentOSRoot E:\AgentOS
```

結果：PASS。

```text
global_jsonl_append_lock_status=passed
parallel_processes=5
writes_per_process=25
expected_lines=125
actual_lines=125
json_lines_parsed=125
sharing_violations=0
lock_timeout_observed=True
pending_side_queue_files=1
```

測試以 5 個獨立 `powershell.exe` 同時對同一 JSONL 各 append 25 次；
125 筆皆存在且逐行通過 `ConvertFrom-Json`。另一個 process 持鎖 5 秒，
測試端使用 100 ms timeout、2 次 retry，確認原 append 未進入目標檔、
待寫入內容完整落地至唯一 side queue，並收到含 `lock_timeout` 與
`pending_path` 的明確錯誤。

## 指定回歸測試

| 測試 | 最終結果 | 證據 |
| --- | --- | --- |
| `tests\test_queue_failure_containment.ps1` | PASS | `queue_failure_containment_status=passed` |
| `tests\test_queue_reason_propagation.ps1` | PASS | `queue_reason_propagation_status=passed` |
| `tests\test_dispatch_resilience.ps1` | PASS | `dispatch_resilience_status=passed`; `case_count=6` |
| `tests\test_escalation_decision_hardening.ps1` | PASS | `escalation_decision_hardening=PASS`; `historical_escalation_hashes_unchanged=true` |

`test_dispatch_resilience.ps1` 首次在受限 sandbox 內因讀取使用者設定檔路徑
得到 `Test-Path : Access is denied`，並非產品 assertion failure。依執行
政策在 sandbox 外 bounded 重跑後 PASS；舊失敗與最終結果均保留於本報告。

## 語法與目標腳本 smoke

- PowerShell parser：5 個本工單檔案全部 PASS。
- `write_task_metric.ps1` 使用臨時 `AgentOSRoot` 寫入後可解析，
  `task_id=lock-smoke-metric`。
- `write_escalation.ps1` 使用臨時 `AgentOSRoot` 寫入後可解析，
  `task_id=lock-smoke-escalation`。
- smoke 僅使用 `%TEMP%`，未改寫正式
  `METRICS_LOG.jsonl`／`ESCALATION_INDEX.jsonl`。

## 獨立 blind verify

結果：PASS。

```text
verify_verdict: PASS
驗證結果：成功
已達成：5
未達成：0
無法驗證：0
```

全新 read-only Codex Verify process 獨立重跑 5 processes × 25 writes，
並確認 mutex 包裝、side queue timeout、四支回歸證據、scoped diff 與
治理綁定。完整結果：
`data\codex_tasks\2026-07-26-global-jsonl-append-lock-codex-verify\OUTPUTS\RESULT.md`。

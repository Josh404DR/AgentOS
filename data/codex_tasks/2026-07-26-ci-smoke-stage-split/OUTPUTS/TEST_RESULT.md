# 2026-07-26-ci-smoke-stage-split Builder 測試結果

test_status: builder_checks_completed
full_ci_status: FAIL
full_ci_pass_claimed: false
independent_verify_status: round_2_failed_fixes_applied_round_3_pending

## Governance gate

結果：PASS。

```text
governance_gate=passed
governance_status=operational_review_required
governance_version=1.3.0
governance_hash=0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1
task_execution_allowed=true
operational_drift_count=22
```

## PowerShell AST

結果：PASS，共解析 9 個本工單 PowerShell 檔案。

## Timeout 故障隔離

命令：`tests\test_agentos_ci_smoke_split.ps1`

結果：PASS。注入的 child PowerShell hang 使 `governance_and_syntax` 產生
`TIMEOUT`、exit 124 及部分結果；PID-scoped process tree termination 後，
其後 `dashboard_optional` 仍完成。兩個 suite 均留下獨立 JSON/Markdown。

證據：`OUTPUTS\test-artifacts\automated-timeout\latest.json`

## 個別 suite

| Suite | 結果 | 證據 |
| --- | --- | --- |
| governance_and_syntax | PASS | `OUTPUTS\test-artifacts\builder-governance\governance_and_syntax\latest.json` |
| dashboard_optional | PASS | `OUTPUTS\test-artifacts\builder-dashboard\dashboard_optional\latest.json` |
| queue_and_antigravity_dryrun | WARN；live model smoke 明確跳過 | `OUTPUTS\test-artifacts\builder-queue\queue_and_antigravity_dryrun\latest.json` |
| python_suites | FAIL；pytest dependency 缺少 | `OUTPUTS\test-artifacts\builder-python\python_suites\latest.json` |

Python 實際 launcher：

```text
kind=project_venv
path=E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe
probe=usable; Python 3.12.13
```

pytest dependency 的實際失敗：

```text
Python exited 1; launcher=E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe;
E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe: No module named pytest
```

該 suite 最終為 `FAIL`、exit 1，未誤報 PASS。

## Fixture namespace API

命令：

```powershell
dashboard\backend\.venv\Scripts\python.exe -m unittest tests\test_ci_fixture_namespace.py
```

結果：PASS（2 tests）。

- `/api/tasks`：預設隱藏，`include_ci_fixtures=true` 顯示全部。
- `/api/escalations`：預設隱藏，`include_ci_fixtures=true` 顯示全部。

## Diff hygiene

`git diff --check`：PASS；僅有既有 Windows LF/CRLF 提示，無 whitespace error。

## Verify round 1 修正測試

- PowerShell AST：PASS（8 個 smoke scoped PowerShell 檔）。
- timeout process-tree／後續 suite 隔離：PASS。
- 缺少 Hermes runtime locks 的注入情境：
  - optional：`gateway_runtime_receipt_reconciliation=WARN`
  - `-RequireHermesRuntimes`：`gateway_runtime_receipt_reconciliation=FAIL`
- 靜態路徑確認：總入口、suite wrapper、worker 均傳遞／使用
  `RequireHermesRuntimes`。
- 已恢復 `gateway_runtime_receipt_reconciliation`、
  `hermes_autostart_dedupe` 及三支 observability scripts 的 AST parse。

## Verify round 2 修正測試

- Suite JSON/Markdown 新增明確 `run_id`。
- Orchestrator JSON/Markdown 與每個 suite overview entry 新增明確 `run_id`。
- timeout 測試新增 `run_id` 存在及 overview／suite receipt 一致性斷言。

# TEST_RESULT — child-06 orchestrator fault test

dispatch_id: 2026-07-26-ci-smoke-stage-split-child-06-orchestrator-fault-test
tested_at: 2026-07-30T12:23:49.7796641+08:00
builder_test_status: passed
full_ci_executed: false
full_ci_pass_claimed: false
fault_test_execution_count: 1

## Dependency verification

| Dependency | Independent verdict | Verify RESULT SHA-256 |
|---|---|---|
| child-02 | PASS | `F9D8437B6CC18DB2A8906F26EC9C7A82C7D20FB536ACBA9737D84EE00CC824F2` |
| child-03 | PASS | `F8CA3423DAC783A23444D9A1C6F28AB2E782A0F3A92109AAF6838F083EA632CA` |
| child-04 | PASS | `51B5C523D5C3712EA35AAF389AEEE87F7818D6E8D88CD131CFE3B7718EBCE641` |
| child-05 revision-1 | PASS | `5AF97C277D77831FD85139A56A228AD199EF368D6BF2948E2B02B633AD099DE6` |

## Parser／schema checks

```text
orchestrator_parser_errors=0
test_parser_errors=0
summary_schema_ok=True
suite_run_ids_unique=True
all_receipts_exist=True
```

## 唯一一次 fault injection 真實輸出

Command：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\AgentOS\tests\test_agentos_ci_smoke_split.ps1 -AgentOSRoot E:\AgentOS
```

Output：

```text
agentos_ci_smoke_status=TIMEOUT
fail_count=0
warn_count=0
timeout_count=1
result_json=E:\AgentOS\data\codex_tasks\2026-07-26-ci-smoke-stage-split\OUTPUTS\test-artifacts\automated-timeout\ci-smoke-20260730-122255-876.json
result_markdown=E:\AgentOS\data\codex_tasks\2026-07-26-ci-smoke-stage-split\OUTPUTS\test-artifacts\automated-timeout\ci-smoke-20260730-122255-876.md
ci_smoke_split_timeout_test=PASS
orchestrator_summary=E:\AgentOS\data\codex_tasks\2026-07-26-ci-smoke-stage-split\OUTPUTS\test-artifacts\automated-timeout\latest.json
fault_test_exit=0
fault_test_started=2026-07-30T12:22:52.7114504+08:00
fault_test_finished=2026-07-30T12:23:11.7914905+08:00
```

## Run-specific receipt validation

Orchestrator:

- run ID：`ci-smoke-20260730-122255-876`
- status：TIMEOUT
- exit code：124
- duration：15.295 seconds
- suite count：2
- timeout/fail/warn count：1/0/0

Injected hang suite:

- suite：`governance_and_syntax`
- run ID：`ci-smoke-governance_and_syntax-20260730-122255-876`
- status：TIMEOUT
- exit code：124
- receipt check：`suite_timeout`／TIMEOUT／124
- JSON/Markdown：均存在

Continued normal suite:

- suite：`dashboard_optional`
- run ID：`ci-smoke-dashboard_optional-20260730-122255-876`
- status：PASS
- exit code：0
- checks：4
- JSON/Markdown：均存在

Summary 內兩個 suite run ID 與各自 receipt 的 `run_id` 完全相同。

## 舊證據保留

Fault run 前 parent OUTPUTS 有 188 個檔案，執行後 198 個；原有路徑缺失數 0。6 個名為 `latest.json`／`latest.md` 的 rolling aliases依設計更新；immutable run-specific receipts 與 child Verify artifacts 未刪除。四份 dependency Verify RESULT 的 SHA-256 如上。

## Source hashes

- `scripts\agentos_ci_smoke.ps1`: `B51CA9AE4435FB5E29B79A8FBF3B017432D68FE7336E5A8709AABD4AF41C3854`
- `tests\test_agentos_ci_smoke_split.ps1`: `E85A42390756824E7693FBD307AE65B9ACE4BD67E9C93A1889DC8FC05315AAE5`


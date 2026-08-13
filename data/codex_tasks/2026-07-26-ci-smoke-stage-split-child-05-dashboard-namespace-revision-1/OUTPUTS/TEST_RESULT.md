# TEST_RESULT — child-05 dashboard namespace revision-1

dispatch_id: 2026-07-26-ci-smoke-stage-split-child-05-dashboard-namespace-revision-1
tested_at: 2026-07-29T21:24:49.9086209+08:00
builder_test_status: passed

## 診斷探測

在 `powershell.exe -NoProfile -ExecutionPolicy Bypass` 中匯入現場 module，實際執行：

```powershell
Resolve-AgentOSPythonLauncher -AgentOSRoot E:\AgentOS
```

結果：

```json
{
  "kind": "project_venv",
  "path": "E:\\AgentOS\\dashboard\\backend\\.venv\\Scripts\\python.exe",
  "probes": [{
    "kind": "project_venv",
    "path": "E:\\AgentOS\\dashboard\\backend\\.venv\\Scripts\\python.exe",
    "status": "usable",
    "exit_code": 0,
    "raw_output": "Python 3.12.13"
  }]
}
```

系統同時存在 bundled candidate：

`C:\Users\brian\AppData\Local\hermes\hermes-agent\venv\Scripts\python.exe`

## 完整 suite 實跑

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "E:\AgentOS\scripts\ci_smoke\ci_smoke_dashboard_optional.ps1" `
  -AgentOSRoot "E:\AgentOS" `
  -OutputDir "E:\AgentOS\data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-05-dashboard-namespace-revision-1\OUTPUTS\test-artifacts" `
  -TimeoutSeconds 30 `
  -RunId "child-05-revision-1-dashboard-optional"
```

真實 stdout：

```text
ci_smoke_suite=dashboard_optional
ci_smoke_suite_status=PASS
result_json=E:\AgentOS\data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-05-dashboard-namespace-revision-1\OUTPUTS\test-artifacts\dashboard_optional\child-05-revision-1-dashboard-optional.json
result_markdown=E:\AgentOS\data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-05-dashboard-namespace-revision-1\OUTPUTS\test-artifacts\dashboard_optional\child-05-revision-1-dashboard-optional.md
suite_exit=0
```

Receipt 實際結果：

- suite status `PASS`、exit code 0、duration `3.346s`
- `python_launcher_resolution`: PASS，project venv usable，Python 3.12.13
- `ci_fixture_namespace`: PASS，exit 0，3 tests in `0.250s`
- `dashboard_health_endpoint`: PASS
- fail/warn/timeout count 全部為 0

Receipt：

- `OUTPUTS\test-artifacts\dashboard_optional\child-05-revision-1-dashboard-optional.json`
- `OUTPUTS\test-artifacts\dashboard_optional\child-05-revision-1-dashboard-optional.md`


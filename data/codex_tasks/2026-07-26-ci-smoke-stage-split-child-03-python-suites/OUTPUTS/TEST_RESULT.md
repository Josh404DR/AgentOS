# Child 03 Test Result

dispatch_id: 2026-07-26-ci-smoke-stage-split-child-03-python-suites
test_status: locally_verified

## Bounded checks

1. `Resolve-AgentOSPythonLauncher` probe（執行一次）：PASS，exit 0。
   - selected kind: `project_venv`
   - absolute launcher: `E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe`
   - probe output: `Python 3.12.13`
2. `ci_smoke_python_suites.ps1`（執行一次，default timeout 150 秒）：FAIL，exit 1，duration 10.348 秒。
   - `url_knowledge_intake`: PASS（10 tests）
   - `dashboard_security`: PASS（17 tests）
   - `knowledge_workspace`: PASS（20 tests）
   - `utf8_encoding_boundary`: PASS（6 cases）
   - `pytest_dependency`: FAIL，exit 1
   - raw error: `E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe: No module named pytest`
   - `python_compile_core`（optional）: PASS

此 FAIL 是必要 dependency check 的預期誠實結果；未安裝 pytest，且未誤報 PASS/WARN。

## Evidence

- `OUTPUTS\test-artifacts\python_suites\child-03-python-suites-bounded.json`
- `OUTPUTS\test-artifacts\python_suites\child-03-python-suites-bounded.md`
- `OUTPUTS\test-artifacts\python_suites\child-03-python-suites-bounded.stdout.log`
- `OUTPUTS\test-artifacts\python_suites\child-03-python-suites-bounded.stderr.log`


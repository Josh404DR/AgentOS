# AgentOS CI Smoke Suite: python_suites

run_id: ci-smoke-python_suites-20260807-092533-862
status: FAIL
exit_code: 1
timeout_seconds: 150
duration_seconds: 28.876
python_launcher: E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe

| Check | Status | Exit code | Duration (s) | Detail |
| --- | --- | ---: | ---: | --- |
| suite_bootstrap | PASS | 0 | 0.009 | suite=python_suites timeout_seconds=150 |
| python_launcher | PASS | 0 | 0.007 | kind=project_venv path=E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe probes={"kind":"project_venv","path":"E:\\AgentOS\\dashboard\\backend\\.venv\\Scripts\\python.exe","status":"usable","exit_code":0,"raw_output":"Python 3.12.13"} |
| url_knowledge_intake | PASS | 0 | 0.719 | launcher=E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe; exit_code=0; raw_error=; output=..........<br>----------------------------------------------------------------------<br>Ran 10 tests in 0.455s<br>System.Management.Automation.RemoteException<br>OK |
| dashboard_security | PASS | 0 | 15.176 | launcher=E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe; exit_code=0; raw_error=; output=E:\AgentOS\dashboard\backend\.venv\Lib\site-packages\fastapi\testclient.py:1: StarletteDeprecationWarning: Using `httpx` with `starlette.testclient` is deprecated; install `httpx2` instead.<br>  from starlette.testclient import TestClient as TestClient  # noqa<br>.................<br>----------------------------------------------------------------------<br>Ran 17 tests in 13.806s<br>System.Management.... |
| knowledge_workspace | PASS | 0 | 8.332 | launcher=E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe; exit_code=0; raw_error=; output=E:\AgentOS\dashboard\backend\.venv\Lib\site-packages\fastapi\testclient.py:1: StarletteDeprecationWarning: Using `httpx` with `starlette.testclient` is deprecated; install `httpx2` instead.<br>  from starlette.testclient import TestClient as TestClient  # noqa<br>....................<br>----------------------------------------------------------------------<br>Ran 20 tests in 7.078s<br>System.Managemen... |
| utf8_encoding_boundary | PASS | 0 | 3.64 | launcher=E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe; exit_code=0; raw_error=; output=encoding_boundary_test_status=passed<br>case_count=6 |
| pytest_dependency | FAIL | 1 | 0.118 | launcher=E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe; exit_code=1; raw_error=E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe: No module named pytest |
| python_compile_core | PASS | 0 | 0.229 | launcher=E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe; exit_code=0; raw_error= |

## Fixture paths

- none

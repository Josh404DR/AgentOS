# AgentOS CI Smoke Suite: python_suites

run_id: ci-smoke-python_suites-20260810-002206-813
status: PASS
exit_code: 0
timeout_seconds: 150
duration_seconds: 9.335
python_launcher: E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe

| Check | Status | Exit code | Duration (s) | Detail |
| --- | --- | ---: | ---: | --- |
| suite_bootstrap | PASS | 0 | 0.028 | suite=python_suites timeout_seconds=150 |
| python_launcher | PASS | 0 | 0.014 | kind=project_venv path=E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe probes={"kind":"project_venv","path":"E:\\AgentOS\\dashboard\\backend\\.venv\\Scripts\\python.exe","status":"usable","exit_code":0,"raw_output":"Python 3.12.13"} |
| url_knowledge_intake | PASS | 0 | 0.312 | launcher=E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe; exit_code=0; raw_error=; output=..........<br>----------------------------------------------------------------------<br>Ran 10 tests in 0.195s<br>System.Management.Automation.RemoteException<br>OK |
| dashboard_security | PASS | 0 | 3.928 | launcher=E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe; exit_code=0; raw_error=; output=E:\AgentOS\dashboard\backend\.venv\Lib\site-packages\fastapi\testclient.py:1: StarletteDeprecationWarning: Using `httpx` with `starlette.testclient` is deprecated; install `httpx2` instead.<br>  from starlette.testclient import TestClient as TestClient  # noqa<br>.................<br>----------------------------------------------------------------------<br>Ran 17 tests in 2.706s<br>System.Management.A... |
| knowledge_workspace | PASS | 0 | 2.624 | launcher=E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe; exit_code=0; raw_error=; output=E:\AgentOS\dashboard\backend\.venv\Lib\site-packages\fastapi\testclient.py:1: StarletteDeprecationWarning: Using `httpx` with `starlette.testclient` is deprecated; install `httpx2` instead.<br>  from starlette.testclient import TestClient as TestClient  # noqa<br>....................<br>----------------------------------------------------------------------<br>Ran 20 tests in 2.038s<br>System.Managemen... |
| utf8_encoding_boundary | PASS | 0 | 1.79 | launcher=E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe; exit_code=0; raw_error=; output=encoding_boundary_test_status=passed<br>case_count=6 |
| pytest_dependency | PASS | 0 | 0.216 | launcher=E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe; exit_code=0; raw_error=; output=pytest 9.1.1 |
| python_compile_core | PASS | 0 | 0.139 | launcher=E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe; exit_code=0; raw_error= |

## Fixture paths

- none

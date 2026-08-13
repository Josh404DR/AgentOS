# AgentOS CI Smoke Suite: python_suites

run_id: ci-smoke-python_suites-20260807-092056-558
status: FAIL
exit_code: 1
timeout_seconds: 150
duration_seconds: 5.819
python_launcher: E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe

| Check | Status | Exit code | Duration (s) | Detail |
| --- | --- | ---: | ---: | --- |
| suite_bootstrap | PASS | 0 | 0.009 | suite=python_suites timeout_seconds=150 |
| python_launcher | PASS | 0 | 0.032 | kind=project_venv path=E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe probes={"kind":"project_venv","path":"E:\\AgentOS\\dashboard\\backend\\.venv\\Scripts\\python.exe","status":"usable","exit_code":0,"raw_output":"Python 3.12.13"} |
| url_knowledge_intake | FAIL | 1 | 0.674 | launcher=E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe; exit_code=1; raw_error=Traceback (most recent call last):<br>  File "<frozen runpy>", line 198, in _run_module_as_main<br>  File "<frozen runpy>", line 88, in _run_code<br>  File "C:\Users\brian\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\Lib\unittest\__main__.py", line 18, in <module><br>    main(module=None)<br>  File "C:\Users\brian\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\Lib\unittest\m... |
| dashboard_security | FAIL | 1 | 0.199 | launcher=E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe; exit_code=1; raw_error=Traceback (most recent call last):<br>  File "<frozen runpy>", line 198, in _run_module_as_main<br>  File "<frozen runpy>", line 88, in _run_code<br>  File "C:\Users\brian\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\Lib\unittest\__main__.py", line 18, in <module><br>    main(module=None)<br>  File "C:\Users\brian\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\Lib\unittest\m... |
| knowledge_workspace | FAIL | 1 | 0.174 | launcher=E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe; exit_code=1; raw_error=Traceback (most recent call last):<br>  File "<frozen runpy>", line 198, in _run_module_as_main<br>  File "<frozen runpy>", line 88, in _run_code<br>  File "C:\Users\brian\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\Lib\unittest\__main__.py", line 18, in <module><br>    main(module=None)<br>  File "C:\Users\brian\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\Lib\unittest\m... |
| utf8_encoding_boundary | PASS | 0 | 3.573 | launcher=E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe; exit_code=0; raw_error=; output=encoding_boundary_test_status=passed<br>case_count=6 |
| pytest_dependency | FAIL | 1 | 0.099 | launcher=E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe; exit_code=1; raw_error=E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe: No module named pytest |
| python_compile_core | PASS | 0 | 0.279 | launcher=E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe; exit_code=0; raw_error= |

## Fixture paths

- none

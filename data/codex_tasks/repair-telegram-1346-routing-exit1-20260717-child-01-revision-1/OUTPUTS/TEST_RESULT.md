test_command: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\classify_task_regression.ps1 -AgentOSRoot E:\AgentOS
test_result: PASS — classifier_regression_status=passed; case_count=12; exit_code=0
test_command: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test_dispatch_diff_helper.ps1 -AgentOSRoot E:\AgentOS
test_result: PASS — diff_helper_regression_status=passed; case_count=4; exit_code=0
test_command: PowerShell Language.Parser ParseFile for scripts\dispatch_task_packet.ps1
test_result: PASS — dispatch_syntax=passed; exit_code=0
test_command: python tests\test_utf8_encoding_boundary.py
test_result: NOT_EXECUTED — configured Python launcher unavailable.

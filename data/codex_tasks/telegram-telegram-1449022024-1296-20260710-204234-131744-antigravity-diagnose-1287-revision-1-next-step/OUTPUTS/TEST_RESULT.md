test_command: powershell -File E:\AgentOS\scripts\assert_governance_ready.ps1
test_result: PASS — 治理門檻檢查通過，狀態為 aligned。

test_command: powershell -NoProfile -ExecutionPolicy Bypass -File "data\tasks\fixtures\test_verify_prompt_verdict_injection.ps1"
test_result: FAIL — 執行結果包含 10 個 PASS 與 3 個 FAIL。長度檢查失敗（Got: 23, Expected: 12 等），證實 write_escalation.ps1 存在轉型空格 Bug。

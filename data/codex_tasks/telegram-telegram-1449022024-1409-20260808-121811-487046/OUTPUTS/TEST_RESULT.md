test_command: Get-Process -Name "rustdesk" -ErrorAction SilentlyContinue
test_result: FAIL — blocked, "requires approval" (no interactive approver in this dispatch session)
test_command: tasklist /FI "IMAGENAME eq rustdesk.exe" /V
test_result: FAIL — blocked, "This command requires approval"
test_command: tasklist
test_result: FAIL — blocked, "This command requires approval" (confirms block is not filter-specific)
test_command: sha256sum AGENTS.md
test_result: PASS — hash 0eaecf6d153925ac17b940992cc12ce82a6de5e7f1d7b766bab9c479c3088eb1 matches dispatch governance_hash
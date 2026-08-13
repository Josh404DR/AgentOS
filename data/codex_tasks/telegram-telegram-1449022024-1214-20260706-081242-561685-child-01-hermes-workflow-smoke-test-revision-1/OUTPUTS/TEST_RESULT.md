test_command: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\assert_governance_ready.ps1
test_result: FAIL — sandbox blocks nested powershell.exe process (line 19 of script: & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $syncScript). Identical failure in both original and revision sessions.
test_command: Read E:\AgentOS\data\governance\governance_status.json + apply assert_governance_ready.ps1 conditional logic (lines 25-76)
test_result: PASS
test_command: Read E:\AgentOS\data\governance\governance_status.json; apply assert_governance_ready.ps1 post-sync logic (lines 25-76)
test_result: PASS — governance_gate=passed, governance_status=aligned, governance_version=1.2.0, governance_hash=AD20E91AFB53EF06800077F420F8F441E57EEEA0E906794FF219E63F0FFE39C3, drift_count=0, task_execution_allowed=true
test_command: Read E:\AgentOS\data\routing\routing_cache.jsonl
test_result: PASS — 49 entries; most recent entry dated 2026-07-01T12:31:38 (URL_INTAKE). Queue is quiescent.
test_command: Read E:\AgentOS\data\escalations\ESCALATION_INDEX.jsonl
test_result: PASS — 11 entries, all status=awaiting_josh.
test_command: Read E:\AgentOS\data\workflow_control\CONTROL_EVENTS.jsonl
test_result: PASS — 15 entries; four dispatches in pause_requested since 2026-07-04T22:51; no resume events.
test_command: Read E:\AgentOS\data\metrics\METRICS_LOG.jsonl
test_result: PASS — 5 completed; 1 pending_verify (learning-collector-mvp).
test_command: Glob E:\AgentOS\data\queue\**\*
test_result: PASS — data\queue\ directory does not exist; no active queue artifacts.
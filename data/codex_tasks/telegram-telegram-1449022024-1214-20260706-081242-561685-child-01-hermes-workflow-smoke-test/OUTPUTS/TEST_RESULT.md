test_command: Read E:\AgentOS\data\governance\governance_status.json
test_result: PASS — governance_status=aligned, governance_version=1.2.0, canonical_hash=AD20E91AFB53EF06800077F420F8F441E57EEEA0E906794FF219E63F0FFE39C3, drift_count=0, checked_at=2026-07-06T08:16:36.7215996+08:00
test_command: Read E:\AgentOS\data\routing\routing_cache.jsonl
test_result: PASS — 49 entries; most recent entry dated 2026-07-01T12:31:38 (URL_INTAKE). No entries for parent dispatch telegram-telegram-1449022024-1214. Queue is quiescent.
test_command: Read E:\AgentOS\data\escalations\ESCALATION_INDEX.jsonl
test_result: PASS — 11 entries, all status=awaiting_josh. Most recent: telegram-telegram-1449022024-1216-20260706-081516-233034 (2026-07-06T08:15:23, risky_task, risk_rules_matched:external_write).
test_command: Read E:\AgentOS\data\workflow_control\CONTROL_EVENTS.jsonl
test_result: PASS — 15 entries. Last 4 events (2026-07-04T22:51) are pause_requested by Josh for dispatches: 1189, 1197, 1201, 1205. No resume events after that. Those four workflows remain paused.
test_command: Read E:\AgentOS\data\metrics\METRICS_LOG.jsonl
test_result: PASS — 5 completed tasks; 1 pending_verify (telegram-telegram-1449022024-1205-20260704-124313-811074-01-learning-collector-mvp).
test_command: Glob E:\AgentOS\data\queue\**\*
test_result: PASS — No files found. data\queue\ directory does not exist; no active queue artifacts.
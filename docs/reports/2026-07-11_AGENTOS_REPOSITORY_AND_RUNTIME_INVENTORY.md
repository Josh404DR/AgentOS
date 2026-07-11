# AgentOS Repository and Runtime Inventory

date: 2026-07-11 Asia/Taipei
status: evidence-backed inventory; no move, archive, deletion, commit, or push performed
governance_version: 1.2.0
governance_hash: A29DDC3DE4701A07BECCCB95E9A7DA9A3B897D2C1C60FAD61416C6C85EED666F

## Executive finding

AgentOS can pass its current deterministic CI smoke gate, but the repository is not ready for a two-computer pull/commit/push workflow. The local checkout has no Git remote, has a different history from the GitHub export, and mixes source files with a large volume of runtime artifacts. Moving scripts before introducing compatibility entrypoints would break scheduled tasks and hard-coded callers.

Current evidence:

- Governance gate: PASS and aligned.
- CI smoke: PASS, 0 failures, 0 warnings. Artifact: `data\ci_health\ci-smoke-20260711-010233.md`.
- Local Git: 2,747 tracked files, 50 modified/deleted entries, 1,641 untracked files.
- Local HEAD: `52873d68cb1e58f8a786aa1985a4262ddd0e4e95`; no `remote.origin.url`.
- GitHub `Josh404DR/AgentOS`: public, default branch `master`, current visible commit `ca497ec6fa5bcc1e5f3e7a3a5542b9618aa9ac0c` (`feat: initial AgentOS export - AI-readable snapshot 2026-07-08`). This is not the local HEAD history.
- `scripts` contains 52 executable PowerShell/Python/batch files and no Node `.js`/`.mjs` files. Node belongs to `dashboard\frontend`.
- No exact SHA-256 duplicate was found among files under `scripts`.

## Actual scheduled and running entrypoints

The following paths are externally bound and must remain stable until their scheduled tasks are deliberately migrated:

| Topic | Trigger | Bound path | Evidence on 2026-07-11 |
|---|---|---|---|
| Hermes main gateway | At logon | `scripts\start.ps1 -SkipProxy` | Task Ready; last result 0; Hermes gateway process running |
| Hermes Lite gateway | At logon | `scripts\start_hermes_lite.ps1` | Task Ready; last result 0; gateway process running |
| Dashboard | At logon | `dashboard\start.ps1 -NoBrowser` | Task Ready; last result 0, but ports 3000/8000 are currently down |
| NotebookLM conveyor | Scheduled/manual | `scripts\notebooklm_conveyor.ps1 -Mode DryRun` | Task Ready; last run 2026-07-05; result 0 |
| Legacy Hermes service | At logon/service task | external `Hermes_Gateway.cmd` | Task Ready; last result 15; separate from AgentOS start scripts |

No queue runner is registered as a persistent scheduled task. `start_task_queue.ps1` is an event-triggered background launcher.

## Script classification

The target structure below is a classification, not an authorization to move files. Phase 1 should keep root-level compatibility wrappers for every externally referenced entrypoint.

### Governance and CI

- `agentos_ci_smoke.ps1`: deterministic repository/workflow smoke gate.
- `assert_governance_ready.ps1`: fail-closed governance gate.
- `sync_shared_governance.ps1`: drift scan and owner-approved baseline update.
- `sync_shared_governance.ps1.bak-2026-07-10`: backup candidate; not an active executable.

### Workflow and queue

- `classify_task.ps1`: deterministic task classification.
- `dispatch_task_packet.ps1`: worker dispatcher and artifact collector.
- `local_file_task_worker.ps1`: creates and routes local-file task packets.
- `task_queue_runner.ps1`: deterministic queue state machine.
- `start_task_queue.ps1`: per-root background queue launcher.
- `workflow_supervisor.ps1`: dependency/escalation completion supervisor.
- `write_escalation.ps1`: escalation artifact writer.
- `decide_escalation.ps1`: records Josh's decision.
- `write_task_metric.ps1`: append-only completion metrics.
- `set_workflow_control.ps1`: workflow control state writer.
- `promote_draft.ps1`: approved draft-to-task promotion.

### Hermes runtime and maintenance

- `start.ps1`: main Hermes gateway/proxy/watchdog entrypoint.
- `start_hermes_lite.ps1`: Lite gateway entrypoint.
- `register_hermes_autostart.ps1`: registers main AtLogOn task.
- `register_hermes_lite_autostart.ps1`: registers Lite AtLogOn task.
- `setup_hermes.ps1`: setup helper.
- `test_hermes.ps1`: basic Hermes test/setup wrapper.
- `watchdog.ps1`: legacy gateway watchdog; stale design per Fable5 report.
- `memory_guard.ps1`: memory pressure monitor.
- `model_fallback.ps1`: model availability/fallback helper.
- `deploy_hermes_typed_dispatch_plugin.ps1`: manual plugin deployment.
- `sync_hermes_system_prompt.ps1`: prompt mirror helper with no active script caller.

### Dispatch bridges and fallback workers

- `hermes_claude_bridge.ps1`: legacy/live Claude bridge.
- `hermes_codex_bridge.ps1`: legacy/live Codex bridge.
- `hermes_tripartite_bridge.ps1`: legacy tripartite bridge.
- `invoke_antigravity_subagent.ps1`: governed Antigravity worker invocation.
- `poll_antigravity_worker.ps1`: Antigravity queue poller.
- `send_task_to_antigravity.ps1`: manual Antigravity sender.
- `free_model_window.ps1`: low-cost provider routing window.

### Intake and publishing

- `typed_dispatch.ps1`: deterministic typed router.
- `telegram_typed_dispatch_entry.ps1`: Telegram wrapper.
- `threads_url_intake.ps1`: Threads intake orchestration.
- `url_intake_task_packet.ps1`: URL task packet creator.
- `url_intake_worker.ps1`: URL fetch/analysis worker.
- `publish_url_knowledge.ps1`: publishes completed knowledge nodes.

### Knowledge and exports

- `notebooklm_conveyor.ps1`: NotebookLM export/sync pipeline.
- `register_notebooklm_conveyor_task.ps1`: conveyor scheduler registration.
- `export_notebooklm_sources.ps1`: source bundle export.
- `sync_notebooklm.py`: NotebookLM synchronization client.
- `export_obsidian_view_nodes.ps1`: Obsidian export wrapper.
- `export_obsidian_view_nodes.py`: Obsidian export implementation.
- `collect_learning_candidates.ps1`: learning candidate collector.

### Monitoring, usage, and evaluation

- `agentos_health_check_noagent.py`: deterministic health report.
- `daily_token_cost_summary_noagent.py`: daily token/cost report.
- `hermes_usage_audit.py`: manual Hermes usage audit; no static caller found.
- `monitor_ui.py`: legacy/manual monitor UI; no static caller found.
- `ollama_practical_eval.ps1`: manual model evaluation.
- `ollama_speed_eval.ps1`: manual speed evaluation.

### Utilities and standalone tools

- `env_manager.py`: environment variable helper.
- `replicate_to_machine2.ps1`: legacy machine-2 replication helper.
- `fan_control\main.py`, `fan_control\run.bat`: standalone fan control tool.

## Archive and deletion candidates

These are candidates only. None were moved or deleted.

### High-confidence archive candidates

- `scripts\sync_shared_governance.ps1.bak-2026-07-10`
- `docs\claude_ops\00_DIAGNOSIS.md.bak-2026-07-09`
- `docs\claude_ops\10_DISPATCH_RULES.md.bak-2026-07-09`
- `docs\claude_ops\30_DELEGATION_TEMPLATES.md.bak-2026-07-09`
- `docs\claude_ops\30_DELEGATION_TEMPLATES.md.bak-2026-07-09-r2`
- `docs\claude_ops\35_COLLAB_PROMPT.md.bak-2026-07-09`
- `docs\claude_ops\40_MAINTENANCE_PROTOCOL.md.bak-2026-07-09`
- `docs\claude_ops\90_LETTER_TO_FUTURE_SESSIONS.md.bak-2026-07-09`
- `docs\temp_routing_rules.txt`
- `docs\overnight_report.md`
- `docs\antigravity_commands\*.txt` should become historical machine setup receipts, not active governance.

Proposed destination: `archive\docs\2026-07-pre-cleanup\` and `archive\scripts\2026-07-pre-cleanup\`, accompanied by a manifest containing original path, hash, reason, dependency evidence, restore command, and approval date.

### Needs dependency or owner decision before archive

- `hermes_claude_bridge.ps1`, `hermes_codex_bridge.ps1`, `hermes_tripartite_bridge.ps1`: likely legacy connectivity flows, but still governance-tracked and referenced by historical docs.
- `watchdog.ps1`: known stale design, but `start.ps1 -StartWatchdog` still calls it.
- `sync_hermes_system_prompt.ps1`: no active caller, but may be retained as a deployment action.
- `deploy_hermes_typed_dispatch_plugin.ps1`: manual-only, but still the main gateway deployment fallback.
- `monitor_ui.py`, `hermes_usage_audit.py`, `env_manager.py`, both Ollama evaluators: no active static callers does not prove they are unused manual tools.
- `replicate_to_machine2.ps1`: should be superseded by Git, but only after the two-computer workflow is proven.

No deletion candidate is currently evidence-complete. Archive first; delete only in a later, separately approved retention pass.

## Documentation classification

Proposed stable layout:

- `docs\governance\`: binding contracts and risk rules only.
- `docs\architecture\`: architecture, memory, routing, evidence contracts.
- `docs\operations\`: startup, scheduler, CI smoke, NotebookLM, intake, setup status.
- `docs\roadmap\`: planned work and product roadmaps.
- `docs\reports\`: dated audits, evaluations, landing reports, and snapshots.
- `docs\historical\` should not be created; historical material belongs under root `archive\docs\...`.
- `docs\claude_ops\`: keep as a governed role-specific handbook until its rules are reconciled into canonical governance. Backup copies should leave this dynamically governed directory.

## Dashboard evidence

The dashboard is currently down on both ports 3000 and 8000 despite the scheduled task reporting result 0.

The backend log shows Uvicorn was launched with reload mode, detected changes in `check_db.py` and `main.py`, began shutdown, then waited for open WebSocket/background tasks. `dashboard\start.ps1` uses `uvicorn ... --reload` for the AtLogOn runtime. Development reload mode is therefore a concrete availability risk for the scheduled production-like dashboard.

The user's product observations are supported by code:

- Usage is not provider quota. `/api/usage` sums Hermes `state.db`; context percentage is only the latest session's token estimate and includes cache reads. It cannot accurately report Claude/Codex/Antigravity account quota.
- `TaskBoard` and `TaskUniverse` are both mounted as separate top-level views and overlap in task visibility.
- `HermesChat` directly calls Groq with a system prompt that explicitly says it has no tools. It is not RAG and cannot answer live task-status questions reliably.
- `LiveLogs` streams role log files. It does not reconstruct worker-to-worker decisions or a dispatch event chain.

The existing observability roadmap correctly proposes a deterministic runtime registry, heartbeats, event chain, failure taxonomy, and degraded frontend states. Its current governance hash is older than the active baseline and its second fresh verification is still pending, so it should be treated as design input rather than implementation authority.

## Immediate blockers before physical reorganization

1. Decide how to reconcile the unrelated local and GitHub histories.
2. Define the source/runtime boundary and strengthen `.gitignore` before creating the clean baseline.
3. Add a script registry and compatibility wrappers before moving any bound script.
4. Repair dashboard lifecycle behavior before relying on it as the process manager UI.
5. Approve exact archive manifests before moving backup or historical files.

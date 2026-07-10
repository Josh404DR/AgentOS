# Script Directory

`config/script_registry.json` is the canonical inventory. Root-level scripts are stable compatibility entrypoints while category migrations proceed one batch at a time.

| Category | Purpose | Scripts |
| --- | --- | --- |
| `entrypoints` | Guarded human commands for two-machine Git work | `agentos-work-start`, `agentos-check`, `agentos-work-finish` |
| `governance` | Baseline, readiness, and repository gates | `assert_governance_ready`, `repository_hygiene_check`, `sync_hermes_system_prompt`, `sync_shared_governance` |
| `workflow` | Classification, dispatch, queue, supervision, escalation, metrics | `classify_task`, `decide_escalation`, `dispatch_task_packet`, `promote_draft`, `set_workflow_control`, `start_task_queue`, `task_queue_runner`, `typed_dispatch`, `workflow_supervisor`, `write_escalation` |
| `runtimes` | Hermes and AgentOS lifecycle | `register_hermes_autostart`, `register_hermes_lite_autostart`, `start`, `start_hermes_lite`, `watchdog` |
| `workers` | Claude, Codex, Antigravity, and provider bridges | `free_model_window`, `hermes_claude_bridge`, `hermes_codex_bridge`, `hermes_tripartite_bridge`, `invoke_antigravity_subagent`, `model_fallback`, `poll_antigravity_worker`, `send_task_to_antigravity` |
| `intake` | Local, Telegram, URL, and Threads intake | `local_file_task_worker`, `telegram_typed_dispatch_entry`, `threads_url_intake`, `url_intake_task_packet`, `url_intake_worker` |
| `knowledge` | NotebookLM, Obsidian, URL publishing, and learning | `collect_learning_candidates`, `export_notebooklm_sources`, both `export_obsidian_view_nodes` files, `notebooklm_conveyor`, `publish_url_knowledge`, `register_notebooklm_conveyor_task`, `sync_notebooklm` |
| `observability` | CI, health, usage, metrics, and monitor views | `agentos_ci_smoke`, `agentos_health_check_noagent`, `daily_token_cost_summary_noagent`, `hermes_usage_audit`, `monitor_ui`, `write_task_metric` |
| `maintenance` | Setup, deployment, environment, evaluation, and replication | `deploy_hermes_typed_dispatch_plugin`, `env_manager`, `memory_guard`, both `ollama_*_eval`, `replicate_to_machine2`, `setup_hermes`, `test_hermes` |
| `standalone` | Utilities outside the AgentOS runtime | `fan_control/main.py`, `fan_control/run.bat` (disabled by default) |

Do not invoke an internal category path until its root wrapper and all callers have migrated in the same tested change set.

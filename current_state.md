# AgentOS Current State Snapshot
Last Updated: 2026-06-24 23:40 Asia/Taipei

## Status Overview (Evidence-Based)

### 1. Memory Layer Architecture (V2)
- **Architecture Setup**: `verified_by_codex`
- **Hermes Memory Pruning**: `claimed_by_hermes`
- **Source of Truth**: AgentOS local files.

### 2. NotebookLM Integration
- **Local Export Package**: `verified_by_codex`
- **Sync Tool**: `tracked` (`scripts\sync_notebooklm.py`)
- **Dry Run**: `verified_by_codex`
- **Fresh Notebook Sync Test**: `verified_by_audit_log` (Executed 2026-06-23)
- **Fresh Notebook Title**: `AgentOS_Fresh_Sync_Test_20260623_2320`
- **Fresh Notebook ID**: `79ef4683-f7d2-43da-b8d3-7298858949e5`
- **Source Count After Sync**: 12
- **Remote Sync**: `verified_fresh_notebook`
- **NotebookLM Role**: Layer 3 (Retrieval-Only, not Source of Truth)
- **Sync/Cleanup Decoupling**: `true` (Cleanup does not depend on Sync)

### 3. Device Maintenance Project
- **Project Index**: `data\projects\device_maintenance.md`
- **Fan Control Utility**:
  - `fan_control_code_landed=true`
  - `run_bat_resolution_strategy_added=true`
  - `windowsapps_shim_avoided=true`
  - `dependency_preflight_done=true`
  - `dependency_install_executed=false`
  - `recommended_FAN_CONTROL_PYTHON=C:\Users\brian\AppData\Local\Programs\Python\Python310\python.exe`
  - `dependency_status=ready_with_python310`
  - `runner_with_FAN_CONTROL_PYTHON=verified_by_codex`
  - `sensor_status=temperature_unavailable_on_host`
  - `enable_max_executed=false`
  - `enable_max_unattended=false`
  - `final_status=partial_sensor_unavailable`
  - **Notes**: Dependencies are available when using Python 3.10. The `status` action executes correctly but fails to read CPU temperature on this host. Due to sensor unavailability, the tool is not considered fully ready. Automatic execution of `enable_max` is prohibited.
- **Memory Guard**: `scripts\memory_guard.ps1`
- **Overall Status**: `internal_maintenance_tools_active` (Partial: Fan Control depends on environment setup)

### 4. Evidence Cleanup
- **Evidence Cleanup Status**:
  - `manifest_created=true`
  - `manifest_verified_by_codex=true`
  - `drift_check_performed=true`
  - `independent_codex_evidence_found=true`
  - `drift_report_path=data\codex_tasks\2026-06-24-independent-agent-verification\OUTPUTS\CODEX_RAW_DRIFT_LOG.md`
  - `cleanup_executed=false`
  - `approval_required_before_cleanup=true`

### 5. Governance and Reporting
- **Unified Evidence Contract**:
  - `unified_evidence_contract_created=true`
  - `status_labels_authoritative=true`
  - `josh_message_classification_required=true`
  - `resource_contribution_summary_required=true`
  - `production_ready=false`

### 6. Risk and Security Review
- **Script Review Status**:
  - `scrape_upwork_risk=high_tos_violation`
  - `env_manager_risk=medium_plaintext_secrets`
  - `monitor_ui_risk=low`
  - `independent_claude_evidence_found=true`
  - `review_report_path=data\codex_tasks\2026-06-24-independent-agent-verification\OUTPUTS\CLAUDE_RAW_RISK_LOG.md`
  - `attribution_status=verified`

### 6. Agent Coordination
- **Autonomous Coordination Mode**:
  - `no_human_relay_default=true`
  - `hermes_coordinates_codex_claude_directly=true`
  - `use_existing_bridge_scripts=true`
  - `josh_contact_only_for_approval_or_blocker=true`
  - `new_queue_or_database_created=false`
- **Resource Allocation Reporting**:
  - `resource_contribution_summary_required_for_multi_agent_tasks=true`
  - `subscription_resources_codex_claude_should_be_used_for_suitable_work=true`
  - `gemini_api_metered_usage_should_be_minimized_when_lower_cost_resources_fit=true`
  - `usage_estimates_must_be_labeled=true`
- **Cost-Saving Routing Protocol**:
  - `typed_dispatch_protocol_v0_1=true`
  - `prompt_pack_v0_1=true`
  - `gemini_api_mode=frozen_for_routine_work`
  - `premium_gemini_requires_TYPE_GEMINI_PREMIUM_or_explicit_approval=true`
  - `routing_cache_path=data\routing\routing_cache.jsonl`
  - `budget_state_path=data\routing\budget_state.json`
  - `hermes_should_assemble_prompts_not_improvise=true`
  - `typed_dispatch_runner=scripts\typed_dispatch.ps1`
  - `telegram_typed_dispatch_entry=scripts\telegram_typed_dispatch_entry.ps1`
  - `typed_dispatch_dry_run_verified=true`
  - `typed_dispatch_models_invoked=false`
  - `typed_dispatch_test_routes=CODEX_VERIFY,CLAUDE_REVIEW,GEMINI_PREMIUM_BLOCK`
  - `telegram_runtime_hooked=enabled_for_next_session`
  - `telegram_hook_requires_josh_approval=false`
  - `telegram_hook_plugin=agentos-typed-dispatch`
  - `telegram_hook_path=C:\Users\brian\AppData\Local\hermes\plugins\agentos-typed-dispatch`
  - `telegram_hook_type=pre_gateway_dispatch`
  - `telegram_hook_local_smoke_verified=true`
  - `telegram_hook_plain_messages_allow=false_replaced_by_lite_chat`
  - `telegram_hook_typed_messages_skip_model_dispatch=true`
  - `telegram_hook_plain_messages_lite_chat=true`
  - `telegram_hook_plain_messages_skip_full_hermes_agent=true`
  - `telegram_hook_lite_chat_provider=groq_via_free_model_window`
  - `telegram_hook_lite_chat_tools_invoked=false`
  - `telegram_hook_lite_chat_identity=Hermes Lite`
  - `telegram_hook_lite_chat_role=AgentOS Telegram intake and routing voice`
  - `telegram_hook_lite_chat_utf8_fix_pending_gateway_restart=true`
  - `telegram_hook_lite_chat_response_base64_enabled=true`
  - `free_model_window_raw_utf8_response_decode=true`
  - `hermes_lite_cannot_claim_routing_without_artifact=true`
  - `hermes_lite_link_summary_requires_typed_dispatch=true`
  - `hermes_lite_url_auto_intake_enabled=true`
  - `hermes_lite_url_auto_intake_type=URL_INTAKE`
  - `hermes_lite_url_auto_intake_route_to=Codex`
  - `hermes_lite_url_auto_task_packet_created=true`
  - `hermes_lite_url_auto_task_packet_script=scripts\url_intake_task_packet.ps1`
  - `hermes_lite_url_auto_worker_script=scripts\url_intake_worker.ps1`
  - `hermes_lite_url_auto_worker_status_field=codex_execution_status`
  - `hermes_lite_url_auto_worker_success_status=completed`
  - `hermes_lite_url_auto_task_packet_external_access=false`
  - `hermes_lite_url_auto_intake_models_invoked=false`
  - `hermes_lite_url_auto_intake_external_services_invoked=false`
  - `hermes_gateway_restarted_after_url_intake_hook=true`
  - `telegram_hook_slash_commands_allow=true`
  - `telegram_hook_live_gateway_restart_required=false`
  - `telegram_hook_live_gateway_restarted=true`
  - `telegram_hook_live_gateway_restarted_at=2026-06-25 00:16 Asia/Taipei`
  - `telegram_hook_live_verified=true`
  - `telegram_hook_live_verified_at=2026-06-25 00:23 Asia/Taipei`
  - `telegram_hook_live_verified_dispatch_id=telegram-telegram-1449022024-923-20260625-002300`
  - `telegram_hook_live_verified_models_invoked=false`
  - `telegram_hook_live_verified_external_services_invoked=false`
  - `telegram_hook_reply_path_fixed=true`
  - `telegram_hook_pre_restart_live_test_api_calls=1`
  - `telegram_hook_async_bug_fixed=true`
  - `telegram_hook_sync_return_verified=true`
  - `telegram_hook_sync_return_result=action_skip`
  - `telegram_hook_models_invoked_in_smoke=false`
  - `cost_risk_cron_daily_token_summary_hits_gemini=true`
  - `hermes_model_alias_ollama_fixed=true`
  - `hermes_model_alias_runtime=C:\Users\brian\AppData\Local\hermes`
  - `hermes_model_alias_ollama=qwen3.5:9b via custom http://localhost:11434/v1`
  - `hermes_model_alias_local=qwen3.5:9b via custom http://localhost:11434/v1`
  - `hermes_model_alias_llama_local=llama3.2:3b via custom http://localhost:11434/v1`
  - `hermes_gateway_restarted_after_model_alias_fix=true`
  - `free_cloud_window_policy_created=true`
  - `free_cloud_window_candidates=groq,openrouter`
  - `free_cloud_window_guard=config\free_model_providers.json,scripts\free_model_window.ps1`
  - `free_cloud_window_default_daily_request_cap=30`
  - `free_cloud_window_paid_models_allowed=false`
  - `free_cloud_window_paid_tools_allowed=false`
  - `free_cloud_window_auto_top_up_allowed=false`
  - `free_cloud_window_fallback_to_gemini=false`
  - `free_cloud_window_dry_run_verified=true`
  - `free_cloud_window_live_invocation_enabled=true_guarded_only`

### 7. Ollama Practical Model Evaluation
- **Evaluation Status**:
  - `ollama_practical_eval_completed=true`
  - `ollama_eval_primary_run=data\ollama_eval\2026-06-26-practical`
  - `ollama_eval_nothink_run=data\ollama_eval\2026-06-26-practical-nothink`
  - `ollama_eval_report=docs\OLLAMA_MODEL_PRACTICAL_EVALUATION.md`
  - `ollama_scorecard=data\ollama_eval\2026-06-26-practical\MODEL_SCORECARD.json`
- **Routing Recommendation**:
  - `ollama_default_structured_worker=qwen2.5-coder:7b`
  - `ollama_evidence_draft_worker=qwen3:8b`
  - `ollama_qwen_thinking_models_require_think_false=true`
  - `ollama_llama3_2_3b_role=trivial_formatting_only`
  - `ollama_final_authority_allowed=false`
  - `free_cloud_window_live_test_verified=true`
  - `free_cloud_window_groq_live_test=completed`
  - `free_cloud_window_openrouter_live_test=completed`
  - `free_cloud_window_usage_counter_fixed=true`
  - `free_cloud_window_usage_today_path=data\routing\free_model_usage_2026-06-25.json`
  - `free_cloud_window_usage_today=groq:1,openrouter:1`
  - `hermes_model_alias_groq_added=true`
  - `hermes_model_alias_openrouter_free_added=true`
  - `hermes_model_alias_groq_base_url=https://api.groq.com/openai`
  - `hermes_model_alias_openrouter_base_url=https://openrouter.ai/api`
  - `hermes_model_alias_custom_endpoint_listing_fix=true`
  - `hermes_free_window_user_providers_added=agentos-groq,agentos-openrouter-free`
  - `hermes_free_window_aliases_use_key_env=true`
  - `hermes_free_window_switch_warning_resolved_by_core_check=true`
  - `hermes_gateway_restarted_after_free_window_aliases=true`
  - `hermes_live_model_status_hotfix_applied=true`
  - `hermes_live_model_status_runtime=C:\Users\brian\AppData\Local\hermes\hermes-agent\gateway\run.py`
  - `hermes_live_model_status_no_switch=true`
  - `hermes_gateway_restarted_after_model_status_hotfix=true`
  - `groq_full_hermes_agent_blocked_by_tpm=true`
  - `groq_full_hermes_agent_tpm_limit=6000`
  - `groq_full_hermes_agent_requested_tokens_approx=21000`
  - `plain_chat_lite_hook_restarted=true`
  - `hermes_lite_identity_patch_applied=true`
  - `hermes_default_chat_switched_to_free_window=false`
  - `kimi_api_automation=deferred_not_verified_free`
  - `cloudflare_workers_ai_automation=deferred_not_guaranteed_zero_cost`
  - `daily_token_cost_summary_cron_throttled=true`
  - `daily_token_cost_summary_cron_mode=no_agent`
  - `daily_token_cost_summary_script=scripts\daily_token_cost_summary_noagent.py`
  - `daily_token_cost_summary_hermes_script=C:\Users\brian\AppData\Local\hermes\scripts\daily_token_cost_summary_noagent.py`
  - `daily_token_cost_summary_models_invoked=false`
  - `daily_token_cost_summary_no_change_silent=true`
  - `daily_token_cost_summary_throttle_verified=true`
  - `typed_dispatch_hook_skip_verified_from_installed_plugin=true`
  - `cursor_owned_external_analysis_artifacts=PROJECT_ANALYSIS.md,RECOMMENDATIONS.md`
  - `cursor_owned_artifacts_non_cursor_editing_allowed=false`
  - `cursor_owned_artifacts_cleanup_policy=keep_external_cursor_owned`

### 7. Role File Hygiene
- **Role Definitions**:
  - `codex_role_mojibake_cleaned=true`
  - `codex_dual_mode_documented=true`
  - `claude_review_rating_disambiguated=true`
  - `routing_plan_date_updated=true`

---

## Codex Handoff & Memory
*Note: This section is for Codex Desktop to understand the system state.*

1. **Truth resides in Files**: Always read `docs\MEMORY_ARCHITECTURE.md`.
2. **Fan Control Runner**: Use `scripts\fan_control\run.bat`. It tries `py -3.13`, then `py`. If failing, set `FAN_CONTROL_PYTHON`.
3. **Git Hygiene**: Strict rule - Never use `git add .`. Add specific files only.

## Key Documentation Index
- **Memory Protocol**: `docs\MEMORY_ARCHITECTURE.md`
- **Core Memory**: `data\memory\HERMES_CORE_MEMORY.md`
- **Device Maintenance**: `data\projects\device_maintenance.md`
- **Progress History**: `progress_log.md`
- **Architecture**: `docs\ARCHITECTURE.md`
- **Cost-Saving Routing**: `docs\COST_SAVING_ROUTING_PROTOCOL.md`
- **Prompt Pack**: `prompts\`
- **Typed Dispatch Runner**: `scripts\typed_dispatch.ps1`
- **Telegram Typed Dispatch Handoff**: `docs\TELEGRAM_TYPED_DISPATCH_HANDOFF.md`
- **Sync Logs**: `data\memory\sync_logs\`

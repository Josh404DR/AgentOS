# AgentOS MEMORY

- generated_at: 2026-07-05 11:36:06 +08:00
- source_of_truth: local_git
- notebooklm_role: human_auxiliary_retrieval
- exclusive_definition: Compact current state and maintained Agent memory indexes; raw transcripts and task evidence are excluded.
- source_count: 4

---

## Source: current_state.md

# AgentOS Current State Snapshot
Last Updated: 2026-06-24 23:40 Asia/Taipei

> Governance notice (2026-06-30): This is a dated snapshot and some fields
> below are historical. Cross-window rules come from `E:\AgentOS\AGENTS.md`.
> Fresh evidence overrides stale fields here. Telegram plugin versions and
> restart claims must be verified live instead of copied from this snapshot.

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
- **NotebookLM Conveyor**:
  - `notebooklm_conveyor_created=true`
  - `notebooklm_conveyor_doc=docs\NOTEBOOKLM_CONVEYOR.md`
  - `notebooklm_export_script=scripts\export_notebooklm_sources.ps1`
  - `notebooklm_conveyor_script=scripts\notebooklm_conveyor.ps1`
  - `notebooklm_scheduler_script=scripts\register_notebooklm_conveyor_task.ps1`
  - `notebooklm_conveyor_schedule=03:30_daily`
  - `notebooklm_conveyor_scheduled_mode=DryRun`
  - `notebooklm_conveyor_live_schedule_blocked_by_policy=true`
  - `notebooklm_conveyor_manual_live_command=powershell -ExecutionPolicy Bypass -File scripts\notebooklm_conveyor.ps1 -Mode Live`
  - `notebooklm_conveyor_dry_run_verified=true`
  - `notebooklm_conveyor_export_source_count=43`
  - `notebooklm_conveyor_dry_run_discovered_markdown=44`
  - `notebooklm_conveyor_models_invoked=false`
  - `notebooklm_conveyor_external_upload_from_schedule=false`

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
  - `telegram_hook_plugin_version=0.3.4`
  - `telegram_hook_sync_callback_compatibility_fixed=true`
  - `telegram_hook_reply_adapter_chat_id_fixed=true`
  - `telegram_hook_dispatch_id_single_source=true`
  - `telegram_hook_evidence_flag_verified=true`
  - `telegram_hook_evidence_flag=telegram_hook_invoked:true`
  - `threads_url_intake_live_verified=true`
  - `threads_url_intake_live_verified_at=2026-06-29 19:54 Asia/Taipei`
  - `threads_url_intake_live_dispatch_id=telegram-telegram-1449022024-1098-20260629-195400-149955`
  - `threads_url_intake_fetch_status=success`
  - `threads_url_intake_codex_execution_status=completed`
  - `threads_url_intake_models_invoked=codex_cli_only`
  - `threads_url_intake_openrouter_or_groq_invoked=false`
  - `generic_url_intake_live_verified=true`
  - `generic_url_intake_live_dispatch_id=telegram-telegram-1449022024-1103-20260629-200436-873483`
  - `generic_url_intake_mode=metadata_only_unfetched_triage`
  - `generic_url_intake_source_not_verified=true`
  - `github_url_specialist_worker_status=planned_not_implemented`
  - `github_url_planned_flow=retrieval_worker_then_codex_then_optional_claude_review`
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
  - `ollama_speed_eval_completed=true`
  - `ollama_speed_eval_run=data\ollama_eval\2026-06-26-speed-nothink`
  - `ollama_speed_eval_report=docs\OLLAMA_SPEED_EVALUATION.md`
- **Routing Recommendation**:
  - `ollama_default_structured_worker=qwen2.5-coder:7b`
  - `ollama_fastest_formatter=llama3.2:3b`
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

---

## Source: data\memory\HERMES_CORE_MEMORY.md

# Hermes Core Memory

Last updated: 2026-06-23

This is the compact memory Hermes should keep. It is a pointer set, not a full project summary.

- AgentOS root: `E:\AgentOS`
- Memory architecture: `docs\MEMORY_ARCHITECTURE.md`
- Source index for NotebookLM: `data\memory\NOTEBOOKLM_SOURCE_INDEX.md`
- Routing plan: `docs\AGENT_ROUTING_PLAN.md`
- Resource inventory: `docs\RESOURCE_INVENTORY.md`
- Reporting rules: `docs\HERMES_REPORTING_PRINCIPLES.md`
- Architecture source of truth: `docs\ARCHITECTURE.md`
- Progress log: `progress_log.md`

Core role boundaries:

- Hermes: coordinator, operator interface, planner, monitor, notes curator, proposal coordinator.
- Codex: code/file execution specialist. Use for repo reads, edits, scripts, tests, and `OUTPUTS\RESULT.md`.
- Claude: inspector/reviewer. Use for risk review, architecture review, and second-pass critique when justified.
- Gemini: high-quality reasoning and planning, but rate-limit and spend must be protected.
- Ollama: local low-cost triage only. Use for simple classification, format checks, and low-risk summaries. Do not use as full Hermes brain for long tasks until proven.

Hard rules:

- Do not contact clients without Josh approval.
- Do not restore quarantined Hermes install scripts.
- Do not run remote PowerShell installer one-liners unless Josh explicitly approves after manual diff and security review.
- Do not delete evidence folders without Josh approval.
- Do not claim production readiness from a single smoke test.
- Label unverified self-reports as `claimed_by_hermes`.

Cost and context rule:

- Use `/cost` before long work.
- If `/cost` reports `HIGH_RISK`, summarize current state, start `/new`, and route low-risk work away from Gemini.
- Do not store routine checkpoint reports in Hermes memory. Write them to AgentOS files instead.

NotebookLM rule:

- NotebookLM is a retrieval layer, not source of truth.
- Feed NotebookLM curated AgentOS files from `data\memory\NOTEBOOKLM_SOURCE_INDEX.md`.
- Keep AgentOS files canonical.
- **Tooling**: `E:\AgentOS\scripts\sync_notebooklm.py`.
- **CRITICAL**: On Windows, always sync as `--type text` instead of `--type file` to avoid corrupted source errors (red status).
- **Active DB**: `AgentOS_Central_Memory_v2` (ID: `9af31a16-7984-428a-85ff-2d648d858560`).

---

## Source: data\memory\NOTEBOOKLM_SOURCE_INDEX.md

# NotebookLM Source Index

Last updated: 2026-06-23

Purpose: define which AgentOS files should be uploaded or exported into NotebookLM when Josh starts the NotebookLM memory layer.

NotebookLM is a retrieval layer. AgentOS files remain the canonical source of truth.

## Priority 1: Core Operating Memory

Upload these first:

- `docs\MEMORY_ARCHITECTURE.md`
- `data\memory\HERMES_CORE_MEMORY.md`
- `docs\ARCHITECTURE.md`
- `current_state.md`
- `docs\AGENT_ROUTING_PLAN.md`
- `docs\RESOURCE_INVENTORY.md`
- `docs\HERMES_REPORTING_PRINCIPLES.md`
- `agents\roles\hermes.md`
- `agents\roles\codex.md`
- `agents\roles\claude.md`
- `agents\roles\gemini.md`

## Priority 2: Workflow Knowledge

Upload after Priority 1:

- `workflows\ai_freelancer_os.md`
- `workflows\hermes_to_codex.md`
- `docs\PRE_FLIGHT_TEST_PLAN.md`
- `docs\24H_STABILITY_MONITOR_PLAN.md`
- `docs\EVIDENCE_HYGIENE_PLAN.md`
- `docs\SECURITY_REVIEW_AVIRA_INSTALL_PS1.md`

## Priority 3: Usage and Cost Evidence

Upload only the latest relevant reports:

- Latest `data\usage\hermes_usage_audit_*.md`
- Latest `data\usage\YYYY-MM-DD.md`
- `data\usage\TEMPLATE.md`

## Priority 4: Case Knowledge

Upload selectively:

- `data\leads\YYYY-MM-DD.md`
- `data\screening\screening_log.md`
- `data\proposals\*.md`
- Finished Codex task `TASK.md` and `OUTPUTS\RESULT.md` pairs

## Exclude By Default

Do not upload these unless Josh explicitly asks:

- Raw `data\live_bridge\*` folders.
- Failed or duplicate bridge-test artifacts.
- Raw full `progress_log.md` if it becomes too large; use curated summaries instead.
- `HERMES_NOTES.md` until the mojibake-corrupted sections are repaired or extracted into a clean file.
- Quarantined or deleted installer scripts.
- Any secrets, tokens, `.env` files, private keys, or browser/session state.

## NotebookLM Use Cases

Good uses:

- Ask "what did we decide about Hermes/Codex/Claude routing?"
- Summarize role boundaries.
- Find prior risk decisions.
- Retrieve lead/proposal patterns.
- Compare current tasks against previous lessons.

Bad uses:

- Treat NotebookLM as an execution engine.
- Treat NotebookLM output as verified without checking source files.
- Use NotebookLM to replace Git history or AgentOS docs.

---

## Source: HERMES_NOTES.md

# Hermes 點子庫 — 跨任務洞察與決策記錄

更新方式：附加寫入，不覆蓋，每筆記錄標註日期與來源。

---

## 2026-06-17
Source: Josh / prior AgentOS testing notes

### [測試結論] AgEnD 系統穩定性
- AgEnD 對長任務會靜默失敗（no-op），不留任何錯誤記錄。
- 短任務分段注入成功率明顯高於一次性長提示。
- 結論：目前不適合用 AgEnD 跑正式客戶任務，定位為受控沙盒實驗場。

### [測試結論] 提示詞才是穩定性的真正來源
- 三輪測試（含拿掉治理文件、拿掉身份背景）結果幾乎一致。
- 篩選準確度主要來自三條具體標準 + 強制階段化紀律格式。
- 結論：不需要依賴特定框架或治理文件，提示詞寫得夠具體就能穩定複製。

### [架構缺口] 現有正式系統三個最大洞
- Task Runner 後面缺執行器（只準備不執行）。
- Delivery Package 驗證是橡皮章（只查檔案存在不查內容）。
- SQLite 狀態跟 task_state.json 狀態用詞不一致，需人工對齊。

### [商業模式] 過程展示型免費試做平台
- 免費展示的是決策過程（為什麼選這個案子、踩了什麼坑）。
- 最終可部署的成果才是付費解鎖的部分。
- 不是刻意做殘缺版，是誠實分開「過程透明」與「成果交付」。
- 每次免費試做即使不成交，決策記錄都會累積進案例庫。

### [待驗證] 三個 agent 分工的交接機制
- 找案源 → 準備 → 執行三層之間，狀態交接格式還沒定案。
- 待確認：是靠檔案傳遞、資料庫欄位，還是靠 Hermes 中介觀察。

---

## 2026-06-23
Source: Hermes / Checkpoint 01-10 Stabilization Phase

### [測試結論] 三智體協議編碼邊界
- 在 Windows 環境下，繁體中文摘要 (ZH-TW) 的 Mojibake 問題極其頑固。
- 結論：強制實施「ASCII 為唯一事實來源 (Canonical)」，中文摘要僅作為選用顯示層且必須具備自動回退機制。

### [風險提醒] CLI 進程殘留
- 觀察到 Claude CLI 在自動化呼叫後可能留下多個 `claude.exe` 駐留進程（目前維持在 9 個）。
- 結論：在進入生產環境前，需驗證進程是否會無限增長，必要時需加入 `taskkill` 清理邏輯。

### [架構缺口] 日誌 Token 成本通膨
- `progress_log.md` 的 Append-only 模式導致上下文加載成本隨時間線性增長（目前已達 ~10,000 Tokens/次）。
- 下一步：需設計「Log Archival / Snapshot」機制，將過往細節歸檔，僅保留精簡狀態摘要作為我的主要記憶區。

### [已解決] 主動協作驗證流
- 成功測試「Hermes 匯報 → Codex 驗證 → 共同提交」的自動化協作閉環，減少了 Operator 手動介入的負擔。
- 結論：此模式應作為未來 AgentOS 內部維護任務的標準 SOP。

## 2026-06-23
Source: Josh (via Telegram)

### [決策結論] AgentOS 中央知識彙整架構
- 決策：Hermes (Gemini) 應作為多渠道輸入（Telegram/LINE）的統一彙整點。
- 邏輯：不論訊息來源，Hermes 負責識別、提取並將其結構化寫入 `HERMES_NOTES.md`。
- 意義：確保 `HERMES_NOTES.md` 成為 AgentOS 的唯一事實來源（Single Source of Truth），避免知識碎片化。
- 下一步：建立 `data/inbox/` 目錄，作為 LINE 等其他接口的落地區，由 Hermes 定時掃描並歸檔。

---

## 2026-06-23
Source: Codex / Hermes Telegram model routing update

### [RESOLVED] Telegram model switch aliases
- Updated the external Hermes gateway implementation so `/model status` reports the current active model instead of trying to switch to a model named `status`.
- Added built-in short aliases for common routing lanes:
  - `/model gemini` and `/model gemini-flash` -> Gemini Flash preview lane for normal coordination.
  - `/model gemini-pro` -> Gemini Pro lane for harder reasoning.
  - `/model gemini-lite` -> Gemini Flash Lite lane for cheaper/lightweight work.
  - `/model ollama`, `/model local`, `/model qwen8b`, `/model qwen-local` -> local Ollama `qwen3:8b` at `http://localhost:11434/v1`.
- `/model status` intentionally reports token/rate-limit fields as `not_available_in_gateway` or `not_reported_by_provider` when Hermes has no reliable counter.
- Verification: Codex ran the focused Hermes test set and got `6 passed`.

### [RISK] Model status must not overclaim quota data
- Hermes can switch models at the gateway/session layer, but it does not yet have a reliable cross-provider token usage and remaining-rate-limit counter.
- Until that counter exists, reports must distinguish active model state from quota state.

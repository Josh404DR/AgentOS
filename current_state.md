# AgentOS Current State Snapshot
Last Updated: 2026-06-24 22:05 Asia/Taipei

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
  - `manifest_path=E:\AgentOS\data\codex_tasks\2026-06-24-evidence-cleanup-manifest\OUTPUTS\EVIDENCE_CLEANUP_MANIFEST.md`
  - `cleanup_executed=false`
  - `approval_required_before_cleanup=true`
  - `post_manifest_untracked_items=true`
  - `post_manifest_untracked_items_count=6`
  - `post_manifest_items_classified_by_codex=true`
  - `post_manifest_classification_path=data\codex_tasks\2026-06-24-post-manifest-incremental-classification\OUTPUTS\INCREMENTAL_CLASSIFICATION.md`
  - `post_manifest_items_require_review=true`
  - `notebooklm_sync_not_deletion_authority=true`
  - `classification_conservative=true`

### 5. Governance and Reporting
- **Unified Evidence Contract**:
  - `unified_evidence_contract_created=true`
  - `contract_path=docs\EVIDENCE_AND_REPORTING_CONTRACT.md`
  - `status_labels_authoritative=true`
  - `legacy_status_terms_deprecated=true`
  - `contract_precision_fix_applied=true`
  - `josh_message_classification_required=true`
  - `telegram_text_context_by_default=true`
  - `quoted_text_executable_only_when_explicit=true`
  - `changes_require_josh_approval=true`
  - `production_ready=false`

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
- **Sync Logs**: `data\memory\sync_logs\`

# AgentOS Current State Snapshot
Last Updated: 2026-06-23 19:30 Asia/Taipei

## Status Overview (Evidence-Based)

### 1. Memory Layer Architecture (V2)
- **Architecture Setup**: `verified_by_codex`
- **Hermes Memory Pruning**: `claimed_by_hermes`
- **Source of Truth**: AgentOS local files.

### 2. NotebookLM Integration
- **Local Export Package**: `verified_by_codex`
- **Sync Tool**: `tracked` (`scripts\sync_notebooklm.py`)
- **Dry Run**: `verified_by_codex`
- **Live Sync Preflight**: `done`
- **Fresh Notebook Sync Test**: `failed_auth_expired` (Executed 2026-06-23)
- **Sync Audit Log**: `data\memory\sync_logs\fresh_notebook_sync\notebooklm_fresh_sync_2026-06-23_214007.md`
- **Remote Sync**: `not_verified`
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

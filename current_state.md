# AgentOS Current State Snapshot
Last Updated: 2026-06-23 18:55 Asia/Taipei

## Status Overview (Evidence-Based)

### 1. Memory Layer Architecture (V2)
- **Architecture Setup**: `verified_by_codex`
- **Hermes Memory Pruning**: `claimed_by_hermes`
- **Source of Truth**: AgentOS local files.

### 2. NotebookLM Integration
- **Local Export Package**: `verified_by_codex`
- **Sync Tool**: `tracked` (`scripts\sync_notebooklm.py`)
- **Dry Run**: `verified_by_codex`
- **Remote Sync**: `not_verified`

### 3. Device Maintenance Project
- **Project Index**: `data\projects\device_maintenance.md`
- **Customer Facing**: `false`
- **Tools**:
  - Fan Control CLI: `scripts\fan_control\run.bat`
  - Memory Guard: `scripts\memory_guard.ps1`
- **Status**: `internal_maintenance_tools_active`
- **Safety Boundary**:
  - Use Fan Control `--action status` for routine checks.
  - Do not use Fan Control `--action enable_max` in unattended automation until threshold and unknown-temperature behavior is reverified.
  - Memory Guard is dry-run by default; do not use `-KillCandidates` without Josh approval.

---

## Codex Handoff & Memory

1. **Truth resides in files**: Always read `docs\MEMORY_ARCHITECTURE.md`.
2. **Device maintenance**: Fan Control and Memory Guard are tracked under `data\projects\device_maintenance.md`.
3. **Git hygiene**: Never use `git add .`; stage explicit files only.

## Key Documentation Index

- **Memory Protocol**: `docs\MEMORY_ARCHITECTURE.md`
- **Core Memory**: `data\memory\HERMES_CORE_MEMORY.md`
- **Device Maintenance**: `data\projects\device_maintenance.md`
- **Progress History**: `progress_log.md`
- **Architecture**: `docs\ARCHITECTURE.md`
- **Sync Logs**: `data\memory\sync_logs\`

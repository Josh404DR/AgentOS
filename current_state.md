# AgentOS Current State Snapshot
Last Updated: 2026-06-23 18:30 Asia/Taipei

## 🚀 Status Overview (Evidence-Based)

### 1. Memory Layer Architecture (V2)
- **Architecture Setup**: `verified_by_codex`
- **Hermes Memory Pruning**: `claimed_by_hermes`
- **Source of Truth**: AgentOS local files.

### 2. NotebookLM Integration
- **Local Export Package**: `verified_by_codex`
- **Sync Tool**: `tracked` (Refactored `scripts\sync_notebooklm.py`).
- **Dry Run**: `verified_by_codex`
- **Remote Sync**: `not_verified`

### 3. Fan Control Project (IoT)
- **Status**: `cli_contract_verified_by_inspector` ✅
  - **Findings**: `scripts\fan_control\` fully implemented with `argparse`, `run.bat`, and standardized Key-Value stdout.
  - **Safety**: Verified that `--action status` is read-only and `enable_max` guards against unknown sensor data.
  - **Hygiene**: Mojibake fixed; logging integrated to `fan_control.log`.
- **Note**: The project is now stable and ready for integration into the 24H health monitor.

---

## 📋 Codex Handoff & Memory
*Note: This section is for Codex Desktop to understand the system state.*

1. **Truth resides in Files**: Always read `docs\MEMORY_ARCHITECTURE.md`.
2. **Fan Control Usage**: Use `scripts\fan_control\run.bat --action [status|enable_max]`. Output is parsable KV pairs.
3. **Git Hygiene**: Strict rule - Never use `git add .`.

## 🔗 Key Documentation Index
- **Memory Protocol**: `docs\MEMORY_ARCHITECTURE.md`
- **Core Memory**: `data\memory\HERMES_CORE_MEMORY.md`
- **Progress History**: `progress_log.md`
- **Architecture**: `docs\ARCHITECTURE.md`
- **Sync Logs**: `data\memory\sync_logs\`

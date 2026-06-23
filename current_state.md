# AgentOS Current State Snapshot
Last Updated: 2026-06-23 17:35 Asia/Taipei

## 🚀 Status Overview (Evidence-Based)

### 1. Memory Layer Architecture (V2)
- **Architecture Setup**: `verified_by_codex` (Files `docs\MEMORY_ARCHITECTURE.md`, `data\memory\HERMES_CORE_MEMORY.md`, and `data\memory\NOTEBOOKLM_SOURCE_INDEX.md` exist).
- **Hermes Memory Pruning**: `claimed_by_hermes` (Hermes reported 94% -> 48%, but usage is internal and cannot be verified by local file inspection).
- **Source of Truth**: AgentOS local files are the canonical source of truth.

### 2. NotebookLM Integration
- **Local Export Package**: `verified_by_codex` (`exports\notebooklm_v1` contains 12 verified Markdown files).
- **Sync Tool**: `tracked_or_pending_commit` (Refactored `scripts\sync_notebooklm.py` with logging and dry-run support).
- **Dry Run**: `verified_by_hermes` (Successfully discovered 12 files and generated audit log).
- **Remote Sync**: `not_verified`
  - **Blocker**: PoC venv reported as broken in background (Python path error), though dry-run worked using absolute path.
  - **Blocker**: No verified live sync logs found for the current notebook `9af31a16-7984-428a-85ff-2d648d858560`.
  - **Note**: NotebookLM remains a retrieval layer only; do not treat as a source of truth until sync is verified.

### 3. Fan Control Project (IoT)
- **Status**: `draft_exists=true`, `cli_acceptance_not_met=true`
  - **Findings**: `scripts\fan_control\` exists with `main.py`, `config.ini`, `requirements.txt`.
  - **Blocker**: `main.py` lacks `argparse` and command-line actions (`--action status`/`--action enable_max`).
  - **Blocker**: `main.py` does not produce key-value stdout.
  - **Blocker**: `main.py` contains encoding artifacts/mojibake (`簞C`).
  - **Blocker**: `run.bat` is missing.
- **Note**: The project is in draft state and not yet functionally completed per task requirements.

---

## 📋 Codex Handoff & Memory
*Note: This section is for Codex Desktop to understand the system state.*

1. **Truth resides in Files**: Always read `docs\MEMORY_ARCHITECTURE.md` and `data\memory\HERMES_CORE_MEMORY.md`.
2. **NotebookLM Status**: Retrieval layer only. Remote sync is unverified. Use the local export files if needed.
3. **Git Hygiene**: Strict rule - Never use `git add .`. Add specific files only.

## 🔗 Key Documentation Index
- **Memory Protocol**: `docs\MEMORY_ARCHITECTURE.md`
- **Core Memory**: `data\memory\HERMES_CORE_MEMORY.md`
- **Progress History**: `progress_log.md`
- **Architecture**: `docs\ARCHITECTURE.md`
- **Sync Logs**: `data\memory\sync_logs\`

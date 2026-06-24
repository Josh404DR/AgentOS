# Task: Adopt Governance Owner Rule

## Objective
Record the adoption of the Governance Owner Rule: "Governance is single-writer, multi-reader."

## Core Rule
- Josh is the final authority.
- Codex is the designated governance file editor.
- Hermes and Claude may propose governance changes, but must not directly edit governance or role-boundary files.
- Hermes and Claude must follow the current governance files as source of truth.
- Any governance change must be implemented by Codex and be traceable in Git.

## Constraints
- Do NOT modify governance files (`docs\`, `agents\roles\`, `current_state.md` governance sections).
- Hermes/Claude only: Read, Follow, Propose.
- Only update `progress_log.md` and create adoption artifacts.

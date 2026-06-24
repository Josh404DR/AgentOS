# Task: P0a - Update .gitignore with Low-Risk Patterns

## Objective
Update the project's `.gitignore` file to include specific operational and temporary patterns. This will prevent Python bytecode caches, logs, and temporary virtual environments from being tracked.

## Approved Scope
Add the following patterns ONLY:
- `**/__pycache__/`
- `scripts/fan_control/fan_control.log`
- `**/.venv_notebooklm_poc/`

## Instructions for Codex
1. **Inspect**: Read the existing `.gitignore` file to check for existing patterns.
2. **Add**: Append only the missing patterns from the approved scope.
3. **Avoid Duplicates**: Do not add a pattern if it (or a broader matching pattern) already exists.
4. **Safety**:
    - **NO DELETION**: Do not delete any files.
    - **NO MOVEMENT**: Do not move any files.
    - **NO BROAD STAGING**: Do not use `git add .`. Do not stage untracked evidence folders or unrelated files.
5. **Verify**: Run `git diff` to confirm only `.gitignore` is modified with the intended changes.
6. **Commit**: Commit the change with the message: `Add low-risk operational ignores`.

## Deliverables
- Modified `.gitignore` (Committed).
- Completion record in `data/codex_tasks/2026-06-24-p0a-gitignore-update/OUTPUTS/RESULT.md`.

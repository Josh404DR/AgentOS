# Device Maintenance Project

Last updated: 2026-06-23 Asia/Taipei

Purpose: group local machine maintenance tools that support AgentOS operations but are not customer-facing freelance delivery work.

## Scope

This project covers local device stability, thermal checks, memory pressure checks, and operator-facing maintenance scripts.

This project does not cover:

- Client delivery.
- Proposal generation.
- Lead sourcing.
- NotebookLM remote sync.
- Hermes/Codex/Claude role protocol changes.

## Tools

### Fan Control CLI

- Path: `scripts\fan_control\`
- Entry point: `scripts\fan_control\run.bat`
- Purpose: check thermal state and, when explicitly requested, activate the configured PredatorSense fan workflow.
- Current status: `maintenance_tool_active`
- Evidence:
  - `scripts\fan_control\main.py`
  - `scripts\fan_control\run.bat`
  - `data\codex_tasks\2026-06-23-fan-control-cli-completion\`
- Safety note:
  - Treat GUI clicking as operator-approved maintenance behavior.
  - Do not call `--action enable_max` from unattended automation until threshold and unknown-temperature behavior is rechecked in the current code.
  - Prefer `--action status` for routine health checks.

### Memory Guard

- Path: `scripts\memory_guard.ps1`
- Purpose: report RAM pressure and list close candidates.
- Current status: `dry_run_tool_active`
- Evidence:
  - Commit `c38700f` added the tool.
  - Last recorded run reported high memory pressure and did not close any process.
- Safety note:
  - Default mode is dry-run.
  - Do not pass `-KillCandidates` unless Josh explicitly approves after reviewing the candidate list.

## Hermes Routing Rule

Hermes may use this project label when planning internal maintenance work:

- `project=device_maintenance`
- `customer_facing=false`
- `requires_josh_approval_for_destructive_or_gui_actions=true`

Recommended task routing:

- Codex: script changes, tests, and command verification.
- Claude Worker: checklist, risk notes, and user-facing maintenance instructions.
- Claude Inspector: final review of safety boundaries and overclaim risk.

## Current Next Steps

1. Reverify Fan Control `enable_max` threshold behavior before unattended use.
2. Add Memory Guard to health-check planning only in dry-run mode.
3. Keep device maintenance separate from freelance delivery workflows.

# AgentOS Evidence Hygiene Plan

Updated: 2026-06-22
Status: cleanup_requires_josh_approval

This document identifies canonical evidence for AgentOS project milestones and classifies other test artifacts for archival or deletion. **No files have been deleted.**

## Canonical Evidence

These folders represent the official verified state of AgentOS protocols.

| Path | Milestone | Reason |
| :--- | :--- | :--- |
| `data/live_bridge/tripartite_2026-06-22-120958/` | Tripartite Protocol Verification | Latest successful post-fix run with ASCII canonical summary and Claude review. |
| `data/codex_tasks/2026-06-22-three-agent-protocol-consistency/` | Role Consistency Check | The matching Codex task packet for the canonical tripartite run. |

## Evidence Classification

### Keep as Reference (keep_reference)
These contain unique data or represent specific testing milestones.

- `data/live_bridge/2026-06-21-0036-live-ascii/`: Initial successful Hermes-Codex bridge.
- `data/live_bridge/claude_2026-06-22-095156/`: First successful standalone Claude bridge.
- `data/live_bridge/tripartite_2026-06-22-101822/`: First full tripartite run (pre-fix, contains mojibake).
- `data/codex_tasks/2026-06-22-agentos-health-check/`: First technical task packet assigned to Codex.
- `data/leads/2026-06-22.md`: First lead discovery output (mock or real).

### Archive Candidates (archive_candidate)
Redundant or partially successful runs that may be useful for debugging but are not canonical.

- `data/live_bridge/2026-06-21-235219/`, `2026-06-21-235324/`: Duplicate environment state logs.
- `data/live_bridge/tripartite_2026-06-22-111736/`: Partial post-fix tripartite run (summary failed).
- `data/codex_tasks/2026-06-20-mock-apps-script-api-check/`: Early mock data test.
- `data/codex_tasks/2026-06-21-agentos-docs-consistency-smoke/`: Early documentation check.

### Delete Candidates (delete_candidate)
Empty, failed, or redundant artifacts that do not contribute to current knowledge. **Requires Josh approval before removal.**

- `data/live_bridge/2026-06-21-0031-live-smoke/`: Empty folder.
- `data/live_bridge/claude_2026-06-22-095050/`: Failed bridge (auth issue).
- `data/live_bridge/tripartite_2026-06-22-095309/`, `...-095653/`, `...-100241/`: Early bridge failures.
- `data/live_bridge/tripartite_2026-06-22-112320/`, `...-112401/`, `...-112455/`, `...-112927/`, `...-115653/`, `...-120311/`, `...-120625/`, `...-120752/`, `...-120851/`: Bridge iteration/dispatch failures.
- `data/codex_tasks/2026-06-22-check-protocol-consistency/`: Redundant consistency check.
- `data/codex_tasks/2026-06-22-check-three-agent-protocol/`: Redundant protocol check.
- `data/codex_tasks/2026-06-22-protocol-consistency/`: Empty/redundant.
- `data/codex_tasks/2026-06-22-protocol-consistency-check/`: Redundant.
- `data/codex_tasks/2026-06-22-role-consistency-check/`: Redundant.
- `data/codex_tasks/2026-06-22-verify-protocol-consistency/`: Empty/redundant.

## Execution Rules
1. Do not use `rm -rf` without explicit per-folder approval.
2. Canonical evidence must be committed to the repository.
3. Reference artifacts may be moved to a `data/archive/` folder instead of deletion.
4. Input prompt files (`*_INPUT_TEMP.txt`) should be excluded from commits unless required for audit.

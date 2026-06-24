# Stage 1 Evidence Cleanup Approval Plan

## Overview
- generated_at: 2026-06-24
- manifest_reference: `E:\AgentOS\data\codex_tasks\2026-06-24-evidence-cleanup-manifest\OUTPUTS\EVIDENCE_CLEANUP_MANIFEST.md`
- source_classification_reference: `E:\AgentOS\data\codex_tasks\2026-06-24-evidence-cleanup-manifest\OUTPUTS\CLAUDE_CLASSIFICATION_PROPOSAL.md`
- total_original_items: 49
- excluded_post_manifest_items: 6
- cleanup_executed: false
- evidence_classification_changed: false
- approval_required_before_cleanup: true

This plan is an approval artifact only. It does not authorize execution until Josh explicitly approves one or more action groups.

---

## safe_keep_no_action

These items remain in place and require no Stage 1 cleanup action.

| path | current_category | proposed_action | risk_level | why_it_is_safe_or_not_safe | approval_required |
|---|---|---|---|---|---|
| `data/memory/sync_logs/*.md` | keep_canonical | keep_in_place | low | Fresh NotebookLM sync evidence is active operational memory evidence. | false |
| `data/leads/2026-06-22.md` | keep_canonical | keep_in_place | low | Active lead tracking evidence. | false |
| `data/leads/2026-06-23.md` | keep_canonical | keep_in_place | low | Active lead tracking evidence. | false |
| `data/codex_tasks/2026-06-23-upgrade-fan-control-to-cli/` | keep_reference | keep_in_place | low | Fan Control CLI completion evidence is useful for device maintenance history. | false |
| `data/codex_tasks/2026-06-23-deploy-fan-control-fix/` | keep_reference | keep_in_place | low | Related Fan Control fix evidence remains useful reference. | false |
| `data/codex_tasks/2026-06-22-check-three-agent-protocol/` | keep_reference | keep_in_place | low | Parallel lane / protocol evidence remains useful reference. | false |
| `scripts/monitor_ui.py` | keep_reference | keep_in_place | medium | Local monitoring tool; do not move or delete until utility is separately reviewed. | false |

---

## archive_candidates_requires_approval

These items are candidates for archive storage. Approval is required per row or for the full archive group.

| path | current_category | proposed_action | risk_level | why_it_is_safe_or_not_safe | approval_required |
|---|---|---|---|---|---|
| `data/live_bridge/2026-06-21-235219/` | archive_candidate | move_to_archive | low | Historical bridge/session evidence; preserve rather than delete. | true |
| `data/live_bridge/2026-06-21-235324/` | archive_candidate | move_to_archive | low | Historical bridge/session evidence; preserve rather than delete. | true |
| `data/live_bridge/claude_2026-06-22-095050/` | archive_candidate | move_to_archive | low | Historical Claude bridge evidence; preserve rather than delete. | true |
| `data/live_bridge/claude_2026-06-22-095156/` | archive_candidate | move_to_archive | low | Historical Claude bridge evidence; preserve rather than delete. | true |
| `data/live_bridge/tripartite_2026-06-22-095309/` | archive_candidate | move_to_archive | low | Historical tripartite run evidence; preserve rather than delete. | true |
| `data/live_bridge/tripartite_2026-06-22-095653/` | archive_candidate | move_to_archive | low | Historical tripartite run evidence; preserve rather than delete. | true |
| `data/live_bridge/tripartite_2026-06-22-100241/` | archive_candidate | move_to_archive | low | Historical tripartite run evidence; preserve rather than delete. | true |
| `data/live_bridge/tripartite_2026-06-22-100459/` | archive_candidate | move_to_archive | low | Historical tripartite run evidence; preserve rather than delete. | true |
| `data/live_bridge/tripartite_2026-06-22-100959/` | archive_candidate | move_to_archive | low | Historical tripartite run evidence; preserve rather than delete. | true |
| `data/live_bridge/tripartite_2026-06-22-101425/` | archive_candidate | move_to_archive | low | Historical tripartite run evidence; preserve rather than delete. | true |
| `data/live_bridge/tripartite_2026-06-22-101822/` | archive_candidate | move_to_archive | low | Historical tripartite run evidence; preserve rather than delete. | true |
| `data/live_bridge/tripartite_2026-06-22-111736/` | archive_candidate | move_to_archive | low | Historical tripartite run evidence; preserve rather than delete. | true |
| `data/live_bridge/tripartite_2026-06-22-112320/` | archive_candidate | move_to_archive | low | Historical tripartite run evidence; preserve rather than delete. | true |
| `data/live_bridge/tripartite_2026-06-22-112401/` | archive_candidate | move_to_archive | low | Historical tripartite run evidence; preserve rather than delete. | true |
| `data/live_bridge/tripartite_2026-06-22-120311/` | archive_candidate | move_to_archive | low | Historical tripartite run evidence; preserve rather than delete. | true |
| `data/live_bridge/tripartite_2026-06-22-120851/` | archive_candidate | move_to_archive | low | Historical tripartite run evidence; preserve rather than delete. | true |
| `data/codex_tasks/2026-06-22-agentos-health-check/` | archive_candidate | move_to_archive | low | Legacy task evidence; preserve for audit but remove from active workspace view. | true |
| `data/codex_tasks/2026-06-22-check-protocol-consistency/` | archive_candidate | move_to_archive | low | Legacy task evidence; preserve for audit but remove from active workspace view. | true |
| `data/codex_tasks/2026-06-22-protocol-consistency-check/` | archive_candidate | move_to_archive | low | Legacy task evidence; preserve for audit but remove from active workspace view. | true |
| `data/codex_tasks/2026-06-22-protocol-consistency/` | archive_candidate | move_to_archive | low | Legacy task evidence; preserve for audit but remove from active workspace view. | true |
| `data/codex_tasks/2026-06-22-role-consistency-check/` | archive_candidate | move_to_archive | low | Legacy task evidence; preserve for audit but remove from active workspace view. | true |
| `data/codex_tasks/2026-06-22-verify-protocol-consistency/` | archive_candidate | move_to_archive | low | Legacy task evidence; preserve for audit but remove from active workspace view. | true |
| `data/codex_tasks/2026-06-23-fix-git-commit/` | archive_candidate | move_to_archive | low | Completed task evidence; preserve for audit but remove from active workspace view. | true |
| `data/codex_tasks/2026-06-23-implement-fan-control/` | archive_candidate | move_to_archive | low | Superseded by later Fan Control CLI evidence; preserve rather than delete. | true |
| `docs/temp_routing_rules.txt` | archive_candidate | move_to_archive | low | Temporary routing note; preserve only if useful as historical context. | true |

---

## delete_candidates_requires_approval

These items are candidates for deletion. Approval is required per row or for the full delete group.

| path | current_category | proposed_action | risk_level | why_it_is_safe_or_not_safe | approval_required |
|---|---|---|---|---|---|
| `scripts/__pycache__/` | delete_candidate | delete | low | Python bytecode cache; regenerated automatically. | true |
| `scripts/fan_control/__pycache__/` | delete_candidate | delete | low | Python bytecode cache; regenerated automatically. | true |
| `data/codex_tasks/2026-06-23-poc-notebooklm-api/.venv_notebooklm_poc/` | delete_candidate | delete | medium | Large POC virtual environment; should be reproducible, but deletion is irreversible without reinstall. | true |
| `ddg_results.html` | delete_candidate | delete | low | Ephemeral search result cache; not canonical evidence. | true |
| `temp_commit.sh` | delete_candidate | delete | medium | Temporary shell helper; delete only after confirming no unique command history is needed. | true |

---

## gitignore_candidates_requires_approval

These are ignore-rule candidates. Approval is required before changing `.gitignore`.

| path_or_pattern | current_category | proposed_action | risk_level | why_it_is_safe_or_not_safe | approval_required |
|---|---|---|---|---|---|
| `scripts/fan_control/fan_control.log` | ignore_by_gitignore | add_to_gitignore | low | Runtime log should not be tracked unless explicitly promoted to evidence. | true |
| `**/__pycache__/` | ignore_by_gitignore | add_to_gitignore | low | Standard Python bytecode cache pattern. | true |
| `**/.venv_notebooklm_poc/` | ignore_by_gitignore | add_to_gitignore | medium | Prevents large POC virtual environment from being tracked; verify no source files live inside before deletion. | true |

---

## needs_josh_decision

These items require Josh decision before any action. They are not Stage 1 cleanup execution targets.

| path | current_category | proposed_action | risk_level | why_it_is_safe_or_not_safe | approval_required |
|---|---|---|---|---|---|
| `exports/notebooklm_v1/` | needs_josh_decision | decide_keep_track_archive_or_regenerate | medium | L3 source/export pack may contain useful retrieval source material; do not move/delete without decision. | true |
| `scripts/env_manager.py` | needs_josh_decision | decide_keep_review_or_remove | medium | Utility related to `.env` management; contents may affect secret-handling workflow. | true |

---

## excluded_post_manifest_items

These items were detected after the initial 49-item manifest. They are excluded from Stage 1 cleanup and require separate incremental review.

| path | current_category | proposed_action | risk_level | why_it_is_safe_or_not_safe | approval_required |
|---|---|---|---|---|---|
| `data\leads\2026-06-24.md` | needs_incremental_classification | exclude_from_stage_1 | unknown | New lead artifact; not part of original manifest. | true |
| `leads.json` | needs_incremental_classification | exclude_from_stage_1 | unknown | New crawler/output artifact; not part of original manifest. | true |
| `page_source.html` | needs_incremental_classification | exclude_from_stage_1 | unknown | New crawler/debug artifact; not part of original manifest. | true |
| `scrape_upwork.py` | needs_incremental_classification | exclude_from_stage_1 | unknown | New crawler script; not part of original manifest. | true |
| `upwork_debug.png` | needs_incremental_classification | exclude_from_stage_1 | unknown | New crawler/debug artifact; not part of original manifest. | true |
| `upwork_utf8.html` | needs_incremental_classification | exclude_from_stage_1 | unknown | New crawler/debug artifact; not part of original manifest. | true |

---

## Josh Approval Checklist

Use explicit yes/no decisions. Partial approvals are allowed.

- [ ] Josh approve all archive candidates? yes/no
- [ ] Josh approve selected archive candidates only? list paths:
- [ ] Josh approve all delete candidates? yes/no
- [ ] Josh approve selected delete candidates only? list paths:
- [ ] Josh approve all gitignore candidates? yes/no
- [ ] Josh approve selected gitignore candidates only? list patterns:
- [ ] Josh decision for `exports/notebooklm_v1/`: keep / track / archive / regenerate / defer
- [ ] Josh decision for `scripts/env_manager.py`: keep / review / remove / defer
- [ ] Josh approve separate incremental review for the 6 post-manifest items? yes/no

---

## Execution Gate

- cleanup_executed: false
- archive_executed: false
- delete_executed: false
- gitignore_modified: false
- post_manifest_items_included_in_stage_1_execution: false

No Stage 1 cleanup action may run until Josh explicitly approves the relevant checklist item.

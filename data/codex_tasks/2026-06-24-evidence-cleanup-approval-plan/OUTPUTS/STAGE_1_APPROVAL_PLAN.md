# Stage 1 Evidence Cleanup Approval Plan

## Overview
- **Generated At:** 2026-06-24
- **Manifest Reference:** `E:\AgentOS\data\codex_tasks\2026-06-24-evidence-cleanup-manifest\OUTPUTS\EVIDENCE_CLEANUP_MANIFEST.md`
- **Total Original Items:** 49
- **Excluded Items:** 6 (Post-manifest)
- **Cleanup Executed:** false

---

## 1. safe_keep_no_action
*These items are identified as essential and will be retained in Layer 2.*

- **keep_canonical (3 items):**
  - `data/memory/sync_logs/*.md` (Fresh NotebookLM sync logs)
  - `data/leads/2026-06-22.md`
  - `data/leads/2026-06-23.md`
- **keep_reference (4 items):**
  - `data/codex_tasks/2026-06-23-upgrade-fan-control-to-cli/`
  - `data/codex_tasks/2026-06-23-deploy-fan-control-fix/`
  - `data/codex_tasks/2026-06-22-check-three-agent-protocol/`
  - `scripts/monitor_ui.py`

---

## 2. archive_candidates_requires_approval
*Items to be moved to cold storage (e.g., `/archive/`) once approved.*

- **Items (25):**
  - `data/live_bridge/*` (16 folders containing old transcripts/logs)
  - `data/codex_tasks/2026-06-22-agentos-health-check/`
  - `data/codex_tasks/2026-06-22-check-protocol-consistency/`
  - `data/codex_tasks/2026-06-22-protocol-consistency-check/`
  - `data/codex_tasks/2026-06-22-protocol-consistency/`
  - `data/codex_tasks/2026-06-22-role-consistency-check/`
  - `data/codex_tasks/2026-06-22-verify-protocol-consistency/`
  - `data/codex_tasks/2026-06-23-fix-git-commit/`
  - `data/codex_tasks/2026-06-23-implement-fan-control/`
  - `docs/temp_routing_rules.txt`
- **Proposed Action:** Move to `archive/` directory.
- **Risk Level:** LOW (Historical evidence only).
- **Safe to Archive:** Yes. These are completed sessions or legacy task artifacts.
- **Approval Required:** true

---

## 3. delete_candidates_requires_approval
*Transient or rebuildable artifacts.*

- **Items (5):**
  - `scripts/__pycache__/`
  - `scripts/fan_control/__pycache__/`
  - `data/codex_tasks/2026-06-23-poc-notebooklm-api/.venv_notebooklm_poc/`
  - `ddg_results.html`
  - `temp_commit.sh`
- **Proposed Action:** Permanent deletion.
- **Risk Level:** LOW (Bytecode, temp cache, or rebuildable virtual environments).
- **Safe to Delete:** Yes. `__pycache__` is auto-generated. `.venv` can be recreated from requirements. Cache files are ephemeral.
- **Approval Required:** true

---

## 4. gitignore_candidates_requires_approval
*Operational files that should not be tracked by Git.*

- **Items (3):**
  - `scripts/fan_control/fan_control.log`
  - `**/__pycache__/`
  - `**/.venv_notebooklm_poc/`
- **Proposed Action:** Add to `.gitignore`.
- **Risk Level:** NONE. Prevents future file bloat.
- **Safe to Ignore:** Yes. Standard practice for logs and build artifacts.
- **Approval Required:** true

---

## 5. needs_josh_decision
*Items requiring human review for sensitivity or integration.*

- **Items (2):**
  - `exports/notebooklm_v1/` (L3 source pack)
  - `scripts/env_manager.py` (Security-sensitive script)
- **Proposed Action:** Manual review by Josh Hsu.
- **Risk Level:** MEDIUM. `env_manager.py` handles secrets. `exports/` may contain canonical data.
- **Safe to Move/Delete:** NO. Requires explicit decision.
- **Approval Required:** true

---

## 6. excluded_post_manifest_items
*Items detected after the initial manifest. Excluded from Stage 1 actions.*

- **Items (6):**
  - `data\leads\2026-06-24.md`
  - `leads.json`
  - `page_source.html`
  - `scrape_upwork.py`
  - `upwork_debug.png`
  - `upwork_utf8.html`
- **Action:** Retain in current location; scheduled for separate incremental review.

---

## 7. Approval Checklist

[ ] **Josh approve archive candidates?** (yes/no)
[ ] **Josh approve delete candidates?** (yes/no)
[ ] **Josh approve gitignore changes?** (yes/no)
[ ] **Josh approve handling needs_josh_decision items?** (yes/no)

---
*Plan prepared by Hermes Agent.*

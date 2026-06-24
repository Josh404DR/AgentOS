# Task: Evidence Cleanup Manifest - Real Run

## Objective
1. Inventory Git untracked / evidence folders / temp files.
2. Classify items (keep_canonical, keep_reference, archive_candidate, delete_candidate, ignore_by_gitignore_candidate, needs_josh_decision).
3. Produce a manifest (EVIDENCE_CLEANUP_MANIFEST.md).
4. NO deletion, NO moving, NO staging of unrelated evidence.
5. Update current_state.md and progress_log.md.
6. Real Git commit.

## Workflows
### Codex Builder Lane
- Run `git status --short`.
- List untracked files/dirs in specific areas.
- Output: `OUTPUTS\CODEX_INVENTORY.md`.

### Claude Worker Lane
- Propose classification for inventoried items.
- Output: `OUTPUTS\CLAUDE_CLASSIFICATION_PROPOSAL.md`.

### Claude Inspector Lane
- Review compliance (no deletions, no secret leaks).
- Output: `OUTPUTS\CLAUDE_INSPECTOR_REVIEW.md`.

## Constraints
- Do not delete anything.
- Do not move anything.
- Do not modify .gitignore.
- Do not stage unrelated evidence.

# Evidence Cleanup Manifest

## Overview
- **Generated At:** 2026-06-24
- **Source Commands:** `git status --short`, `git ls-files --others --exclude-standard`
- **Total Untracked Items Reviewed:** 49
- **Cleanup Executed:** false
- **Approval Required:** true (Josh Hsu)

## Classification Table

| Category | Item Count | Action Strategy |
| :--- | :--- | :--- |
| **keep_canonical** | 3 | Retain as Layer 2 source of truth. |
| **keep_reference** | 4 | Retain for historical evidence and local tooling. |
| **archive_candidate** | 25 | Move to archive storage (pending approval). |
| **delete_candidate** | 5 | Safe to delete (bytecode, temporary VEs). |
| **ignore_by_gitignore** | 3 | Add to `.gitignore` to prevent future tracking. |
| **needs_josh_decision** | 2 | Requires manual review for sensitivity/utility. |

## Category Definitions
- **keep_canonical:** Fresh Notebook sync artifacts and active project leads that are essential for current operations.
- **keep_reference:** Completed task evidence and local operational tools that provide value for debugging or context.
- **archive_candidate:** Old sync sessions (Live Bridge) and legacy task artifacts that are no longer active but should be preserved.
- **delete_candidate:** Transient build artifacts (pycache), temporary scripts, and large POC virtual environments.
- **ignore_by_gitignore_candidate:** Files that are part of normal operations but should never be tracked (logs, bytecode).
- **needs_josh_decision:** Items with potential security sensitivity (auth managers) or high-value source packs (NotebookLM exports).

## Detailed Classification Proposal
Refer to `E:\AgentOS\data\codex_tasks\2026-06-24-evidence-cleanup-manifest\OUTPUTS\CLAUDE_CLASSIFICATION_PROPOSAL.md` for the full list of files per category.

## Recommended Next Steps
1. **Josh Review:** Josh Hsu to review the categories and specific file lists.
2. **Move to Archive:** Upon approval, move `archive_candidate` items to a dedicated `/archive/` directory.
3. **Update Gitignore:** Add `fan_control.log` and `__pycache__` patterns to `.gitignore`.
4. **Prune Delete Candidates:** Delete identified pycache and POC virtual environments.

## Explicit Statements
- **No files were deleted or moved during this task.**
- **Cleanup requires Josh approval.**
- **NotebookLM sync status is not used as deletion authority.**
- **Security Check:** `scripts/env_manager.py` identified as a Medium risk; contents were not read into the manifest.

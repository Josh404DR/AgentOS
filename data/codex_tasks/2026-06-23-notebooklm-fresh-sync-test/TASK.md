# Task: NotebookLM Fresh Notebook Sync Test

## Goal
Perform a controlled, auditable sync test to a newly created NotebookLM notebook to resolve the evidence gap between UI observation and local logs.

## Constraints
1. **New Notebook Only**: Create a fresh notebook for this test; do not delete or modify existing ones.
2. **Source of Truth**: NotebookLM is Layer 3 (Retrieval). Local files remain the authority.
3. **Auditability**: Every step (creation, upload, source count) must be logged in a markdown audit log.
4. **Security**: No credential reading. Use existing auth profile.
5. **Scope**: Sync only the 12 verified files in `E:\AgentOS\exports\notebooklm_v1\`.

## Deliverables
- `OUTPUTS\CODEX_RESULT.md`: Technical execution details and remote counts.
- `OUTPUTS\CLAUDE_WORKER_PLAN.md`: Strategic plan for querying and recovery.
- `OUTPUTS\CLAUDE_INSPECTOR_REVIEW.md`: Compliance and safety audit.
- `OUTPUTS\FINAL_SUMMARY.md`: Consolidated report for Josh.
- `E:\AgentOS\data\memory\sync_logs\fresh_notebook_sync\notebooklm_fresh_sync_*.md`: The authoritative audit log.

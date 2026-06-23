# Task: NotebookLM Controlled Live Sync

## Goal
Execute the first approved live sync of 12 verified Markdown files to NotebookLM using the stable Python 3.10 environment.

## Constraints
1. **Source of Truth**: NotebookLM is Layer 3 (Retrieval-Only). Local files remain the authority.
2. **Decoupling**: Evidence cleanup is independent of sync status.
3. **Security**: No credential reading. Use existing auth profile only.
4. **Scope**: Sync only the 12 files in `E:\AgentOS\exports\notebooklm_v1\`.
5. **No Retries**: Single execution only. Report failures as is.

## Deliverables
- `OUTPUTS\CODEX_RESULT.md`: Execution log and technical outcome.
- `OUTPUTS\CLAUDE_WORKER_PLAN.md`: Post-sync protocol and retrieval strategy.
- `OUTPUTS\CLAUDE_INSPECTOR_REVIEW.md`: Compliance and safety audit.
- `OUTPUTS\FINAL_SUMMARY.md`: Final status report.

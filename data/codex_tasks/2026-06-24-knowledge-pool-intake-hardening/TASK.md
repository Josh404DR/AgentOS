# Task: Knowledge Pool Intake Hardening

## Objective
Harden the knowledge collection process by performing a triage of all current items in `data\knowledge_pool\`. This ensures that saved links are not treated as verified or adoptable tools without proper review.

## Requirements
1.  **Read-Only Review**: Review all 12 current entries in `data\knowledge_pool\`.
2.  **Classification**: Assign each entry a primary triage category (`safe_reference`, `needs_source_verification`, `needs_security_review`, `needs_platform_policy_review`, `low_priority_curiosity`) and secondary flags.
3.  **Triage Report**: Produce `OUTPUTS\KNOWLEDGE_POOL_TRIAGE.md` with a structured table and intake rules.
4.  **Governance Compliance**: Adhere to the "Governance Owner Rule" (No direct edits to governance/role files).
5.  **Evidence Contract**: Use the required Evidence Block format in the final report.

## Constraints
- **NO EXECUTION**: Do not install, run, clone, or test any external tools.
- **NO SYNC**: Do not trigger NotebookLM sync yet.
- **NO MODIFICATION**: Do not modify existing knowledge files or governance/role docs.
- **NO DELETION**: Do not delete or move files.

## Deliverables
- `data/codex_tasks/2026-06-24-knowledge-pool-intake-hardening/TASK.md`
- `data/codex_tasks/2026-06-24-knowledge-pool-intake-hardening/OUTPUTS/KNOWLEDGE_POOL_TRIAGE.md`
- Updated `progress_log.md`

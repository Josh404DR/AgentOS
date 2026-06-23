# TASK: Parallel Lane Smoke Test - Evidence-Based Workflow

## Objective
Verify the new multi-lane collaboration protocol without performing high-risk operations. Ensure Hermes can coordinate Codex Builder, Claude Worker, and Claude Inspector.

## Roles
- **Hermes**: Coordinator & Final Summarizer.
- **Codex Builder**: Execution of technical dry-runs and file inspection.
- **Claude Worker**: Analysis of task suitability for parallel processing.
- **Claude Inspector**: Quality assurance and role boundary verification.

## Acceptance Criteria
1. Codex Builder successfully performs a NotebookLM dry-run discovering 12 files.
2. Claude Worker provides a suitability note for parallel tasks.
3. Claude Inspector verifies both outputs against evidence and role boundaries.
4. Final summary produced by Hermes.

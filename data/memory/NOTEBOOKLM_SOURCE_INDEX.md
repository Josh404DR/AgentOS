# NotebookLM Source Index

Last updated: 2026-06-23

Purpose: define which AgentOS files should be uploaded or exported into NotebookLM when Josh starts the NotebookLM memory layer.

NotebookLM is a retrieval layer. AgentOS files remain the canonical source of truth.

## Priority 1: Core Operating Memory

Upload these first:

- `docs\MEMORY_ARCHITECTURE.md`
- `data\memory\HERMES_CORE_MEMORY.md`
- `docs\ARCHITECTURE.md`
- `current_state.md`
- `docs\AGENT_ROUTING_PLAN.md`
- `docs\RESOURCE_INVENTORY.md`
- `docs\HERMES_REPORTING_PRINCIPLES.md`
- `agents\roles\hermes.md`
- `agents\roles\codex.md`
- `agents\roles\claude.md`
- `agents\roles\gemini.md`

## Priority 2: Workflow Knowledge

Upload after Priority 1:

- `workflows\ai_freelancer_os.md`
- `workflows\hermes_to_codex.md`
- `docs\PRE_FLIGHT_TEST_PLAN.md`
- `docs\24H_STABILITY_MONITOR_PLAN.md`
- `docs\EVIDENCE_HYGIENE_PLAN.md`
- `docs\SECURITY_REVIEW_AVIRA_INSTALL_PS1.md`

## Priority 3: Usage and Cost Evidence

Upload only the latest relevant reports:

- Latest `data\usage\hermes_usage_audit_*.md`
- Latest `data\usage\YYYY-MM-DD.md`
- `data\usage\TEMPLATE.md`

## Priority 4: Case Knowledge

Upload selectively:

- `data\leads\YYYY-MM-DD.md`
- `data\screening\screening_log.md`
- `data\proposals\*.md`
- Finished Codex task `TASK.md` and `OUTPUTS\RESULT.md` pairs

## Exclude By Default

Do not upload these unless Josh explicitly asks:

- Raw `data\live_bridge\*` folders.
- Failed or duplicate bridge-test artifacts.
- Raw full `progress_log.md` if it becomes too large; use curated summaries instead.
- `HERMES_NOTES.md` until the mojibake-corrupted sections are repaired or extracted into a clean file.
- Quarantined or deleted installer scripts.
- Any secrets, tokens, `.env` files, private keys, or browser/session state.

## NotebookLM Use Cases

Good uses:

- Ask "what did we decide about Hermes/Codex/Claude routing?"
- Summarize role boundaries.
- Find prior risk decisions.
- Retrieve lead/proposal patterns.
- Compare current tasks against previous lessons.

Bad uses:

- Treat NotebookLM as an execution engine.
- Treat NotebookLM output as verified without checking source files.
- Use NotebookLM to replace Git history or AgentOS docs.

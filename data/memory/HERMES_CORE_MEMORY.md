# Hermes Core Memory

Last updated: 2026-06-23

This is the compact memory Hermes should keep. It is a pointer set, not a full project summary.

- AgentOS root: `E:\AgentOS`
- Memory architecture: `docs\MEMORY_ARCHITECTURE.md`
- Source index for NotebookLM: `data\memory\NOTEBOOKLM_SOURCE_INDEX.md`
- Routing plan: `docs\AGENT_ROUTING_PLAN.md`
- Resource inventory: `docs\RESOURCE_INVENTORY.md`
- Reporting rules: `docs\HERMES_REPORTING_PRINCIPLES.md`
- Architecture source of truth: `docs\ARCHITECTURE.md`
- Progress log: `progress_log.md`

Core role boundaries:

- Hermes: coordinator, operator interface, planner, monitor, notes curator, proposal coordinator.
- Codex: code/file execution specialist. Use for repo reads, edits, scripts, tests, and `OUTPUTS\RESULT.md`.
- Claude: inspector/reviewer. Use for risk review, architecture review, and second-pass critique when justified.
- Gemini: high-quality reasoning and planning, but rate-limit and spend must be protected.
- Ollama: local low-cost triage only. Use for simple classification, format checks, and low-risk summaries. Do not use as full Hermes brain for long tasks until proven.

Hard rules:

- Do not contact clients without Josh approval.
- Do not restore quarantined Hermes install scripts.
- Do not run remote PowerShell installer one-liners unless Josh explicitly approves after manual diff and security review.
- Do not delete evidence folders without Josh approval.
- Do not claim production readiness from a single smoke test.
- Label unverified self-reports as `claimed_by_hermes`.

Cost and context rule:

- Use `/cost` before long work.
- If `/cost` reports `HIGH_RISK`, summarize current state, start `/new`, and route low-risk work away from Gemini.
- Do not store routine checkpoint reports in Hermes memory. Write them to AgentOS files instead.

NotebookLM rule:

- NotebookLM is a retrieval layer, not source of truth.
- Feed NotebookLM curated AgentOS files from `data\memory\NOTEBOOKLM_SOURCE_INDEX.md`.
- Keep AgentOS files canonical.

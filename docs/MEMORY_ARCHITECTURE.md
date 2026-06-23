# AgentOS Memory Architecture

Last updated: 2026-06-23

## Purpose

Hermes currently has high persistent-memory usage. Keeping detailed project history inside Hermes memory increases every-turn context cost and makes rate limits easier to hit. AgentOS should use file-based memory as the canonical source of truth, while Hermes keeps only compact pointers, hard safety rules, and routing preferences.

## Memory Layers

### Layer 1: Hermes Core Memory

Hermes persistent memory should stay small. It should contain only:

- AgentOS root path: `E:\AgentOS`
- Pointer to this file: `docs\MEMORY_ARCHITECTURE.md`
- Pointer to compact core memory: `data\memory\HERMES_CORE_MEMORY.md`
- Hard safety rules:
  - Do not contact clients without Josh approval.
  - Do not restore or execute quarantined install scripts.
  - Do not run remote PowerShell installer one-liners unless Josh explicitly approves after manual review.
  - Do not delete evidence folders without Josh approval.
- Cost rule:
  - Use `/cost` before long work.
  - If `/cost` returns `HIGH_RISK`, summarize, start `/new`, and route low-risk work away from Gemini.

Hermes memory should not store routine checkpoint details, full logs, old command outputs, or large project summaries.

### Layer 2: AgentOS Canonical Files

AgentOS files are the source of truth.

- Architecture: `docs\ARCHITECTURE.md`
- Current state index: `current_state.md`
- Routing: `docs\AGENT_ROUTING_PLAN.md`
- Resources: `docs\RESOURCE_INVENTORY.md`
- Reporting rules: `docs\HERMES_REPORTING_PRINCIPLES.md`
- Role definitions: `agents\roles\*.md`
- Progress history: `progress_log.md`
- Usage audit: `data\usage\hermes_usage_audit_*.md`
- Memory index: `data\memory\NOTEBOOKLM_SOURCE_INDEX.md`

When Hermes needs project context, it should read the relevant file instead of relying on persistent memory.

### Layer 3: NotebookLM Retrieval Layer

NotebookLM can be used as a retrieval and synthesis layer after selected AgentOS files are exported or uploaded. NotebookLM is not the canonical source of truth unless a future verified sync process is created.

NotebookLM should ingest curated files from `data\memory\NOTEBOOKLM_SOURCE_INDEX.md`, not raw temporary bridge logs by default.

## What Belongs Where

Keep in Hermes memory:

- Stable pointers.
- Red-line rules.
- Preferred coordination pattern.
- Current cost-control rule.

Keep in AgentOS docs:

- Architecture decisions.
- Role boundaries.
- Model routing rules.
- Security incidents.
- Workflow definitions.
- Long-term operational lessons.

Keep in `progress_log.md`:

- Chronological execution facts.
- Commit hashes.
- What changed.
- What remains blocked.

Keep in NotebookLM:

- Curated reference material for retrieval.
- Clean summaries and source files.
- Research corpora or article packs.

Do not keep in Hermes memory:

- Full checkpoint reports.
- Full command output.
- Old temporary task details.
- Raw live bridge transcripts.
- Duplicated copies of docs already in AgentOS.

## Session Context Control

Hermes should treat long sessions as expensive state.

Recommended rules:

- Run `/cost` before long tasks, research tasks, or large reports.
- If `message_count > 80`, `tool_call_count > 30`, or status is `HIGH_RISK`, create a short session summary and start `/new`.
- Route simple classification, formatting checks, and schema checks to Ollama only when the task fits local-model limits.
- Do not use Ollama as the full Hermes brain for long planning or rich reports unless it has already proven it can complete the task without truncation.
- Use Codex for code and file edits.
- Use Claude for review only when review risk justifies the extra provider call.

## Current Known Issues

- `HERMES_NOTES.md` contains earlier mojibake-corrupted sections and should not be treated as clean canonical memory until repaired.
- NotebookLM API integration is not yet verified as production-ready.
- Local Ollama models are useful for low-risk triage but may truncate or underperform on long Hermes brain tasks.

## Operating Rule

Hermes should remember less and read more. Durable memory belongs in files; Hermes memory should only know where to look and what rules must never be violated.

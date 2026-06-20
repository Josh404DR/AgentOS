# AgentOS Agent Routing Plan

Updated: 2026-06-21 00:13 Asia/Taipei
Purpose: Minimal routing rules for assigning work across Hermes, Codex, Gemini, Claude, Perplexity, Ollama, and Antigravity without adding a new agent framework.

## Routing Principle

Use file artifacts first. Hermes coordinates, then assigns explicit work packets or review notes to the cheapest reliable resource for the task.

## Resource Roles

| Resource | Role | Current automation status |
|---|---|---|
| Hermes | Coordinator, Telegram brain, lead/proposal owner | Active coordinator, file-based handoff |
| Codex | Repo edits, scripts, tests, implementation, technical validation | Active through task packets |
| Gemini | Research, summaries, proposal second opinion | Available, not separate state owner |
| Claude | High-context review, architecture critique, second opinion | CLI installed, not automated yet |
| Perplexity | Current web research with sources | Subscription user-reported, integration not verified |
| Ollama | Local low-cost classification, draft summaries, fallback reasoning | Local models available |
| Antigravity IDE | Manual desktop coding resource | Subscription user-reported, not automated |

## Minimal Dispatch Flow

```text
Hermes defines decision
  -> data\routing_decisions\YYYY-MM-DD-<task>.md
  -> if technical: data\codex_tasks\YYYY-MM-DD-<task>\TASK.md
  -> assigned resource writes result artifact
  -> Hermes updates routing decision and summarizes to Josh
```

## Escalation Rules

- Use Ollama for cheap local rough classification.
- Use Gemini for lead/proposal summarization and second opinions.
- Use Perplexity only when current external facts or sources matter.
- Use Codex when local files, code, scripts, tests, or implementation are involved.
- Use Claude for manual high-context review after Codex output exists.
- Ask Josh before client-facing commitments, paid API use, credentials, or proposal submission.

## Current Non-Goals

- Do not build a new daemon or queue yet.
- Do not make Claude, Perplexity, or Antigravity automatic workers until their handoff is tested.
- Do not bypass the `data\codex_tasks\...\OUTPUTS\RESULT.md` return contract for Codex work.

# AgentOS Agent Routing Plan

Updated: 2026-06-21 22:33 Asia/Taipei
Purpose: Minimal routing rules for assigning work across Hermes, Codex, Gemini, Claude, Perplexity, Ollama, and manual IDE resources without adding a new agent framework.

## Routing Principle

Use file artifacts first. Hermes coordinates, then assigns explicit work packets or review notes to the cheapest reliable resource for the task.

## Resource Roles

| Resource | Role | Current automation status |
|---|---|---|
| Hermes | Coordinator, Telegram brain, lead/proposal owner | Active coordinator, file-based handoff |
| Codex | Repo edits, scripts, tests, implementation, technical validation | Active through task packets |
| Gemini | Research, summaries, proposal second opinion | Available, not separate state owner |
| Claude | Inspector, high-context review, architecture critique | Active Inspector via tripartite bridge for tested review handoffs |
| Perplexity | Current web research with sources | Subscription user-reported, integration not verified |
| Ollama | Local low-cost classification, draft summaries, fallback reasoning | Local models available |
| Antigravity IDE | Manual desktop coding resource | Subscription user-reported, not automated |
| Perplexity IDE | Manual research/coding assistant | User-reported, not automated |
| VSCode + Cline free | Manual IDE/agent support | User-reported, not automated |
| Cursor free quota | Manual IDE coding support | User-reported, not automated |

## Minimal Dispatch Flow

```text
Hermes defines decision
  -> data\routing_decisions\YYYY-MM-DD-<task>.md
  -> if technical: data\codex_tasks\YYYY-MM-DD-<task>\TASK.md
  -> assigned resource writes result artifact
  -> Hermes updates routing decision and summarizes to Josh
```

## Live Hermes-Codex CLI Bridge

For direct CLI communication, use:

```powershell
.\scripts\hermes_codex_bridge.ps1
```

## Live Hermes-Codex-Claude Tripartite Bridge

For high-assurance coordination where Codex implementation is reviewed by Claude, use:

```powershell
.\scripts\hermes_tripartite_bridge.ps1
```

The tripartite bridge runs a full cycle:

```text
Hermes CLI (Brain)
  -> Dispatches TASK.md packet
  -> Codex CLI (Builder)
    -> Executes and writes RESULT.md
    -> Claude CLI (Inspector)
      -> Reviews RESULT.md and provides RATING
      -> Hermes CLI
        -> Summarizes the verified outcome for Josh
```

Outputs are stored under:

```text
E:\AgentOS\data\live_bridge\tripartite_<id>\
  01_HERMES_DISPATCH.md
  02_CODEX_OUTPUT.md
  03_CLAUDE_REVIEW.md
  04_HERMES_FINAL_SUMMARY.md
  TRANSCRIPT.md
```

## Escalation Rules

- Use Ollama for cheap local rough classification.
- Use Gemini for lead/proposal summarization and second opinions.
- Use Perplexity only when current external facts or sources matter.
- Use Codex when local files, code, scripts, tests, or implementation are involved.
- Use Claude (via Tripartite Bridge) for automated high-assurance review after Codex output exists.
- Use Claude manually for interactive architecture critique or complex reasoning.
- Use IDE resources manually when Josh chooses to spend desktop/free quota; copy meaningful output back into tracked artifacts.
- Ask Josh before client-facing commitments, paid API use, credentials, or proposal submission.

## Pre-Flight Plan

Canonical staged test plan:

```text
E:\AgentOS\docs\PRE_FLIGHT_TEST_PLAN.md
```

Do not start real client task knowledge accumulation until the pre-flight plan records acceptable results for Hermes 24h operation and the first safe multi-resource tests.

## Current Non-Goals

- Do not build a new daemon or queue yet.
- Do not make Claude, Perplexity, Ollama, Antigravity, Perplexity IDE, VSCode Cline, or Cursor automatic workers until their handoff is tested.
- Do not bypass the `data\codex_tasks\...\OUTPUTS\RESULT.md` return contract for Codex work.

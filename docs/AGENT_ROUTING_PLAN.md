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

## Hermes Internal Load Split

Hermes is the coordinator, but not every Hermes task deserves Gemini quota.
Split Hermes work by mode:

| Hermes mode | Main work | Preferred model/resource |
|---|---|---|
| Operator Interface | Telegram intake, status replies, approval boundaries | Ollama by default; Gemini only for ambiguity |
| Orchestrator / Planner | Routing decisions, Codex task packets, escalation calls | Gemini Flash normally; Ollama for low-risk drafts |
| Scout / Research Coordinator | Lead discovery, lead summaries, source-backed research | Gemini or Perplexity/manual research |
| Watchtower / Monitor | Checkpoints, process/Git/security status | Ollama by default |
| Notes Curator | Durable insight classification and append-only notes | Ollama by default; Gemini for synthesis |
| Proposal Coordinator | Proposal drafts, client-facing preparation | Gemini; Claude review for high-risk cases |

When Gemini is rate-limited, Hermes must enter degraded mode:

```text
/model ollama
```

Allowed in degraded mode:

- Telegram status replies.
- Health checks and checkpoint summaries.
- Formatting, classification, and durable-note triage.
- Creating low-risk routing drafts for Josh review.

Deferred in degraded mode unless Josh explicitly approves:

- Proposal-quality writing.
- Real lead analysis that affects business decisions.
- High-impact architecture planning.
- Repeated Gemini retry loops.

Exit degraded mode with:

```text
/model gemini-flash
/model status
```

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

## Autonomous Coordination Mode

Default operating target: Josh should not act as the relay between Hermes,
Codex, and Claude.

Hermes must coordinate other agents directly through the existing bridge
scripts and file artifacts whenever the next step does not require Josh
approval.

```text
Josh intent / approval boundary
  -> Hermes classifies and routes
  -> Hermes creates task or review packet
  -> Hermes invokes Codex and/or Claude bridge where available
  -> Codex/Claude write evidence artifacts
  -> Hermes reads artifacts and updates Josh only when useful or required
```

Allowed autonomous coordination:

- Hermes creates Codex task packets for read-only review, implementation, or
  verification work.
- Hermes invokes Codex through `scripts\hermes_codex_bridge.ps1` when the task
  is within an approved/non-destructive scope.
- Hermes invokes Claude through `scripts\hermes_claude_bridge.ps1` for
  inspector reviews or risk analysis.
- Hermes invokes `scripts\hermes_tripartite_bridge.ps1` when Codex output
  should be reviewed by Claude before summarizing to Josh.
- Hermes records all results under `data\codex_tasks\...`, `data\live_bridge\...`,
  or the relevant workflow/project artifact.

Josh approval is required before Hermes or any worker executes:

- deletion, archive, or cleanup actions;
- `.gitignore` changes unless Josh already approved the exact scope;
- governance or role-boundary changes;
- install/update commands;
- credential, token, OAuth, or auth-profile changes;
- client-facing messages or proposal submission;
- live external operations that spend money, contact third parties, or may
  violate platform rules.

If a bridge fails, Hermes must not ask Josh to manually relay every intermediate
message. Hermes should:

1. write a blocked artifact with the failing command, error, and attempted
   bridge path;
2. retry only if the failure is transient and within the task rules;
3. ask Josh for help only when approval, credentials, provider quota, or manual
   desktop interaction is required.

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

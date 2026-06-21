# AgentOS Pre-Flight Test Plan

Updated: 2026-06-21 22:33 Asia/Taipei
Purpose: Define the staged tests required before AgentOS starts using real client tasks to accumulate case knowledge.

## Current Understanding

The current goal is to test whether the whole AgentOS loop can run correctly before using real client work.

Current intended roles:

```text
Hermes = brain / coordinator / Telegram entry
Hermes model brain = Gemini
Coder = Codex
Reviewer = Claude
Research = Perplexity
Local fallback / cheap triage = Ollama
Manual IDE resources = Antigravity IDE, Perplexity IDE, VSCode + Cline free, Cursor free quota
```

## Test Status

| Layer | Status | Evidence |
|---|---|---|
| Git traceability | Passed | Git repo initialized, commits exist |
| File-packet workflow | Passed with mock data | Mock lead -> screening -> proposal -> Codex result |
| Routing workflow | Passed with internal smoke test | `data\codex_tasks\2026-06-21-agentos-docs-consistency-smoke\OUTPUTS\RESULT.md` |
| Hermes -> Codex live CLI bridge | Passed | `data\live_bridge\2026-06-21-0036-live-ascii\TRANSCRIPT.md` |
| Hermes 24h unattended operation | Not yet proven | Need sustained gateway/cron/watchdog observation |
| Telegram-triggered Codex dispatch | Not yet proven | Direct CLI bridge works; Telegram automation not tested |
| Claude reviewer loop | Not yet tested | Claude CLI exists, reviewer handoff not tested |
| Perplexity research loop | Not yet tested | Subscription user-reported; integration not verified |
| Ollama triage loop | Not yet tested in routing | Models available; needs simple classification task |
| IDE resource loop | Not yet tested | Antigravity, Perplexity IDE, VSCode/Cline, Cursor are manual resources for now |
| Real lead -> proposal -> knowledge loop | Not yet started | No real Hermes lead file observed yet |

## Pre-Flight Sequence

### Stage 1 - Read-Only Health Check

Goal: Use the working Hermes-Codex bridge for a harmless read-only AgentOS health check.

Expected flow:

```text
Hermes CLI -> Codex CLI -> Hermes CLI
Codex action: inspect local status only
Output: data\live_bridge\<id>\TRANSCRIPT.md
```

Pass criteria:

- Codex confirms repo status, key docs, latest bridge transcript, and known blockers.
- No files are changed.
- Hermes summarizes result for Josh.

### Stage 2 - Ollama Local Triage

Goal: Prove a local model can handle cheap classification without cloud quota.

Test task:

- Input: one mock lead or one synthetic task description.
- Output: `fit=good|watch|reject`, `reason=<short reason>`.

Pass criteria:

- Ollama command runs locally.
- Output is saved under `data\routing_decisions\` or `data\local_model_tests\`.
- Hermes records whether the output is usable.

### Stage 3 - Gemini Brain / Summary

Goal: Confirm Hermes/Gemini can summarize the same task and produce a Josh-facing note.

Pass criteria:

- Gemini/Hermes output is readable.
- It does not create client-facing commitments.
- It writes or is copied into a tracked artifact.

### Stage 4 - Claude Reviewer

Goal: Use Claude as reviewer, not coder, on an existing Codex result.

Test input:

- A prior `OUTPUTS\RESULT.md`.

Expected output:

- `data\reviews\YYYY-MM-DD-<slug>-claude-review.md`

Pass criteria:

- Claude gives review findings or says no issues.
- No direct client commitments.
- Hermes summarizes whether Claude found anything actionable.

### Stage 5 - Perplexity Research

Goal: Prove Perplexity can support source-based research for lead/project context.

Pass criteria:

- Source links/citations are captured in an artifact.
- Output is not treated as final unless sources are present.
- No client contact.

### Stage 6 - IDE Manual Resource Check

Goal: Register desktop/manual coding resources without pretending they are automated agents.

Resources:

- Antigravity IDE subscribed desktop quota
- Perplexity IDE
- VSCode + Cline free
- Cursor free quota

Pass criteria:

- Each resource has a documented role and boundary.
- No resource is called an automated worker until there is a tested CLI/API handoff.

### Stage 7 - 24h Hermes Operation

Goal: Confirm Hermes can stay operational long enough for real business flow.

Minimum check window:

```text
24 hours
```

Signals to collect:

- Hermes gateway state
- Hermes cron status
- Watchdog state
- Model fallback state
- Telegram delivery behavior
- Lead patrol output file presence

Expected artifacts:

```text
logs\watchdog_state.json
logs\model_fallback_state.json
docs\SETUP_STATUS.md
progress_log.md
data\leads\YYYY-MM-DD.md, if lead patrol succeeds
```

Pass criteria:

- Hermes remains reachable or watchdog recovers it.
- Cron/lead patrol behavior is understood and recorded.
- Any gateway/scheduler mismatch is explicitly recorded.

### Stage 8 - First Real Task Knowledge Loop

Only start after Stage 7 is acceptable.

Expected loop:

```text
Real Hermes lead or Josh-approved internal task
  -> screening
  -> proposal / task packet
  -> Codex implementation or validation
  -> Claude review if high risk
  -> Hermes summary
  -> knowledge note
```

Knowledge artifact path:

```text
E:\AgentOS\data\knowledge\YYYY-MM-DD-<topic>.md
```

Pass criteria:

- The loop uses real input, not mock data.
- The result is reusable knowledge for future cases.
- Josh approval is required before any client-facing action.

## Current Answer To "Have We Done The Loop?"

Partial, but not production-ready.

Done:

- Mock file-packet loop.
- Internal routing loop.
- Direct Hermes-Codex CLI bridge.

Not done yet:

- Hermes 24h unattended operation.
- Telegram-triggered Codex dispatch.
- Claude reviewer loop.
- Perplexity research loop.
- Ollama routed triage loop.
- IDE/manual-resource loop.
- Real task knowledge accumulation loop.

## Current Non-Goals

- Do not start real client outreach until 24h Hermes operation is understood.
- Do not call desktop IDE quotas automated agents.
- Do not let reviewer/resource tools make business commitments.
- Do not replace the file-packet audit trail with hidden chat-only work.

# AgentOS Cost-Saving Routing Protocol v0.1

Updated: 2026-06-24 23:40 Asia/Taipei
Owner: Josh Hsu
Editor: Codex

## Purpose

AgentOS optimizes for completed work per dollar, not maximum model
intelligence per message.

Hermes should not spend metered Gemini API quota on routine coordination,
formatting, cleanup planning, status reports, or evidence checks when Codex,
Claude, Ollama, or deterministic routing rules can do the work.

This protocol defines a minimal cost-saving routing layer:

```text
Josh typed request
  -> deterministic TYPE routing
  -> prompt pack template
  -> compact context pack
  -> Codex / Claude / Ollama worker
  -> Codex verifier when claims need checking
  -> Gemini API only as premium exception
```

## Core Rule

Hermes must prefer structured dispatch over free-form reasoning.

If Josh provides a recognized `[TYPE: ...]`, Hermes must not use Gemini for
open-ended task interpretation. Hermes should route by table, assemble the
matching prompt template, and hand the task to the assigned worker.

## Cost Classes

| Resource | Cost class | Default use |
|---|---|---|
| Codex CLI | subscription | Build, edit, verify, inspect files, run tests |
| Claude CLI | subscription | Risk review, architecture critique, checklist work, parallel analysis |
| Ollama | local | Intake classification, format checks, low-risk summaries |
| Gemini API | api_metered | Premium synthesis, proposal-quality writing, high-value lead reasoning |
| Perplexity / IDEs | manual | Manual research or coding assistance until automation is verified |

## Typed Dispatch v0.1

Josh may use the following input shape:

```text
[TYPE: CODEX_VERIFY]
[GOAL: Verify Hermes latest report]
[TARGET: commit or path]
[CONSTRAINTS: no cleanup, no external calls]
[OUTPUT: verifier report]
```

Recognized types:

| TYPE | Route to | Template | Context pack | Gemini allowed |
|---|---|---|---|---|
| `CODEX_BUILD` | Codex | `prompts/task_templates/codex_build.md` | `repo_task` | No |
| `CODEX_VERIFY` | Codex | `prompts/task_templates/codex_verify.md` | `evidence_verification` | No |
| `CLAUDE_REVIEW` | Claude | `prompts/task_templates/claude_review.md` | `evidence_verification` | No |
| `CLAUDE_WORKER` | Claude | `prompts/task_templates/claude_worker.md` | `minimal` or `repo_task` | No |
| `OLLAMA_TRIAGE` | Ollama | `prompts/task_templates/ollama_triage.md` | `minimal` | No |
| `JOSH_APPROVAL` | Hermes records approval | none | approval target only | No |
| `GEMINI_PREMIUM` | Gemini API | explicit Josh-approved prompt | minimal, targeted | Yes |
| `STOP` | Hermes stops discretionary work | none | none | No |

Unknown types must be treated as `context` until Josh clarifies.

## Gemini Freeze Rule

Gemini API is frozen by default for routine AgentOS operations.

Gemini API may be used only when at least one condition is true:

- Josh explicitly uses `[TYPE: GEMINI_PREMIUM]`.
- A high-value proposal or lead decision requires premium synthesis.
- Codex and Claude are insufficient for the task and Hermes records why.
- A blocker cannot be resolved by deterministic routing, Codex, Claude, or
  Ollama.

Before using Gemini API, Hermes must write:

```text
gemini_use_request:
  reason:
  cheaper_resources_considered:
  expected_value:
  approval_source:
```

If approval is not explicit, `approval_source` must be `not_approved` and
Gemini must not be used.

## Context Shrinking

Agents must not pass full conversation history unless Josh explicitly asks.

Use compact context packs:

- `minimal`: task goal, constraints, output schema.
- `repo_task`: minimal plus relevant file paths and acceptance criteria.
- `evidence_verification`: target claims, artifact paths, git commands, expected evidence.
- `cleanup_approval`: manifest path, exact proposed actions, approval status.

Context packs should reference file paths instead of copying large file
contents when the receiving tool can read files directly.

## Routing Cache v0.1

AgentOS may keep a simple append-only routing cache at:

```text
data/routing/routing_cache.jsonl
```

Each line records a prior deterministic routing decision:

```json
{"timestamp":"","type":"","route_to":"","template":"","context_pack":"","reason":"","gemini_used":false}
```

This is not semantic caching. It is an audit trail and repeat-routing hint.

## Budget State v0.1

AgentOS may keep coarse cost guard state at:

```text
data/routing/budget_state.json
```

The file records policy, not exact billing:

```json
{
  "gemini_api_mode": "frozen",
  "default_router": "typed_dispatch",
  "premium_use_requires_explicit_type": true,
  "last_reviewed": "2026-06-24"
}
```

Exact token, cost, or quota numbers must not be invented. Use measured values
only when a reliable counter exists.

## Prompt Pack Rule

Hermes should assemble prompts from stable pieces:

```text
role_header + task_template + context_pack + output_contract
```

Hermes should not improvise long prompts for Codex or Claude when a template
exists.

## Circuit Breakers

Stop and ask Josh before:

- Gemini API premium use without explicit `[TYPE: GEMINI_PREMIUM]`.
- deletion, archiving, or cleanup;
- install/update commands;
- credential, token, OAuth, or auth-profile changes;
- client-facing messages;
- live external actions that may spend money or violate platform rules.

## Success Criteria for v0.1

- Typed requests can be routed without Gemini reasoning.
- Codex and Claude receive stable task templates.
- Reports identify resource contribution and cost class.
- Gemini remains frozen except for explicit premium tasks.
- No new daemon, queue, database, or hidden automation is introduced.

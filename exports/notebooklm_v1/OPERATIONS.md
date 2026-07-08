# AgentOS OPERATIONS

- generated_at: 2026-07-05 11:36:06 +08:00
- source_of_truth: local_git
- notebooklm_role: human_auxiliary_retrieval
- exclusive_definition: Current operating procedures, routing rules, setup guidance, and active workflow instructions.
- source_count: 12

---

## Source: docs\AGENT_ROUTING_PLAN.md

# AgentOS Agent Routing Plan

Updated: 2026-06-24 23:40 Asia/Taipei
Purpose: Minimal routing rules for assigning work across Hermes, Codex, Gemini, Claude, Perplexity, Ollama, and manual IDE resources without adding a new agent framework.

## Routing Principle

Use file artifacts first. Hermes coordinates, then assigns explicit work packets or review notes to the cheapest reliable resource for the task.

Cost-saving typed dispatch is defined in:

```text
docs\COST_SAVING_ROUTING_PROTOCOL.md
```

When Josh provides a recognized `[TYPE: ...]`, Hermes should route by the
protocol table and prompt pack instead of using Gemini for free-form task
interpretation.

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

Typed requests should use this shape whenever possible:

```text
[TYPE: CODEX_VERIFY]
[GOAL: Verify a claim or artifact]
[TARGET: commit, file, or report path]
[CONSTRAINTS: no cleanup, no external calls]
[OUTPUT: verifier report path]
```

Recognized v0.1 types:

- `CODEX_BUILD`
- `CODEX_VERIFY`
- `CLAUDE_REVIEW`
- `CLAUDE_WORKER`
- `OLLAMA_TRIAGE`
- `JOSH_APPROVAL`
- `GEMINI_PREMIUM`
- `STOP`

Unknown types must be treated as context until Josh clarifies.

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

Typed dispatch should happen before invoking a bridge when Josh provides a
`[TYPE: ...]` request:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\typed_dispatch.ps1 -InputText "<TYPED_REQUEST>"
```

The typed dispatch runner only creates routing artifacts and assembled prompts.
It does not call Gemini, Codex, Claude, Ollama, or external services.

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

## Resource Contribution and Cost Routing

AgentOS should route work with both quality and resource economics in mind.

Codex and Claude are subscription/capacity resources. Gemini API is metered
usage. Ollama is local zero-cost compute. Perplexity and IDE tools are manual
subscription resources until their automation paths are verified.

Routing principles:

- Do not burn Gemini API quota on work that Codex, Claude, or Ollama can do
  reliably.
- Keep Gemini API frozen for routine work unless Josh uses
  `[TYPE: GEMINI_PREMIUM]` or an explicit premium-use approval is recorded.
- Do not force Codex or Claude usage just to consume quota; route useful work
  that matches their strengths.
- Prefer Codex for implementation, file inspection, scripts, tests, and
  independent claim verification.
- Prefer Claude for parallel review, risk analysis, acceptance checklist
  preparation, architecture critique, and overclaim detection.
- Prefer Ollama for low-risk classification, formatting, watchtower summaries,
  and routine status triage.
- Use Gemini for Hermes planning, proposal-quality language, nuanced lead
  analysis, and synthesis where cheaper resources are insufficient.
- Use Perplexity/manual tools only when fresh external sources or manual
  subscription capabilities are actually needed.
- Assemble Codex and Claude prompts from the prompt pack under `prompts\`
  rather than improvising long prompts.

Every multi-agent task should end with a contribution distribution summary:

```text
resource_contribution_summary:
  - resource: Hermes
    role: coordinator
    contribution:
    artifacts:
    cost_class: api_metered | subscription | local | manual | unknown
    usage_basis: measured | estimated | not_available
  - resource: Codex
    role: builder_or_verifier
    contribution:
    artifacts:
    cost_class: subscription
    usage_basis: measured | estimated | not_available
  - resource: Claude
    role: inspector_or_worker
    contribution:
    artifacts:
    cost_class: subscription
    usage_basis: measured | estimated | not_available
  - resource: Gemini
    role: brain_or_synthesis
    contribution:
    artifacts:
    cost_class: api_metered
    usage_basis: measured | estimated | not_available
next_allocation_recommendation:
underused_resources:
overused_resources:
api_cost_reduction_opportunities:
```

This summary is not a billing statement unless real usage counters exist. If
usage is estimated or unavailable, reports must say so explicitly.

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

---

## Source: docs\COST_SAVING_ROUTING_PROTOCOL.md

# AgentOS Cost-Saving Routing Protocol v0.1

governance_source: E:\AgentOS\AGENTS.md

This file defines routing and cost mechanics. It cannot override shared role,
approval, deletion, or evidence rules.

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
| Claude CLI | subscription | Default governed workspace implementation and revision work |
| Ollama | local | Intake classification, format checks, low-risk summaries |
| Groq | free-plan limited / guarded | Routine chat window candidate and short classification only |
| OpenRouter | free-model-only / guarded | Backup chat window candidate through `openrouter/free` or `:free` models only |
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
| `CODEX_PLAN` | Codex | `prompts/task_templates/codex_plan.md` | `minimal` | No |
| `CODEX_BUILD` | Codex | `prompts/task_templates/codex_build.md` | `repo_task` | Legacy only |
| `CODEX_VERIFY` | Codex | `prompts/task_templates/codex_verify.md` | `evidence_verification` | No |
| `CLAUDE_REVIEW` | Claude | `prompts/task_templates/claude_review.md` | `evidence_verification` | Legacy only |
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

## Free Cloud Window Guard

Groq and OpenRouter may be tested as routine cloud chat-window candidates, but
only through the free-only guard:

```text
config\free_model_providers.json
scripts\free_model_window.ps1
```

Rules:

- default daily attempted-request cap is `30` per provider;
- paid models are not allowed;
- paid tools are not allowed;
- auto top-up is not allowed;
- failed free-window attempts must not automatically fall back to Gemini;
- Kimi API and Cloudflare Workers AI are excluded until no-extra-cost automation
  is verified.

One Josh message usually maps to one provider request, but retries, tool calls,
or multi-step workflows can consume more. Therefore local caps count attempted
provider calls, not Telegram messages.

## Cron Cost Throttle

Scheduled jobs are independent cost paths. A Telegram typed-dispatch hook does
not protect cron jobs.

`Daily-Token-Cost-Summary` must run in Hermes `no-agent` mode and use:

```text
scripts\daily_token_cost_summary_noagent.py
```

The script reads Hermes `state.db` metadata, fingerprints aggregate usage
counters, and writes a local report only when counters changed. It does not read
message content, invoke Gemini, invoke any model, or call external services.

When there is no new usage data, default stdout is empty so Hermes has nothing
to deliver.

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

## Typed Dispatch Runner

Local runner:

```text
scripts\typed_dispatch.ps1
```

Recommended invocation on Windows:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\typed_dispatch.ps1 -InputText "<TYPED_REQUEST>"
```

The runner:

- parses `[TYPE: ...]` fields;
- selects the route, prompt template, role header, and context pack;
- writes `ROUTING_DECISION.md` and `ASSEMBLED_PROMPT.md` under
  `data\routing_decisions\<dispatch_id>\`;
- appends a compact entry to `data\routing\routing_cache.jsonl`;
- does not invoke Gemini, Codex, Claude, Ollama, or external services.

Execution-policy note: direct `.\scripts\typed_dispatch.ps1` may be blocked on
Windows hosts. Use the explicit `powershell -ExecutionPolicy Bypass -File`
form above for local invocation.

## Telegram Handoff Entry

Future Hermes Telegram hooks should call the local wrapper:

```text
scripts\telegram_typed_dispatch_entry.ps1
```

This wrapper invokes `scripts\typed_dispatch.ps1` and preserves the same
no-model, no-external-service behavior. It exists so Hermes gateway integration
can be reviewed separately from the routing logic.

Do not modify Hermes external runtime or live Telegram hooks until Josh
approves the handoff step. See:

```text
docs\TELEGRAM_TYPED_DISPATCH_HANDOFF.md
```

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

## Initial Dry-Run Evidence

Validated locally without invoking any model:

- `CODEX_VERIFY` -> `route_to=Codex`, `dispatch_status=ready_to_route`,
  `models_invoked=false`
- `CLAUDE_REVIEW` -> `route_to=Claude`, `dispatch_status=ready_to_route`,
  `models_invoked=false`
- `GEMINI_PREMIUM` without approval -> `route_to=Gemini`,
  `dispatch_status=approval_required`, `models_invoked=false`

Evidence paths:

```text
data\routing_decisions\test-codex-verify-write\
data\routing_decisions\test-claude-review-write\
data\routing_decisions\test-gemini-premium-block\
data\routing_decisions\telegram-entry-test\
```

---

## Source: docs\FREE_CLOUD_WINDOW_POLICY.md

# AgentOS Free Cloud Window Policy

Updated: 2026-06-25 Asia/Taipei
Owner: Josh Hsu
Editor: Codex

## Purpose

AgentOS needs a cheap or free routine chat window so Gemini API is not used as
the default operator conversation layer.

This policy is conservative: a provider is not treated as free unless it is
configured through an explicit free-only guard.

## Current Decision

Allowed candidates:

| Provider | Status | Allowed mode |
|---|---|---|
| Groq | `candidate_free_plan_limited` | Routine chat/classification only through guard |
| OpenRouter | `candidate_free_models_only` | Free model router or `:free` models only through guard |

Excluded for now:

| Provider | Reason |
|---|---|
| Kimi API | API no-extra-cost status not verified for automation |
| Cloudflare Workers AI | Free-plan inclusion exists, but unit pricing also exists |
| Ollama | Local and no token cost, but Josh does not want it as normal chat window because it is slow |

## Guard Rules

- `allow_paid_models=false`
- `allow_paid_tools=false`
- `allow_auto_top_up=false`
- `fallback_to_gemini=false`
- default daily provider-call cap: `30`
- missing API key means `blocked_missing_api_key`
- cap reached means `blocked_daily_cap`
- default script behavior is dry-run only

Guard config:

```text
config\free_model_providers.json
```

Guard script:

```text
scripts\free_model_window.ps1
```

## Request Counting

Provider free limits are counted as API requests. In normal chat, one Josh
message usually means one provider request.

However, one Telegram message can consume more than one request if an agent
adds retries, follow-up calls, tool calls, or multi-step workflows.

AgentOS therefore uses a conservative local cap of 30 attempted requests per
provider per day before any provider is allowed to become a default window.

## Cron Must Be Controlled First

Free provider limits are unsafe if background cron jobs can spend requests
without Josh sending a message.

`Daily-Token-Cost-Summary` is therefore required to run as a Hermes `no-agent`
job through:

```text
scripts\daily_token_cost_summary_noagent.py
```

This cron path must report:

```text
models_invoked=false
external_services_invoked=false
```

No free cloud window should be wired into ordinary Telegram chat until this cron
path remains no-agent.

## Not Yet Allowed

- Do not wire Groq or OpenRouter into Hermes normal Telegram chat automatically.
- Do not use OpenRouter paid model slugs.
- Do not use OpenRouter web search, image generation, or paid tools.
- Do not use Groq built-in paid tools such as search or code execution.
- Do not enable auto top-up or add billing automation.
- Do not route ordinary messages back to Gemini when free candidates fail.

## Next Verification

Before live use:

1. Josh creates the provider account/key without enabling auto top-up.
2. Store key outside Git as `GROQ_API_KEY` or `OPENROUTER_API_KEY`.
3. Run the guard script in dry-run mode.
4. Perform one explicit live test.
5. Confirm request counter increments and no paid path is used.
6. Only then consider `/model groq` or `/model openrouter-free` aliases.

---

## Source: docs\NOTEBOOKLM_CONVEYOR.md

# NotebookLM Human Retrieval Conveyor

NotebookLM is an optional human-facing retrieval aid. It is not an AgentOS
decision layer, source of truth, verifier, or task trigger.

## Authority Boundary

- Local files and Git are authoritative.
- NotebookLM never blocks AgentOS work.
- Agents must not execute a task from a NotebookLM answer.
- If NotebookLM conflicts with local evidence, local evidence wins and the
  mismatch is reported as `retrieval_drift`.
- `PROJECT_ANALYSIS.md` and `RECOMMENDATIONS.md` are Cursor-owned and copied
  read-only. The conveyor never edits them.

## Exclusive Bundles

The export creates five fixed bundles. Every included source belongs to one
bundle only:

1. `CORE.md`: architecture, governance, and role definitions.
2. `OPERATIONS.md`: current procedures, routing, setup, and workflows.
3. `MEMORY.md`: compact current state and maintained memory indexes.
4. `PROJECT_ANALYSIS.md`: Cursor-owned analysis, copied read-only.
5. `RECOMMENDATIONS.md`: Cursor-owned proposals, copied read-only.

Knowledge Pool nodes are **not** merged into any bundle. Each node is an
independent NotebookLM source uploaded individually via
`scripts\publish_url_knowledge.ps1`. Migration audit reports are retained
separately under `data\memory\sync_logs\knowledge_pool_migration\` and must not
be uploaded to NotebookLM.

Raw task evidence, bridge transcripts, logs, temporary files, debug artifacts,
and archives are excluded.

## Schedule

- Task name: `AgentOS NotebookLM Conveyor`
- Schedule: Sunday at `03:30`
- Scheduled mode: `DryRun`
- Models invoked: `false`
- External upload from schedule: `false`

The scheduled task rebuilds the five local bundles and writes a manifest. It
does not contact NotebookLM. Knowledge Pool nodes are not rebuilt by this
task; they are published individually via `scripts\publish_url_knowledge.ps1`.

## Manual Live Upload

Josh can explicitly run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\notebooklm_conveyor.ps1 -Mode Live
```

Live mode uses fixed bundle names with content hashes. It uploads a changed
bundle, waits until the new source is ready, and only then deletes older ready
versions of that same bundle. A failed upload leaves the old source intact.

The integration uses an unofficial client and may break after Google changes.
Failure is logged and does not affect AgentOS execution.

## Evidence

- Generated bundles: `exports\notebooklm_v1`
- Bundle and run logs: `data\memory\sync_logs\conveyor`
- Export script: `scripts\export_notebooklm_sources.ps1`
- Sync script: `scripts\sync_notebooklm.py`

---

## Source: docs\PRE_FLIGHT_TEST_PLAN.md

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

---

## Source: docs\RESOURCE_INVENTORY.md

# AgentOS Resource Inventory

Updated: 2026-06-21 22:33 Asia/Taipei
Owner: Josh Hsu
Purpose: This file is the source of truth for model/tool resources that affect future AgentOS agent configuration.

## Verification Summary

Local verification performed from `E:\AgentOS`.

| Resource | Verified state | Evidence | Operational status |
|---|---|---|---|
| Codex CLI | Installed | `codex --version` -> `codex-cli 0.138.0` | Primary technical execution tool |
| Gemini CLI | Installed | `gemini --version` -> `0.46.0` | Research/summarization/support tool |
| Claude Code CLI | Active via tripartite bridge | `claude auth status` -> `loggedIn: true` | Active Inspector via tripartite bridge for tested review handoffs |
| Claude Pro subscription | Verified via CLI | `claude auth status` | Pro quota available for CLI and manual use |
| Perplexity subscription | User-reported | Josh reports active subscription | Useful for research; no local AgentOS CLI/API integration verified |
| Ollama | Installed | `ollama list` succeeded | Local fallback/small model pool |
| Antigravity IDE desktop subscription | User-reported | Josh reports subscribed desktop usage quota | Manual IDE resource; no AgentOS CLI/API integration verified |
| Perplexity IDE | User-reported | Josh reports available IDE resource | Manual research/coding assistant; no AgentOS automation verified |
| VSCode + Cline free | User-reported | Josh reports available free-tier resource | Manual IDE/agent resource; no AgentOS automation verified |
| Cursor free quota | User-reported | Josh reports available free quota | Manual IDE coding resource; no AgentOS automation verified |
| Groq API | Candidate only | Official docs show free API key/free-plan limits and paid token pricing | Guarded free-plan chat-window candidate; not wired into Hermes default |
| OpenRouter API | Candidate only | Official FAQ documents free models with low rate limits and credit-based billing | Guarded free-model-only backup candidate; not wired into Hermes default |
| Kimi API | Deferred | Kimi web/app free use exists with limits, but API no-extra-cost automation is not verified | Manual web only for now |
| Cloudflare Workers AI | Deferred | Free-plan inclusion exists, but unit pricing also exists | Not treated as guaranteed zero-cost automation |

## Ollama Local Models

Verified with `ollama list`:

| Model | Size | Recommended use |
|---|---:|---|
| `qwen3:8b` | 5.2 GB | Local general reasoning outside Hermes; not valid as Hermes default because context is 40,960, below Hermes minimum 64K |
| `qwen2.5-coder:7b` | 4.7 GB | Local code explanation, small script drafts, fallback code review |
| `qwen3.5:9b` | 6.6 GB | Preferred Hermes Ollama fallback; verified context is 262,144 |
| `llama3.2:3b` | 2.0 GB | Fast local classification, rough summaries, low-stakes preprocessing; verified context is 131,072 |

## Recommended Agent Configuration

### Hermes

Default role: coordinator, Telegram brain, lead workflow owner.

Recommended resource stack:

1. Gemini API through Hermes config for proposal-quality reasoning, lead
   analysis, and high-value planning.
2. Ollama for low-risk Telegram status replies, monitoring checkpoints,
   classification, formatting, and durable-note triage.
3. Gemini CLI for manual research/summarization support when Hermes needs a
   second pass.
4. Perplexity subscription for current web research and source discovery, used
   manually or through a future verified integration.

Hermes should not use Codex/Claude directly for client-facing commitments. Hermes can ask Josh to dispatch a technical packet to Codex.

Rate-limit policy:

- If Gemini rate-limits Hermes, switch the Telegram brain to Ollama with
  `/model ollama`. This should resolve to `qwen3.5:9b`, not `qwen3:8b`,
  because Hermes requires at least 64K context.
- While on Ollama, keep Hermes in low-risk modes: Operator Interface,
  Watchtower / Monitor, Notes Curator, and simple routing drafts.
- Defer proposal-quality writing and business-critical lead analysis until
  Gemini is available again, unless Josh explicitly approves the lower-quality
  fallback.
- Resume normal mode with `/model gemini-flash` and verify with
  `/model status`.

### Codex

Default role: technical execution specialist.

Recommended resource stack:

1. Codex CLI as the primary implementation runner.
2. Claude Code CLI as an optional manual second-opinion/code-review resource after the workflow is explicitly designed.
3. Ollama coder models for small local drafts or fallback analysis, not final authority.

Codex should continue writing `OUTPUTS\RESULT.md` for task packets.

### Gemini

Default role: research, summarization, proposal second opinion, quota fallback support.

Recommended resource stack:

1. Gemini CLI for ad hoc summaries and lead/proposal review.
2. Hermes Gemini API configuration for scheduled Hermes work.
3. Perplexity for current web/source-oriented research when needed.

Gemini output should be folded back into Hermes-managed files and should not become a separate state store.

### Claude

Current state:

- Claude Code CLI is active and verified through the `hermes_tripartite_bridge.ps1`.
- Claude Pro subscription is verified via CLI auth status.

Recommended role:

- **Inspector**: High-assurance technical review of Codex output.
- **Architecture Critique**: Complex reasoning about system design.
- **Second Opinion**: Final safety check before destructive or client-facing actions.
- Use `scripts/hermes_tripartite_bridge.ps1` for automated coordination.

### Perplexity

Current state:

- Subscription is user-reported.
- No local CLI/API integration has been verified inside AgentOS.

Recommended role for now:

- Current market/client/tool research.
- Lead background research.
- Competitive/reference discovery.
- Do not treat Perplexity output as final unless citations/sources are captured in the relevant artifact.

### Antigravity IDE Desktop

Current state:

- Desktop subscription/usage quota is user-reported.
- No AgentOS automation interface has been verified.

Recommended role for now:

- Manual coding/IDE resource when Josh wants to spend desktop quota.
- Not part of Hermes automated orchestration until there is a tested CLI/API/workflow handoff.

### Other Manual IDE Resources

Current state:

- Perplexity IDE is user-reported.
- VSCode + Cline free is user-reported.
- Cursor free quota is user-reported.
- Cursor maintains protected third-party analysis artifacts:
  `PROJECT_ANALYSIS.md` and `RECOMMENDATIONS.md`.
- No AgentOS automation interface has been verified for these resources.

Recommended role for now:

- Manual coding/research/review support.
- Useful for interactive work when Josh chooses to spend free or subscribed quota.
- Outputs should be copied into tracked AgentOS artifacts if they affect decisions.
- Not part of Hermes automated orchestration until a tested CLI/API/workflow handoff exists.
- Cursor-owned artifacts may be read and cited, but must not be modified,
  reformatted, cleaned, archived, or deleted by non-Cursor agents.

### Free Cloud Chat Window Candidates

Current state:

- Groq and OpenRouter are candidates only.
- AgentOS has a free-only guard config at `config\free_model_providers.json`.
- AgentOS has a dry-run-first guard script at `scripts\free_model_window.ps1`.
- No provider is wired into Hermes default Telegram chat yet.
- Kimi API and Cloudflare Workers AI are excluded from automation until
  no-extra-cost status is verified.

Recommended role:

1. Groq: primary candidate for routine chat, short summaries, and typed request
   normalization, only while free-plan/no-extra-cost use is confirmed.
2. OpenRouter: backup candidate using `openrouter/free` or `:free` model slugs
   only.
3. Both candidates must obey the local daily attempted-request cap of 30.
4. Neither candidate may use paid tools, auto top-up, paid model slugs, or
   automatic Gemini fallback.

## Routing Rules

Use the cheapest reliable resource that fits the task:

- Local Ollama: low-risk categorization, rough summaries, private/offline drafts.
- Gemini: bulk reasoning, lead summaries, proposal second opinions.
- Perplexity: current web research with sources.
- Codex: repo edits, scripts, tests, debugging, implementation artifacts.
- Claude: automated high-assurance review (tripartite bridge) or manual complex reasoning.
- Groq: guarded routine cloud chat candidate, not yet wired into Hermes default.
- OpenRouter: guarded free-model backup candidate, not yet wired into Hermes default.
- Antigravity / Perplexity IDE / VSCode Cline / Cursor: manual IDE work, not yet automated.
Escalate resource choice when:

- A proposal depends on technical feasibility: create a Codex task packet.
- Current market/client facts matter: use Perplexity or another source-capturing research path.
- A codebase change is high risk: use Codex first, optionally ask Claude for review.
- Quota/cost pressure appears: use Gemini/Ollama for low-risk analysis, keep Codex/Claude for high-value work.

## Current Non-Goals

- Do not build a new multi-agent framework around these resources yet.
- Do not make Claude, Perplexity, Antigravity, Perplexity IDE, VSCode Cline, or Cursor automatic workers until their handoff paths are tested.
- Do not route client-facing messages directly through any model without Josh approval.
- Do not assume a subscription equals API or CLI automation access.

---

## Source: docs\SETUP_STATUS.md

# Hermes Agent Setup Status

Updated: 2026-06-20 (Asia/Taipei)
Actor: Codex

## Summary

Hermes Agent model authentication was tested and repaired.

## Findings

- Hermes install path: `E:\AI_Projects_Hub\External_AI_Agents\hermes-agent`
- Hermes executable: `E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\.venv\Scripts\hermes.exe`
- Hermes env file: `C:\Users\brian\AppData\Local\hermes\.env`
- Initial `.env` check: `GEMINI_API_KEY` line was missing, not populated.
- Existing usable key source found: user-level `GOOGLE_API_KEY` environment variable.
- Existing config was using `google-gemini-cli` OAuth provider with `cloudcode-pa://google` base URL.

## Fixes Applied

- Rebuilt broken Hermes `.venv`; it had pointed at a missing WindowsApps Python 3.11/3.13 alias.
- Installed project-local standalone Python via `uv` and rebuilt `.venv` against it.
- Confirmed `hermes.exe --version` works: Hermes Agent v0.14.0, Python 3.13.13.
- Added `GEMINI_API_KEY` alias to `C:\Users\brian\AppData\Local\hermes\.env` using the existing `GOOGLE_API_KEY` value.
- Updated Hermes model config:
  - `model.provider = gemini`
  - `model.default = gemini-3-flash-preview`
  - `model.base_url = https://generativelanguage.googleapis.com/v1beta/openai`

## Test Result

Command:

```powershell
.\.venv\Scripts\hermes.exe -z test
```

Result: success.

Hermes response included:

```text
Test received. I am operational and ready to assist.
```

## Gateway Status

Started requested gateway command in the background:

```powershell
python cli.py --gateway
```

Observed running Python processes with command line:

```text
E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\.venv\Scripts\python.exe cli.py --gateway
E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\.uv-python\cpython-3.13-windows-x86_64-none\python.exe cli.py --gateway
```

Gateway stdout log at `E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\gateway_stdout.log` shows:

```text
Starting Hermes Gateway (messaging platforms)...
```

Caveat: `hermes.exe gateway status` reports `Gateway is not running`, apparently because this command checks the installed service status rather than the legacy/manual `python cli.py --gateway` process.

## Current State

- Model authentication: working with Gemini API key.
- `hermes.exe`: working after venv repair.
- One-shot Hermes test: passed.
- Gateway manual process: running.
- Installed gateway service status: not running / not installed as active service.

## AgentOS Remaining Setup - 2026-06-20

### 1. Hermes proxy for Codex CLI

Target requested: `http://localhost:8080`.

Actions performed:

- Checked Hermes proxy CLI: this Hermes version supports `hermes proxy start --provider nous|xai`; default port is `8645`, so AgentOS uses `--port 8080`.
- Checked proxy upstreams with `hermes proxy status`.
- Attempted to start proxy on `127.0.0.1:8080` with provider `nous`.
- Tested `http://localhost:8080/v1/models`.
- Rewrote `E:\AgentOS\scripts\start.ps1` with the correct AgentOS root and correct Hermes commands.
- PowerShell parse check for `start.ps1`: OK.

Result:

- Proxy did **not** come up on `localhost:8080`.
- Startup blocker: `Not logged into Nous Portal. Run hermes login nous first.`
- `hermes proxy status` reports:
  - `nous` — not logged in
  - `xai` — not logged in
- Important limitation: this Hermes proxy build exposes only `nous` and `xai` upstream adapters. It does not expose a `claude`/`anthropic` upstream adapter, so Claude subscription proxying cannot be confirmed from the current Hermes proxy without a supported OAuth upstream/login path.

Current script:

```powershell
E:\AgentOS\scripts\start.ps1
```

It starts:

- `hermes gateway run --accept-hooks`
- `hermes proxy start --provider nous --host 127.0.0.1 --port 8080`

and sets current-session:

```powershell
OPENAI_BASE_URL=http://localhost:8080/v1
```

### 2. Hermes cron lead patrol

Created Hermes cron job:

- Job id: `d00fbf284738`
- Name: `daily-upwork-lead-patrol`
- Schedule: `0 8 * * *`
- Next run: `2026-06-21T08:00:00+08:00`
- Delivery: `telegram`
- Workdir: `E:\AgentOS`

Prompt summary:

Search Upwork for new Google Apps Script and Sheets Automation jobs, include relevant jobs with visible budget `$500+`, summarize title/URL/budget/client notes/fit score/recommended next action, and deliver to Josh via Telegram. If no qualifying jobs are found, send a short no-match report.

Verification:

- `hermes cron list` shows the job as `[active]`.
- Caveat: Hermes currently reports `Gateway is not running — jobs won't fire automatically.` The legacy/manual `python cli.py --gateway` process exists, but Hermes cron/status does not recognize it as the scheduler gateway. Use `E:\AgentOS\scripts\start.ps1` or install the gateway service with Hermes if persistent automatic cron execution is required.

### 3. OpenClaw / Hermes Telegram bot conflict check

Checked Hermes Telegram token from `C:\Users\brian\AppData\Local\hermes\.env` and OpenClaw Telegram secret reference from `C:\Users\brian\.openclaw-ai-hub\openclaw.json` / environment variable `TELEGRAM_BOT_TOKEN`.

Result:

- Hermes Telegram bot id: `8606793349`
- OpenClaw Telegram bot id: `8680039302`
- Token hash fingerprints differ.
- Conclusion: OpenClaw and Hermes are configured with different Telegram bots and should not compete for the same bot update stream.

No token values were written to this status file.

## Task 1 - Hermes SOUL.md Updated

Updated: 2026-06-20

Result: Updated C:\Users\brian\AppData\Local\hermes\SOUL.md so Hermes identifies as the AgentOS brain for Josh's freelance automation system, with Codex/Gemini delegation rules, Telegram behavior, AgentOS paths, and safety constraints.

## Task 2 - Hermes Proxy / Codex CLI Bridge

Updated: 2026-06-20

Result: `E:\AgentOS\scripts\start.ps1` exists and starts Hermes gateway plus Hermes proxy on `127.0.0.1:8080` using the current Hermes CLI syntax:

```powershell
hermes gateway run --accept-hooks
hermes proxy start --provider nous --host 127.0.0.1 --port 8080
```

Connectivity check: `http://localhost:8080/v1/models` did not return a usable response.

Current blocker: Hermes proxy upstreams are not authenticated:

- `nous` - not logged in
- `xai` - not logged in

Important limitation: this Hermes build exposes proxy adapters for `nous` and `xai`; it does not expose a native `claude`/`anthropic` proxy adapter. Claude subscription bridging through Hermes proxy cannot be completed until a supported OAuth upstream is logged in or Hermes gains/uses a Claude-compatible upstream adapter.
## Task 3 - Hermes Cron Schedule

Updated: 2026-06-20

Result: two Hermes cron jobs are active.

1. `daily-agentos-health-check`
   - Job id: `c22498762626`
   - Schedule: `55 7 * * *`
   - Next run: `2026-06-21T07:55:00+08:00`
   - Delivery: `telegram`
   - Workdir: `E:\AgentOS`
   - Purpose: gateway/proxy/cron/provider/quota health report to Josh.

2. `daily-upwork-lead-patrol`
   - Job id: `d00fbf284738`
   - Schedule: `0 8 * * *`
   - Next run: `2026-06-21T08:00:00+08:00`
   - Delivery: `telegram`
   - Workdir: `E:\AgentOS`
   - Purpose: Upwork Google Apps Script / Sheets Automation lead patrol for visible `$500+` opportunities.

Caveat: `hermes cron list` still warns `Gateway is not running — jobs won't fire automatically.` The jobs exist, but automatic firing requires `hermes gateway run` to stay active or installing the Hermes gateway service.

## Task 4 - Codex Task Receiving Mechanism

Updated: 2026-06-20

Result: Created E:\AgentOS\workflows\hermes_to_codex.md. It defines the Hermes-to-Codex delegation protocol, task packet directory structure, TASK.md format, dispatch commands, OUTPUTS\RESULT.md return format, retry/blocker handling, and status values.

## Task 5 - AI_Freelancer_OS Integration

Updated: 2026-06-20

Result: AI_Freelancer_OS storage and proposal workflow are now defined.

Created/confirmed directories:

- `E:\AgentOS\data\leads\`
- `E:\AgentOS\data\proposals\`
- `E:\AgentOS\data\codex_tasks\`
- `E:\AgentOS\data\projects\`

Created workflow document:

- `E:\AgentOS\workflows\ai_freelancer_os.md`

Lead patrol storage rule:

- Daily lead patrol must save full results to `E:\AgentOS\data\leads\YYYY-MM-DD.md` before sending Josh a Telegram summary.

Proposal draft rule:

- Pursued leads generate proposal drafts at `E:\AgentOS\data\proposals\YYYY-MM-DD-<lead-slug>.md`.
- Hermes may draft proposals, but must not submit or message clients without Josh approval.
- If technical validation is needed, Hermes creates a Codex task packet under `E:\AgentOS\data\codex_tasks\`.

Cron update:

- Updated job `d00fbf284738` so the 08:00 lead patrol explicitly writes the daily lead file and then sends Telegram summary.
## Task 6 - Machine 2 Replication Script

Updated: 2026-06-20

Result: Updated `E:\AgentOS\scripts\replicate_to_machine2.ps1`.

Capabilities:

- Copies AgentOS from `E:\AgentOS` to a target AgentOS root.
- Copies the local Hermes project from `E:\AI_Projects_Hub\External_AI_Agents\hermes-agent` to the target Hub root.
- Creates required AgentOS data directories on the target.
- Writes a safe `machine2_hermes_config\.env.template` instead of copying secrets by default.
- Optional `-IncludeHermesUserConfig` copies `config.yaml` and `SOUL.md` scaffolding.
- Optional `-IncludeSecrets` copies Hermes `.env`, with an explicit warning.
- Writes `MACHINE2_FIRST_RUN.md` to guide target machine setup.

Verification: PowerShell parser check passed for `replicate_to_machine2.ps1`.
## Task 7 - System Maintenance

Updated: 2026-06-20

Result: Added AgentOS maintenance scripts.

Created/updated scripts:

- `E:\AgentOS\scripts\watchdog.ps1`
- `E:\AgentOS\scripts\model_fallback.ps1`
- `E:\AgentOS\scripts\start.ps1` now supports `-StartWatchdog`

Watchdog behavior:

- Checks Hermes gateway process state.
- Recognizes both formal `hermes gateway run` and current legacy `cli.py --gateway` mode.
- Starts `hermes gateway run --accept-hooks` when no gateway process is found.
- Optionally checks/starts Hermes proxy with `-StartProxy`.
- Writes status to `E:\AgentOS\logs\watchdog_state.json`.

Watchdog verification:

- `watchdog.ps1 -Once` executed successfully.
- Current detected gateway mode: `legacy-cli-py-gateway`.
- Caveat: legacy gateway is running and holding the Hermes gateway runtime lock; `hermes gateway status` / `hermes cron list` still do not recognize it as the formal scheduler gateway. Do not kill it automatically unless Josh explicitly approves switching from legacy gateway to `hermes gateway run`.

Model fallback behavior:

- Runs a lightweight Hermes health prompt.
- If healthy, no change is made.
- If failure text looks like quota/rate-limit/auth/provider exhaustion, it tries fallback Gemini models:
  - `gemini-3.1-flash-lite-preview`
  - `gemini-2.5-flash`
- Writes status to `E:\AgentOS\logs\model_fallback_state.json`.

Model fallback verification:

- `model_fallback.ps1` executed successfully.
- Current result: Hermes model health OK; no model switch needed.

Script verification:

- PowerShell parser checks passed for:
  - `start.ps1`
  - `watchdog.ps1`
  - `model_fallback.ps1`
  - `replicate_to_machine2.ps1`

## Task 8 - Hermes / Codex Live CLI Bridge

Updated: 2026-06-21

Result: Added and tested `E:\AgentOS\scripts\hermes_codex_bridge.ps1`.

What was tested:

```text
Hermes CLI -> Codex CLI -> Hermes CLI
```

Successful transcript:

```text
E:\AgentOS\data\live_bridge\2026-06-21-0036-live-ascii\TRANSCRIPT.md
```

Important auth note:

- Initial `codex exec` failed because `OPENAI_API_KEY` / `CODEX_API_KEY` environment variables pointed to an invalid API key.
- Codex Doctor showed stored ChatGPT tokens are available.
- The bridge clears those two API-key environment variables only for the bridge process so Codex CLI can use stored ChatGPT auth.

Current boundary:

- Direct CLI handoff works.
- This is not yet Telegram automation.
- This is not yet a long-running daemon.
- This does not yet mean Hermes can autonomously run arbitrary Codex tasks without an explicit bridge command.

---

## Source: docs\TELEGRAM_TYPED_DISPATCH_HANDOFF.md

# Telegram Typed Dispatch Handoff Plan

Updated: 2026-06-24 23:38 Asia/Taipei
Editor: Codex

## Purpose

This document defines the clean handoff point between Hermes Telegram intake
and AgentOS typed dispatch.

The local typed-dispatch layer is ready. The Hermes user plugin has been
installed and enabled for the gateway's next session.

## Current State

Ready local entrypoint:

```text
scripts\telegram_typed_dispatch_entry.ps1
```

The entrypoint wraps:

```text
scripts\typed_dispatch.ps1
```

It only parses typed requests and writes local routing artifacts. It does not
call Gemini, Codex, Claude, Ollama, Telegram, or external services.

Hermes plugin installed:

```text
%LOCALAPPDATA%\hermes\plugins\agentos-typed-dispatch\
```

The plugin registers:

```text
pre_gateway_dispatch
```

Behavior:

- Messages containing `[TYPE: ...]` are routed into
  `scripts\telegram_typed_dispatch_entry.ps1`.
- Routed typed messages return `action=skip` to prevent Hermes' normal model
  dispatch for that message.
- Messages without `[TYPE: ...]` return `action=allow` and continue through
  the existing Hermes flow.
- The plugin sends a short Telegram confirmation when the adapter supports one
  of the common send methods.

Hermes plugin manager verification:

```text
name=agentos-typed-dispatch
key=agentos-typed-dispatch
enabled=True
hooks=1
error=None
```

## Safe Local Test

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\telegram_typed_dispatch_entry.ps1 -MessageText "[TYPE: CODEX_VERIFY]
[GOAL: Verify typed dispatch through Telegram entry wrapper]
[TARGET: scripts/telegram_typed_dispatch_entry.ps1]
[CONSTRAINTS: no cleanup, no external calls]
[OUTPUT: routing decision]"
```

Expected:

```text
route_to=Codex
dispatch_status=ready_to_route
models_invoked=false
telegram_hook_invoked=false
external_services_invoked=false
```

## Plugin Smoke Test

Codex ran a non-live fake Telegram event against the installed plugin.

Result:

```text
plain_action=allow
typed_action=skip
typed_reason_prefix=agentos_typed_dispatch
reply_count=1
reply_preview=AgentOS typed dispatch accepted.
```

Routing artifact created:

```text
data\routing_decisions\telegram-telegram-local-test-chat-local-test-msg-20260624-233441\
```

## Josh Approval Gate

Stop and ask Josh before any of the following:

- modifying the Hermes external runtime under
  `E:\AI_Projects_Hub\External_AI_Agents\hermes-agent`;
- restarting the Telegram gateway;
- changing Hermes model/provider configuration;
- testing live Telegram messages through the gateway.

## Live Activation Step

Josh explicitly approved installing and enabling:

```text
agentos-typed-dispatch pre_gateway_dispatch hook
```

The plugin is enabled, but Hermes reports plugin changes take effect on the
next session. A currently running gateway process may need a restart before
live Telegram messages use the hook.

## Non-Goals

- No new daemon.
- No new database.
- No semantic cache.
- No Gemini use for routine dispatch.
- No live Telegram test without Josh approval.

---

## Source: workflows\ai_freelancer_os.md

# AI_Freelancer_OS Integration

AI_Freelancer_OS is the AgentOS business workflow for finding leads, qualifying them, drafting proposals, and routing execution to Codex/Gemini under Hermes coordination.

This document is the source of truth for the business flow. It should consume Hermes output; it should not define a second lead-search agent.

## Data Locations

Lead patrol output must be stored in:

```text
E:\AgentOS\data\leads\YYYY-MM-DD.md
```

Screening history should be stored in:

```text
E:\AgentOS\data\screening\screening_log.md
```

Proposal drafts must be stored in:

```text
E:\AgentOS\data\proposals\YYYY-MM-DD-<lead-slug>.md
```

Project execution data should be stored in:

```text
E:\AgentOS\data\projects\<project_id>\
```

## Daily Lead Patrol

At 08:00, Hermes searches Upwork for new work matching:

- Google Apps Script
- Google Sheets automation
- Sheets dashboards/reporting
- AppSheet / Workspace automation when relevant
- Small business workflow automation with clear scripting opportunity

Filters:

- Prefer visible budget `$500+`
- Favor recently posted jobs
- Favor clients with clear requirements and good payment history
- Exclude vague, underpriced, or agency-fishing posts unless strategically useful

Daily lead file format:

```markdown
# Leads - YYYY-MM-DD

Generated: YYYY-MM-DD HH:mm Asia/Taipei
Source: Upwork
Owner: Hermes

## Summary
- Qualified leads: N
- Strongest lead: <title or none>
- Recommended action: <proposal / watch / skip>

## Leads

### 1. <Lead Title>

- URL: <url>
- Budget: <budget>
- Posted: <posted time if available>
- Client notes: <payment verified/history/location if available>
- Fit score: 1-10
- Why it fits Josh: <short reason>
- Risks: <short risk list>
- Recommended next action: draft proposal | ask clarification | skip

## No-Match Note

If no qualified leads were found, write the search terms used and why candidates were rejected.
```

Hermes must write the full daily file before sending the Telegram summary, so every Josh-facing recommendation has a durable source artifact.

If no qualified leads are found, Hermes still writes the daily file with a `No-Match Note`. This keeps the patrol auditable and avoids silent days.

## Screening Flow

Hermes is already responsible for finding real leads. Screening should not duplicate the lead search; it should consume the daily lead file produced by Hermes.

Input:

```text
E:\AgentOS\data\leads\YYYY-MM-DD.md
```

Recommended screening log path:

```text
E:\AgentOS\data\screening\screening_log.md
```

Screening requirements:

- Append new runs; do not overwrite earlier screening history.
- Record both accepted and rejected leads.
- Evaluate each lead against:
  - AI/automation fit, or Apps Script / Sheets automation fit when the task is clearly in Josh's service lane
  - technical feasibility with current AgentOS/Hermes/Codex/Gemini capabilities
  - client/budget fit, including whether visible budget is proportional to scope
- Mark confidence as high, medium, or low, with a reason.
- Do not fabricate missing client facts.
- If testing with sample leads, label them as mock data.

Screening entry format:

```markdown
## YYYY-MM-DD HH:mm Asia/Taipei - <lead title or daily batch>

- Lead file: E:\AgentOS\data\leads\YYYY-MM-DD.md
- Lead URL: <url or unavailable>
- Decision: pursue | watch | reject
- Confidence: high | medium | low
- Reason: <short rationale>
- Risks: <facts only>
- Next artifact: <proposal path, Codex task path, or none>
```

Screening output should identify one recommended next lead for proposal preparation, or say that no lead should move forward.

## Proposal Draft Flow

When a lead should move forward, Hermes first records screening, then creates a proposal draft from the lead file. Josh approval is required before any client-facing submission.

Proposal draft path:

```text
E:\AgentOS\data\proposals\YYYY-MM-DD-<lead-slug>.md
```

Proposal draft format:

```markdown
# Proposal Draft - <Lead Title>

Status: draft_for_josh_review
Lead source: <daily lead file path>
Lead URL: <url>
Created: YYYY-MM-DD HH:mm Asia/Taipei
Technical validation: not needed | queued | passed | partial | blocked

## Client Need
<plain-language summary>

## Josh Fit
<why Josh is credible for this>

## Clarifying Questions
1. <question>
2. <question>

## Proposed Approach
<short phased plan>

## Draft Message
Hi <client/name>,

<proposal text>

## Estimate Notes
- Suggested range: <range or TBD>
- Timeline: <timeline or TBD>
- Assumptions: <assumptions>

## Risks / Do Not Promise
- <risk>
```

Rules:

- Hermes may draft proposals automatically.
- Hermes must not submit proposals or message clients without Josh approval.
- If technical uncertainty exists, Hermes creates a Codex task packet under `data\codex_tasks\` to validate feasibility before final proposal wording.

## Codex Support for Proposals

Use Codex when proposal quality depends on technical validation, such as:

- Can Apps Script access the required API?
- Can Sheets formulas/scripts support the requested workflow?
- Is the deadline realistic?
- What implementation phases or tests should be proposed?

Codex returns notes to `OUTPUTS\RESULT.md`; Hermes folds the result into the proposal draft and flags any risk for Josh.

## End-To-End Handoff Contract

```text
1. Hermes searches Upwork.
2. Hermes writes `data\leads\YYYY-MM-DD.md`.
3. Hermes or Josh-triggered review appends to `data\screening\screening_log.md`.
4. If a lead is worth pursuing, Hermes writes `data\proposals\YYYY-MM-DD-<lead-slug>.md`.
5. Josh reviews the draft.
6. If technical validation is needed, Hermes writes `data\codex_tasks\YYYY-MM-DD-<task-slug>\TASK.md`.
7. Codex performs the local technical work and writes `OUTPUTS\RESULT.md`.
8. Hermes reads the result, updates the proposal or project note, and summarizes the outcome to Josh on Telegram.
```

Create a Codex task packet only when the proposal or delivery needs technical work that Hermes should not perform directly. Examples:

- Verify an API, library, Apps Script capability, or integration limit.
- Inspect a client repo or sample file.
- Build a small proof of concept.
- Estimate technical effort based on actual files.
- Implement an approved project task.

Do not create a Codex task packet just to summarize a lead or write ordinary proposal copy.

## Do Not Build Yet

- Do not add a new `lead_finder` agent.
- Do not add a new queue/database around screening.
- Do not bypass Josh review for proposal submission.
- Do not create client messages from Codex output without Hermes/Josh review.
- Do not mark Hermes proxy or Claude bridge as available unless a real command has passed.

---

## Source: workflows\client_project.md

# Client Project Workflow

This workflow starts after Josh approves a proposal or asks AgentOS to prepare a delivery plan.

## Project Directory

```text
E:\AgentOS\data\projects\<project_id>\
  PROJECT_PLAN.md
  working\
  delivery\
  REVIEW_NOTES.md
```

## Flow

1. Hermes creates or updates `PROJECT_PLAN.md` from the approved scope.
2. Hermes creates Codex task packets for implementation work.
3. Codex edits files, runs verification, and writes each task result to `OUTPUTS\RESULT.md`.
4. Hermes summarizes progress to Josh and records review notes.
5. Josh approves any client-facing delivery message.

## Boundaries

- Do not start project execution from an unscreened lead.
- Do not let Codex send client messages directly.
- Do not create a project database until file-based project records are insufficient.

---

## Source: workflows\daily_lead_scout.md

# Daily Lead Scout

This file is a pointer to the canonical lead workflow in `E:\AgentOS\workflows\ai_freelancer_os.md`.

Hermes already owns real lead discovery through the `daily-upwork-lead-patrol` cron job. Do not create a second lead scout agent from this file.

## Required Output

Daily patrol writes:

```text
E:\AgentOS\data\leads\YYYY-MM-DD.md
```

The file should include qualified leads, rejected/no-match notes, search terms, and a recommended next action. Hermes then sends Josh a Telegram summary with the saved path.

## Next Step

Screening consumes that daily file and appends decisions to:

```text
E:\AgentOS\data\screening\screening_log.md
```

---

## Source: workflows\hermes_to_codex.md

# Hermes to Codex Workflow

This document defines how Hermes assigns work to Codex and collects results inside AgentOS.

## Purpose

Hermes is the AgentOS coordinator and Josh-facing brain. Codex is the execution specialist for code, scripts, repo inspection, tests, and structured file edits.

Hermes should delegate to Codex when a task needs one or more of these:

- Editing code, scripts, configs, or markdown artifacts
- Inspecting a repository or debugging a local failure
- Running tests, linters, or CLI verification
- Producing implementation-ready project files
- Creating repeatable automation scripts
- Validating technical feasibility before proposal wording

Hermes should not use Codex for final client commitments, pricing approval, or sending client-facing messages. Josh approves those.

## Directory Contract

Codex task packets live under:

```text
E:\AgentOS\data\codex_tasks\
```

Recommended structure:

```text
E:\AgentOS\data\codex_tasks\YYYY-MM-DD-<task-slug>\
  TASK.md
  INPUTS\
  OUTPUTS\
  STATUS.md
```

Project execution artifacts should live under:

```text
E:\AgentOS\data\projects\<project_id>\
  PROJECT_PLAN.md
  working\
  delivery\
  REVIEW_NOTES.md
```

## Task Packet Format

Hermes creates `TASK.md` with this format:

```markdown
# Codex Task: <short title>

Owner: Hermes
Reviewer: Josh
Created: YYYY-MM-DD HH:mm Asia/Taipei
Working directory: <absolute path>

## Objective
<one concrete outcome>

## Context
<client/project/lead context, relevant files, constraints>

## Inputs
- <path or data source>

## Required Output
- Write summary to `OUTPUTS/RESULT.md`
- Write changed files in-place or under `OUTPUTS/` as instructed
- Include test/verification results

## Acceptance Criteria
- <checkable criterion 1>
- <checkable criterion 2>

## Safety Rules
- Do not contact clients
- Do not expose credentials or tokens
- Do not overwrite unrelated files
- Ask Hermes/Josh if blocked by missing secrets or business decisions
```

## Dispatch Methods

Preferred, when Codex CLI is available locally:

```powershell
codex --cwd <working-directory> < E:\AgentOS\data\codex_tasks\YYYY-MM-DD-<task-slug>\TASK.md
```

Fallback, if Hermes proxy is working and Codex must use the local proxy:

```powershell
$env:OPENAI_BASE_URL = "http://localhost:8080/v1"
codex --cwd <working-directory> < E:\AgentOS\data\codex_tasks\YYYY-MM-DD-<task-slug>\TASK.md
```

If a non-interactive Codex command is unavailable, Hermes should create the task packet and notify Josh with the exact packet path and requested action.

## No Human Relay Rule

Josh should not be the routine message carrier between Hermes and Codex.

When Hermes has enough context and the work is within approved boundaries,
Hermes should dispatch Codex directly through the available bridge or CLI
method, then read `OUTPUTS\RESULT.md` and summarize only the decision-relevant
result to Josh.

Hermes should ask Josh only when one of these is true:

- the task requires approval for deletion, archive, install/update, credentials,
  governance changes, client-facing messages, or live external actions;
- the bridge/CLI path is blocked and the blocked artifact shows a concrete
  manual action is needed;
- the task intent is ambiguous enough that executing would be unsafe;
- Josh explicitly asks to review the prompt before dispatch.

Hermes should not ask Josh to copy a Codex prompt into Codex or paste Codex
output back into Hermes when an existing bridge can perform the handoff.

## Autonomous Dispatch Evidence

For each autonomous dispatch, Hermes should preserve:

```text
data\codex_tasks\YYYY-MM-DD-<task-slug>\
  TASK.md
  OUTPUTS\RESULT.md
  STATUS.md              optional
```

If Claude is involved:

```text
data\codex_tasks\YYYY-MM-DD-<task-slug>\
  CLAUDE_REVIEW_PROMPT.md
  OUTPUTS\CLAUDE_REVIEW.md
```

If a live bridge run is used:

```text
data\live_bridge\<bridge-id>\
  01_HERMES_DISPATCH.md
  02_CODEX_OUTPUT.md
  03_CLAUDE_REVIEW.md   when applicable
  04_HERMES_FINAL_SUMMARY.md
  TRANSCRIPT.md
```

## Result Collection

Codex writes:

```text
OUTPUTS\RESULT.md
```

with this shape:

```markdown
# Result

Status: success | partial | blocked | failed

## Summary
<what changed or what was learned>

## Files Changed
- <path>

## Verification
- <command>: pass/fail/not run

## Blockers
<any missing credentials, approvals, external systems>

## Next Action for Hermes/Josh
<clear next step>
```

Hermes then reads `OUTPUTS/RESULT.md`, condenses it for Josh, and records the next state in the relevant project or lead file.

For proposal validation tasks, Hermes should also update the proposal draft with one of:

- `Technical validation: passed`
- `Technical validation: partial`
- `Technical validation: blocked`
- `Technical validation: not needed`

Codex should include enough evidence in `RESULT.md` for Hermes to summarize confidently: commands run, files inspected, assumptions, and remaining risks. Hermes owns the business interpretation; Codex owns the technical finding.

## Failure Handling

- Codex may retry implementation failures up to 3 times when the issue is technical and local.
- After 3 failed attempts, Hermes summarizes the failure and asks Josh whether to continue, simplify scope, or switch model/tool.
- If failure is caused by credentials, quota, OAuth, or external service access, stop immediately and report the required action.

## Status Values

`STATUS.md` should use one of:

- `queued`
- `running`
- `needs_review`
- `blocked`
- `done`
- `cancelled`

Hermes owns status transitions. Codex may suggest status but should not silently mark business work as complete without Hermes/Josh review.

## Minimal Hermes Checklist

Before dispatch:

- Objective is concrete
- Working directory is explicit
- Inputs are attached or linked
- Acceptance criteria are checkable
- Secrets are not embedded

After return:

- Read result
- Verify changed files or command output if needed
- Summarize to Josh via Telegram
- Save final artifact in AgentOS data/workflows/docs as appropriate

## Current Boundary

This is a file-packet workflow, not a daemon contract. Until a real Hermes -> Codex -> Hermes cycle succeeds, do not build an automatic Codex runner, queue worker, or database-backed task system.

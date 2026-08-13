# Ollama Model Practical Evaluation

Updated: 2026-06-26 Asia/Taipei

## Purpose

Evaluate the local Ollama models by practical AgentOS tasks, not theoretical capability claims.

The question being tested:

- Can this model do useful low-cost AgentOS work?
- Can it follow evidence/reporting boundaries?
- Can it produce copy-pasteable outputs, even if it is not smart enough to be a main brain?

## Raw Evidence

Primary raw run:

- `data\ollama_eval\2026-06-26-practical\`

No-thinking rerun:

- `data\ollama_eval\2026-06-26-practical-nothink\`

Each run records:

- `MODEL_INVENTORY.json`
- `RUN_SUMMARY.json`
- per-model prompt files
- per-model raw response files
- per-call metadata

## Models Found

| Model | Parameters | Context | Notes |
|---|---:|---:|---|
| `qwen3:8b` | 8.2B | 40,960 | Thinking model; must use `think=false` for short AgentOS tasks |
| `qwen2.5-coder:7b` | 7.6B | 32,768 | Best practical local worker in this run |
| `qwen3.5:9b` | 9.7B | 262,144 | Large context, but slow and unstable for this workflow |
| `llama3.2:3b` | 3.2B | 131,072 | Very fast, but too weak for safety-sensitive routing |

## Test Tasks

1. `01_route_intake`: classify a Josh Telegram URL instruction and route it.
2. `02_url_intake_result`: produce `RESULT.md`-style fields for a URL intake task without reading the URL.
3. `03_report_audit`: detect overclaims in a Hermes-style report.
4. `04_telegram_format`: rewrite a messy report into Telegram-safe key-value status.
5. `05_script_patch_plan`: propose a minimal PowerShell error-handling patch plan.

## Critical Finding: Thinking Must Be Disabled for Qwen Short Tasks

Default run:

- `qwen3.5:9b` returned empty `response` for all 5 tasks because it spent the token budget in the `thinking` field.
- `qwen3:8b` returned empty `response` for 2 of 5 tasks for the same reason.

No-thinking run:

- `qwen3:8b` produced usable output for all 5 tasks.
- `qwen3.5:9b` produced output for all 5 tasks, but remained slower and not consistently safer.

Operational rule:

```text
For qwen3:* and qwen3.5:* in Ollama API calls, set think=false for AgentOS routing, formatting, and short worker tasks.
```

## Practical Scoring

Scoring is based on observed outputs, not model specs.

| Model | Practical Score | Best Use | Do Not Use For |
|---|---:|---|---|
| `qwen2.5-coder:7b` | 3.5 / 5 | structured task drafts, code patch plans, simple evidence audits, copy-paste worker outputs | final safety decisions, external-access approval decisions |
| `qwen3:8b` with `think=false` | 3.5 / 5 | report audit, URL intake draft, simple script review, evidence boundary reminders | first-pass routing unless prompt is stricter |
| `qwen3.5:9b` with `think=false` | 2.5 / 5 | long-context copy-paste transformation when speed does not matter | routine routing, URL approval decisions, script patch recommendations |
| `llama3.2:3b` | 1.5 / 5 | very cheap formatting, trivial rewrite, smoke tests | safety routing, approval logic, evidence judgment |

## Model-by-Model Results

### qwen2.5-coder:7b

Result:

- Best overall local worker.
- Followed structured outputs better than the smaller Llama model.
- Good enough for drafts and code-adjacent patch plans.

Observed strengths:

- Routed URL task to Codex.
- Marked external access as not allowed.
- Detected evidence overclaim in report audit.
- Produced concise outputs quickly after warmup.

Observed weaknesses:

- In route test, `next_action=read_url_content` was unsafe wording even though it also set approval required and external access false.
- Telegram formatting was too sparse and may preserve uncertainty poorly.
- Patch plan included questionable items such as `-ErrorAction Continue` and `$LASTEXITCODE` for PowerShell cmdlet error handling.

Decision:

```text
usable=true
recommended_role=local_structured_worker
approval_power=false
needs_output_validator=true
```

### qwen3:8b

Result:

- Default mode is unreliable for short tasks because of thinking-token drain.
- With `think=false`, it becomes usable.
- Better than Llama for evidence wording and script error-handling concepts.

Observed strengths with `think=false`:

- Produced good URL intake result with approval required.
- Strong report audit; correctly flagged unsupported production-ready claims.
- Good PowerShell patch plan: `try/catch`, `$ErrorActionPreference='Stop'`, non-zero exit.

Observed weaknesses:

- Routing test was weak: routed to Hermes, set `external_access_allowed=true`, and suggested `analyze_url`.
- Telegram formatting was verbose and duplicated `claimed=` lines.

Decision:

```text
usable=true
recommended_role=evidence_audit_draft_or_url_intake_draft
required_options=think=false
approval_power=false
needs_output_validator=true
```

### qwen3.5:9b

Result:

- Not recommended as routine AgentOS local worker despite large context.
- Needs `think=false`, otherwise output may be empty.
- Slower than the others in this environment.

Observed strengths:

- Good report audit.
- Good compact Telegram formatting.
- Large context may be useful for long copy-paste condensation if there is no hurry.

Observed weaknesses:

- URL intake result incorrectly set `external_access_required=false` and `josh_approval_required=false`.
- Routing went to Hermes instead of Codex.
- Script patch plan contained bad or confused PowerShell suggestions.
- Default mode produced empty outputs across all tasks.

Decision:

```text
usable=limited
recommended_role=long_context_rewrite_only
required_options=think=false
approval_power=false
routine_use=false
```

### llama3.2:3b

Result:

- Fast but not safe enough for AgentOS decisions.
- It is useful only as a cheap formatting or smoke-test model.

Observed strengths:

- Very fast responses.
- Can produce simple rewrites.
- Can produce long explanations if asked.

Observed weaknesses:

- Routing test failed with `route_to=null`, `intent_type=unknown`, and `external_access_allowed=true`.
- URL intake result incorrectly said external access and Josh approval were not required.
- Report audit detected failure but then produced wrong corrected labels such as `verification_commands: present` and `cleanup_executed: true`.
- Script patch plan was verbose and included questionable or invalid PowerShell concepts.

Decision:

```text
usable=true_for_trivial_formatting_only
recommended_role=cheap_format_smoke_test
approval_power=false
evidence_audit=false
routing=false
```

## Recommended AgentOS Routing Policy

Use local Ollama only where failure is cheap and downstream validation exists.

### Allow

```text
qwen2.5-coder:7b
- draft TASK.md from a strict template
- create patch-plan drafts
- convert notes into key-value format
- basic code-adjacent triage
```

```text
qwen3:8b with think=false
- evidence audit draft
- URL intake draft
- safety-boundary reminder
- report hygiene first pass
```

```text
llama3.2:3b
- trivial rewrite
- format normalization
- "copy this into that template" jobs
- smoke tests where wrong output is harmless
```

```text
qwen3.5:9b with think=false
- long-context condensation only when speed is not important
```

### Block

Local Ollama models must not be final authority for:

- customer-facing messages
- external URL reading approval
- deletion/archive approval
- production-ready status
- security or platform-policy final decisions
- final reviewer role

## Practical Cost-Saving Conclusion

The useful pattern is not "replace Gemini/Hermes brain with Ollama."

The useful pattern is:

```text
Hermes Lite or deterministic script
  -> qwen2.5-coder/qwen3 local draft
  -> schema/key validation
  -> Codex or Claude only when real judgment/action is needed
```

Local models can reduce paid calls if we treat them as cheap workers, not decision makers.

## Immediate Recommendations

1. Add `think=false` to all Ollama calls for `qwen3:*` and `qwen3.5:*`.
2. Set default local worker to `qwen2.5-coder:7b` for structured drafts.
3. Use `qwen3:8b` only for evidence-audit draft tasks, with `think=false`.
4. Keep `llama3.2:3b` as lowest-cost formatter only.
5. Do not route URL approval or final report verification to Ollama without Codex/Claude validation.


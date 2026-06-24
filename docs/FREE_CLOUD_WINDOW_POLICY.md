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

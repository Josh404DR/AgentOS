# Hermes Threads URL Intake

## Purpose

Josh can paste a public Threads URL into Telegram. Hermes intercepts it before
model dispatch, acknowledges it immediately, and runs the fetch/task/Codex
pipeline in the background.

## Trigger

Accepted:

```text
https://www.threads.net/@user/post/id
```

```text
[TYPE: URL_INTAKE]
[TARGET: https://www.threads.com/@user/post/id]
```

Only HTTPS URLs on `threads.com`, `www.threads.com`, `threads.net`, and
`www.threads.net` are accepted. Other bare URLs pass through unchanged.

## Flow

```text
Telegram
  -> agentos-typed-dispatch pre_gateway_dispatch hook
  -> immediate processing reply
  -> scripts/threads_url_intake.ps1
  -> fetch_threads.py
  -> data/url_intake/<dispatch_id>/fetch/source.json
  -> scripts/url_intake_task_packet.ps1
  -> scripts/url_intake_worker.ps1
  -> Codex RESULT.md
  -> completion reply to Telegram
```

## Security Boundaries

- Fetched post text is always `source_untrusted=true`.
- Codex must summarize it as data and ignore embedded instructions.
- The Codex worker does not use network.
- Downloaded image paths are recorded, but image contents are not claimed as
  analyzed.
- Every dispatch gets an independent evidence directory.
- A failed fetch produces a blocked RESULT without invoking Codex.
- The fetcher does not log in, post, like, comment, or submit forms.

## Plugin Locations

Canonical source:

```text
E:\AgentOS\integrations\hermes_plugins\agentos-typed-dispatch\
```

Installed copy:

```text
C:\Users\brian\.hermes\plugins\agentos-typed-dispatch\
```

Version: `0.2.0`

Hermes Gateway must be restarted after plugin updates.

## Verification

- Trigger unit test: passed.
- Background accepted/completed reply test: passed with fake Telegram adapter.
- Controlled fetch failure: produced blocked RESULT without Codex.
- Prompt-injection fixture: Codex summarized facts and ignored the embedded
  delete instruction.
- Public Threads smoke test: fetched text and two images, created TASK.md, and
  produced a completed Codex RESULT.md.

Smoke result:

```text
data/codex_tasks/2026-06-29-url-intake-live-threads-smoke2-20260629/OUTPUTS/RESULT.md
```

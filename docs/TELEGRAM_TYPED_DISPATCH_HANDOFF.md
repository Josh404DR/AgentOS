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
C:\Users\brian\AppData\Local\hermes\plugins\agentos-typed-dispatch\
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

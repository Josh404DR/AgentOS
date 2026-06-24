# Telegram Typed Dispatch Handoff Plan

Updated: 2026-06-24 23:55 Asia/Taipei
Editor: Codex

## Purpose

This document defines the clean handoff point between Hermes Telegram intake
and AgentOS typed dispatch.

The local typed-dispatch layer is ready. The actual Hermes gateway hook is not
yet changed.

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

## Josh Approval Gate

Stop and ask Josh before any of the following:

- modifying the Hermes external runtime under
  `E:\AI_Projects_Hub\External_AI_Agents\hermes-agent`;
- changing Hermes gateway hooks;
- restarting the Telegram gateway;
- changing Hermes model/provider configuration;
- testing live Telegram messages through the gateway.

## Proposed Live Integration Step

When Josh approves, inspect Hermes hook support and connect Telegram intake to:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File E:\AgentOS\scripts\telegram_typed_dispatch_entry.ps1 -MessageText "<telegram_message_text>"
```

If the Hermes hook API cannot pass raw message text, create a small adapter
inside AgentOS first and test it locally before touching the runtime.

## Non-Goals

- No new daemon.
- No new database.
- No semantic cache.
- No Gemini use for routine dispatch.
- No live Telegram test without Josh approval.

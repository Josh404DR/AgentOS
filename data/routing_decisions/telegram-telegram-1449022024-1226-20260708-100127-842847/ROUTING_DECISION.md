# AgentOS Typed Dispatch Decision

dispatch_id: telegram-telegram-1449022024-1226-20260708-100127-842847
created_at: 2026-07-08 10:01:32 +08:00

type: JOSH_APPROVAL
route_to: Hermes
template: 
role_header: 
context_pack: approval_target_only
gemini_allowed: False
requires_josh_approval: False
dispatch_status: ready_to_route
governance_version: 1.2.0
governance_hash: AD20E91AFB53EF06800077F420F8F441E57EEEA0E906794FF219E63F0FFE39C3
cleanup_executed: false
live_external_action_executed: false
models_invoked: false

## Parsed Fields

goal: 
target: 
scope: 
files: 
constraints: 
output: 
approval: 

## Notes

- This runner performs deterministic routing only.
- It does not call Gemini, Codex, Claude, Ollama, or external services.
- Unknown types are context-only until Josh clarifies.
- Gemini premium routing requires explicit type and approval handling.

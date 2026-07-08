# AgentOS Typed Dispatch Decision

dispatch_id: test-gemini-premium-block
created_at: 2026-06-24 20:05:16 +08:00

type: GEMINI_PREMIUM
route_to: Gemini
template: 
role_header: 
context_pack: minimal_targeted
gemini_allowed: True
requires_josh_approval: True
dispatch_status: approval_required
cleanup_executed: false
live_external_action_executed: false
models_invoked: false

## Parsed Fields

goal: Premium synthesis test
target: cost protocol
scope: 
files: 
constraints: no external calls
output: none
approval: 

## Notes

- This runner performs deterministic routing only.
- It does not call Gemini, Codex, Claude, Ollama, or external services.
- Unknown types are context-only until Josh clarifies.
- Gemini premium routing requires explicit type and approval handling.

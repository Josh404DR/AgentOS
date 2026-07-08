# AgentOS Typed Dispatch Decision

dispatch_id: telegram-telegram-local-test-chat-local-test-msg-20260624-233441
created_at: 2026-06-24 23:34:42 +08:00

type: CODEX_VERIFY
route_to: Codex
template: prompts\task_templates\codex_verify.md
role_header: prompts\role_headers\codex_verifier.md
context_pack: evidence_verification
gemini_allowed: False
requires_josh_approval: False
dispatch_status: ready_to_route
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

# AgentOS Typed Dispatch Decision

dispatch_id: ci-live-generic-resilient-20260719-225229
created_at: 2026-07-19 22:52:32 +08:00

type: URL_INTAKE
route_to: Codex
template: prompts\task_templates\codex_verify.md
role_header: prompts\role_headers\codex_verifier.md
context_pack: minimal
gemini_allowed: False
requires_josh_approval: False
dispatch_status: ready_to_route
governance_version: 1.3.0
governance_hash: 0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1
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

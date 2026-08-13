# Phase 0 Builder Test Result

dispatch_id: knowledge-workspace-phase0-security-20260720
builder_role: Codex Builder
tested_at: 2026-07-20T15:22:34.7576785+08:00
governance_version: 1.3.0
governance_hash: 0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1
external_services_invoked: false
models_invoked: false
self_verification_claimed: false

## PASS evidence

- `dashboard\backend\.venv\Scripts\python.exe -m unittest tests\test_dashboard_security.py`
  - `Ran 8 tests`
  - `OK`
  - covers public read-only APIs, wrong token, unauthenticated write, expired
    session, non-owner session, Origin, CSRF, feature flag default-off, actor
    audit, artifact hash/state fields, strict UTF-8 and mojibake scan.
- `tests\test_url_knowledge_security.ps1`
  - `url_knowledge_security_tests=PASS`
  - path cases: valid, `..`, absolute outside, junction/symlink escape.
  - review cases: strict PASS, PASS_WITH_CAVEATS, incomplete schema.
  - verify cases: fresh PASS, non-fresh mode, FAIL.
- `tests\test_utf8_encoding_boundary.py`
  - `encoding_boundary_test_status=passed`
  - `case_count=6`
- Python compile and PowerShell AST parse: `syntax_checks=PASS`.
- `npm.cmd run lint`: PASS.
- `npm.cmd run build`: PASS; Next.js production build and TypeScript completed.

## Live machine evidence

- Final listeners:
  - `127.0.0.1:3000`
  - `127.0.0.1:8000`
  - no `0.0.0.0:3000/8000` listener.
- Read-only API status: health/tasks/workflows/decisions all HTTP 200.
- Wrong token: 403.
- Unauthenticated write: 403.
- Valid owner login: 200.
- Returned actor: `laptop-impr60b8\brian`.
- Authentication method: `local_owner_token`.
- Missing CSRF: 403.
- Cross Origin: 403.
- Authenticated domain mutation with default feature flag off: 403.
- ACL output contains exactly:
  `E:\AgentOS\data\dashboard_auth\owner-token.txt LAPTOP-IMPR60B8\brian:(F)`.
- `CodexSandboxOffline` token read: denied.
- Runtime log: `logs\dashboard-backend.stderr.log` shows Uvicorn bound to
  `http://127.0.0.1:8000` and application startup complete.

## Full smoke result

Artifact: `data\ci_health\ci-smoke-20260720-150814.md`

- Overall: `FAIL` (not concealed).
- New `dashboard_security`: PASS.
- New `url_knowledge_security`: PASS.
- All other task-related encoding, syntax, URL knowledge and compile checks: PASS.
- Sole FAIL: pre-existing `dispatch_resilience` timeout fixture took 21 seconds
  against a 20-second test threshold. One isolated bounded retry repeated 21
  seconds. No Phase 0 file is on that fixture's execution path.
- WARN: Hermes runtimes/scheduled tasks unavailable in the test context, and
  model CLI smoke intentionally skipped to keep task data local.

This is Builder evidence only. Final acceptance requires a different fresh
read-only Codex Verify session.

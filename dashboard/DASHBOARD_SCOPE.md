# Dashboard Scope & Integration Strategy

**Decision date**: 2026-06-29  
**Updated**: 2026-07-26（three-plane naming alignment）

## Current Phase: Public Read Plane + Owner-Authenticated Control Plane + Isolated Knowledge Append Plane

The web dashboard is a sandbox. Telegram remains the primary production interface.

### What dashboard does now

#### Public Read Plane (`public-read`; 公開唯讀區)

- Token usage, work trail, Codex task status, live logs, Today, workflow,
  approval, decision and task views.
- Rebuildable SQLite/FTS5 trigram Knowledge search, node detail, discussion
  projection and opaque artifact viewer under `/api/v1`.
- Hermes Lite chat belongs here because it is an isolated conversational view:
  Groq is called directly and the feature does not write to `state.db` or any
  Dashboard domain artifact.

#### Owner-Authenticated Control Plane (`owner-control`; 擁有者驗證控制區)

- Owner session status, login and logout.
- Workflow control, approval decisions and ADR create/status/link/layout
  operations. Domain mutations are default-off and retain all existing security
  checks described below.

#### Isolated Knowledge Append Plane (`knowledge-append`; 隔離知識附加區)

- Owner-authenticated discussion, feedback, message and candidate append
  operations.
- Appended events remain isolated from canonical task, ADR, governance and
  Knowledge Pool files.

### What dashboard does NOT do (yet)
- Open work orders / trigger URL intake
- Write to state.db
- Modify Hermes state
- Sync with Telegram session

### Plane-specific mutation endpoints in main.py (as of 2026-07-26)

#### Owner-Authenticated Control Plane (`owner-control`)

- `POST /api/auth/login` and `POST /api/auth/logout` manage the owner session.
- `POST /api/workflows/{id}/control` executes a control action via PowerShell.
- `POST /api/approvals/{id}/decision` records an approval decision and may
  trigger downstream scripts.
- ADR create/status/link/layout endpoints mutate decision artifacts.

All domain mutation endpoints in this plane are **default off** behind
`AGENTOS_DASHBOARD_MUTATIONS_ENABLED`. Enabling them does not bypass security:
every domain mutation still requires a loopback request, an allowed local
Origin, an authenticated owner session and a matching CSRF token. Login is the
session bootstrap operation; status is a public read and logout follows its
existing middleware exception. Plane naming does not alter those behaviors.

At backend startup, a short-lived owner token is rotated into
`data\dashboard_auth\owner-token.txt`. Its NTFS ACL is restricted to the Windows
identity running the service. A successful token login returns a short-lived
HttpOnly session and rotates the owner token again. Audit events are appended to
`data\dashboard_auth\AUDIT_LOG.jsonl` with the authenticated Windows actor,
authentication method, request id, affected artifact and before/after hashes.

#### Isolated Knowledge Append Plane (`knowledge-append`)

- `POST /api/v1/knowledge/{node_id}/feedback`
- `POST /api/v1/knowledge/{node_id}/discussions`
- `POST /api/v1/knowledge/{node_id}/discussions/{discussion_id}/messages`
- `POST /api/v1/knowledge/{node_id}/candidate`

These endpoints are the narrow exception to the domain mutation feature flag.
They still require loopback, Origin allowlist, owner session and CSRF, but can
only append schema-validated events below `data\knowledge_discussions\`.
Candidate export is restricted to `data\knowledge_candidates\` and explicitly
cannot dispatch or publish.

The backend and frontend bind to `127.0.0.1`. Public Read Plane task, workflow,
decision, Today and Knowledge views remain available without a session. Browser
refreshes query the derived index and do not walk the full task filesystem.

### Why
Telegram's current state is stable and clean. Integration work will inevitably
touch Telegram's logic. The dashboard is the place to build and test that
integration safely before connecting it back.

## Future Phase: Unified Integration

When the integration is ready:
- Both Telegram and web share the same state (single source of truth)
- Writing from web will be safe because the conflict logic is already tested here

The transition happens only after the dashboard-side integration is stable.
Never modify Telegram's logic from the dashboard side during the current phase.

Knowledge promotion, publication, NotebookLM writes, resolution lifecycle and
knowledge graph features remain unavailable; they require later-phase approval.

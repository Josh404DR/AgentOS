# Dashboard Scope & Integration Strategy

**Decision date**: 2026-06-29

## Current Phase: Read-Only + Isolated Chat

The web dashboard is a sandbox. Telegram remains the primary production interface.

### What dashboard does now
- READ: token usage, work trail, Codex task status, live logs
- CHAT: Hermes Lite (Groq direct, isolated — does not write to state.db)

### What dashboard does NOT do (yet)
- Open work orders / trigger URL intake
- Write to state.db
- Modify Hermes state
- Sync with Telegram session

### Actual write endpoints in main.py (as of 2026-07-08)

The following POST endpoints exist in `backend/main.py` and **do** trigger writes or execute PowerShell scripts. This contradicts the "read-only" description above and is documented here for accuracy:

- `POST /api/workflows/{id}/control` — executes a control action on a workflow via PowerShell
- `POST /api/approvals/{id}/decision` — records an approval decision and may trigger downstream scripts

These endpoints are live but unsecured (no auth). Agents must treat the dashboard as having a write surface, not a read-only surface. Do not assume dashboard actions are safe no-ops.

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

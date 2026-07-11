# AgentOS 24H Stability Monitor Plan

Updated: 2026-06-22
Goal: Verify AgentOS infrastructure stability before executing real client work.

## Monitor Schedule
- **Duration**: 24 hours.
- **Interval**: Manual or automated checkpoint every 2 hours.

## Checkpoint Checklist

| Component | Check | Expected Result |
| :--- | :--- | :--- |
| **Hermes Gateway** | `hermes health` | Status: OK, Telegram: Connected |
| **Telegram Path** | Send test message to Home | Message received |
| **Codex Bridge** | `.\scripts\hermes_codex_bridge.ps1` | Transcript Status: Success |
| **Claude CLI** | `claude auth status` | loggedIn: true |
| **Gemini Fallback** | `gemini --version` | Command returns version |
| **Git State** | `git status --short` | Clean or documented dirty role files |
| **Antivirus** | Check Avira Logs | No new AgentOS/Hermes detections |
| **Processes** | `ps | grep hermes` | No runaway or orphan processes |

## Status Labels
- `ok`: All checks passed.
- `degraded`: One or more non-blocking checks failed (e.g., Claude 529).
- `blocked_provider_overload`: Claude or Gemini unavailable due to quota/errors.
- `needs_josh_review`: Unexpected error, security event, or data corruption.

## Reporting
Final report path: `data/monitoring/24h/YYYY-MM-DD/REPORT.md`

Each checkpoint should record:
1. Timestamp
2. Status Label
3. Checkpoint findings
4. Any corrective actions taken

## Safety Rules
1. **Do not contact clients** during the 24h stability test.
2. **Do not run installers or updates** (irm | iex) during the test.
3. If an antivirus event occurs, **Stop and notify Josh immediately**.

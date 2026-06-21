# TASK 7 - HERMES 24H OPERATION MONITOR PLAN

## Current Status
- **Gateway**: Running (PID: 9968).
- **Scheduled Jobs**: 3 Active.
  - `daily-agentos-health-check`: 2026-06-22 07:55
  - `daily-upwork-lead-patrol`: 2026-06-22 08:00
  - `Daily-Token-Cost-Summary`: 2026-06-23 00:00
- **Watchdog State**: Manual Gateway mode; no automatic Windows service.
- **Model Fallback**: Gemini-3-Flash is primary; Ollama qwen3:8b is available as local fallback.

## 24h Observation Checklist
- [ ] **Gateway Stability**: Verify PID 9968 (or its child) remains alive for 24 hours.
- [ ] **Telegram Handoff**: Confirm `Daily-Token-Cost-Summary` successfully delivers to the home channel.
- [ ] **Cron Execution**: Verify `daily-agentos-health-check` runs and writes its daily health artifact.
- [ ] **Lead Patrol**: Confirm `daily-upwork-lead-patrol` executes and outputs results to `data/leads/`.

## Operational Boundaries
- **Status**: 24h observation started.
- **Success Criteria**: 24 hours of uninterrupted gateway and cron operation with evidence in `progress_log.md`.
- **Note**: No Windows service installed. Stability depends on the current persistent session.

## Acceptance Criteria Check
- **Gateway/Cron status recorded**: YES
- **Checklist created**: YES
- **ASCII Safety**: Verified.

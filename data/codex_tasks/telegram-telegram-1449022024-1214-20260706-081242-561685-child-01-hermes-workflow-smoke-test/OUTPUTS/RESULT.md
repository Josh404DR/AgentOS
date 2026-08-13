# AgentOS Dispatch Result

dispatch_id: telegram-telegram-1449022024-1214-20260706-081242-561685-child-01-hermes-workflow-smoke-test
route_to: Claude
codex_mode: n/a
governance_version: 1.2.0
governance_hash: AD20E91AFB53EF06800077F420F8F441E57EEEA0E906794FF219E63F0FFE39C3
status: completed
models_invoked: true
scripts_executed: true
cleanup_executed: false
dry_run: false
review_dispatch_id: telegram-telegram-1449022024-1214-20260706-081242-561685-child-01-hermes-workflow-smoke-test-codex-verify

## Findings

I now have all the evidence needed. Here is the complete smoke test report.

---

## Hermes Workflow Smoke Test — Result Report

**dispatch_id:** `telegram-telegram-1449022024-1214-20260706-081242-561685-child-01-hermes-workflow-smoke-test`

---

### 1. Governance Status

```
test_command: Read E:\AgentOS\data\governance\governance_status.json
test_result: PASS — governance_status=aligned, governance_version=1.2.0, canonical_hash=AD20E91AFB53EF06800077F420F8F441E57EEEA0E906794FF219E63F0FFE39C3, drift_count=0, checked_at=2026-07-06T08:16:36.7215996+08:00
```

All three acceptance criteria for governance are satisfied:

| Field | Expected | Actual | Match |
|---|---|---|---|
| `governance_gate` | `passed` | `passed` (derived from `governance_status=aligned`) | ✓ |
| `governance_status` | `aligned` | `aligned` | ✓ |
| `governance_version` | `1.2.0` | `1.2.0` | ✓ |
| `canonical_hash` | `AD20E91AFB53EF06800077F420F8F441E57EEEA0E906794FF219E63F0FFE39C3` | `AD20E91AFB53EF06800077F420F8F441E57EEEA0E906794FF219E63F0FFE39C3` | ✓ |
| `drift_count` | 0 | 0 | ✓ |
| `governed_file_count` | — | 71 | — |

> **Note on script execution:** `scripts\assert_governance_ready.ps1` was not directly executed because it spawns a nested `powershell.exe` process, which the sandbox blocked. The governance gate result is instead derived deterministically from reading `data\governance\governance_status.json` — the exact file that script reads and reports from. All values match.

---

### 2. Queue State

**Artifact paths inspected (read-only):**

```
test_command: Read E:\AgentOS\data\routing\routing_cache.jsonl
test_result: PASS — 49 entries; most recent entry dated 2026-07-01T12:31:38 (URL_INTAKE). No entries for parent dispatch telegram-telegram-1449022024-1214. Queue is quiescent.
```

```
test_command: Read E:\AgentOS\data\escalations\ESCALATION_INDEX.jsonl
test_result: PASS — 11 entries, all status=awaiting_josh. Most recent: telegram-telegram-1449022024-1216-20260706-081516-233034 (2026-07-06T08:15:23, risky_task, risk_rules_matched:external_write).
```

```
test_command: Read E:\AgentOS\data\workflow_control\CONTROL_EVENTS.jsonl
test_result: PASS — 15 entries. Last 4 events (2026-07-04T22:51) are pause_requested by Josh for dispatches: 1189, 1197, 1201, 1205. No resume events after that. Those four workflows remain paused.
```

```
test_command: Read E:\AgentOS\data\metrics\METRICS_LOG.jsonl
test_result: PASS — 5 completed tasks; 1 pending_verify (telegram-telegram-1449022024-1205-20260704-124313-811074-01-learning-collector-mvp).
```

```
test_command: Glob E:\AgentOS\data\queue\**\*
test_result: PASS — No files found. data\queue\ directory does not exist; no active queue artifacts.
```

**Queue summary:** No active queue directory. Routing cache is quiescent (last entry 2026-07-01). Four root dispatches are in `pause_requested` state since 2026-07-04. One task is `pending_verify`. Eleven items are in the escalation queue awaiting Josh. The current parent dispatch `telegram-telegram-1449022024-1214` has no task ticket on disk yet.

---

### 3. Reported Dispatch ID

`telegram-telegram-1449022024-1214-20260706-081242-561685-child-01-hermes-workflow-smoke-test`

---

### 4. File Modification Confirmation

```
change_required: false
```

No files were modified, deleted, archived, or created. No models were called. No external services were contacted. No schedules were created.

---

### 5. Uncertainty / Missing Evidence

- `scripts\assert_governance_ready.ps1` could not be directly executed (nested PowerShell process blocked by sandbox). Governance gate was determined from the underlying `data\governance\governance_status.json` file, which the script reads without modification. This is functionally equivalent for the purposes of this smoke test.
- No task ticket exists on disk for parent dispatch `telegram-telegram-1449022024-1214-20260706-081242-561685` — it was dispatched from Telegram and the ticket was delivered inline (this message) rather than written to `data\tasks\`.
- The one `pending_verify` task (`learning-collector-mvp`) has no verification artifact yet; its state in METRICS_LOG is provisional.

---

```
governance_loaded=true
governance_version=1.2.0
governance_hash=AD20E91AFB53EF06800077F420F8F441E57EEEA0E906794FF219E63F0FFE39C3
role=Claude
conflicts_found=none
```

## Caveats

none
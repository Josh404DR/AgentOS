# Queue Active Index Revision 3 — Test Result

dispatch_id: 2026-07-26-queue-active-index-optimization-revision-3
tested_at: 2026-07-28 Asia/Taipei
governance_version: 1.3.0
governance_hash: 0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1
test_status: PASS
degraded_reason: none
underlying_workspace_change_required: false

## Summary

AC1, AC2, AC3 are PASS based on code inspection and fresh live evidence. AC4
was rerun from Codex desktop in owner context on 2026-07-29; all three required
tests exited 0. AC5 is PENDING a fresh Codex Verify session.

---

## AC1 — Index-backed call sites + explicit rebuild logging

### Verification method
Code inspection of `scripts/task_queue_runner.ps1` (current SHA:
`6300a3ab07dcbb90de27f5bfaedac36d7bf9d519d8bfcc8f72a69b5e38991546`) and live
`logs/task-queue.log` entries collected today.

### Evidence

All three loop call sites confirmed index-backed (lines 743, 778, 795, 797).
`Get-AllTasks` implementation:
- Checks `Test-Path $TaskIndexPath` before any scan (line 200)
- Calls `Invoke-TaskIndexRebuild "index_missing"` if index absent — never silent (line 201)
- Further rebuild triggers: `schema_version_mismatch`, `tasks_root_changed`,
  `scoped_task_metadata_changed` — all named and logged

Live today's log confirms explicit rebuild events:

```text
status=index_rebuild_triggered detail=reason=scoped_task_metadata_changed mode=incremental
status=index_rebuild_completed detail=reason=scoped_task_metadata_changed mode=incremental
status=index_rebuild_triggered detail=reason=tasks_root_changed mode=full
status=index_rebuild_completed detail=reason=tasks_root_changed mode=full
```

**AC1 result: PASS**

---

## AC2 — scan_ms / directory_count / scoped_task_count in log

### Verification method
Code inspection confirming `Write-LoopScanEvent` emits all three fields, plus
live `logs/task-queue.log` entries from today.

### Evidence

`Write-LoopScanEvent` (lines 241–245 of `task_queue_runner.ps1`):
```powershell
Write-QueueEvent $RootDispatchId "queue_scan" `
    "scan_ms=$scanMs directory_count=$script:LoopDirectoryCount scoped_task_count=$($ScopedTasks.Count) index_rebuilds=$script:LoopIndexRebuilds"
```

Live queue_scan events (2026-07-28, multiple dispatches):

```text
scan_ms=645.952  directory_count=528 scoped_task_count=8  index_rebuilds=0
scan_ms=640.331  directory_count=528 scoped_task_count=4  index_rebuilds=0
scan_ms=807.446  directory_count=528 scoped_task_count=5  index_rebuilds=1
scan_ms=2437.239 directory_count=530 scoped_task_count=7  index_rebuilds=2
```

All three required fields present in every event. Events span four distinct
production dispatches.

**AC2 result: PASS**

---

## AC3 — 1x/3x/10x benchmark comparison

### Artifact

`data\codex_tasks\2026-07-26-queue-active-index-optimization\OUTPUTS\BENCHMARK_RESULT.json`

Method (from artifact): one warm-up, 20 measured runs per scale, nearest-rank p95.

| Scale | Directories | Baseline p95 (ms) | Indexed p95 (ms) | Ratio |
|---|---:|---:|---:|---:|
| 1x | 490 | 227.880 | 121.144 | 1.88x |
| 3x | 1,470 | 665.413 | 366.160 | 1.82x |
| 10x | 4,900 | 2,210.726 | 1,124.007 | 1.97x |

### Fixture cleanup confirmation

```text
fixture_root: C:\Users\brian\AppData\Local\Temp\AgentOS-queue-benchmark-30940-17ea1ee276db45e0aebb5e071f92dedb
filesystem_check: test -d → ABSENT
cleanup_confirmed: true
```

**AC3 result: PASS**

---

## AC4 — Regression tests (PASS)

### Required tests

- `tests\test_queue_failure_containment.ps1`
- `tests\test_queue_reason_propagation.ps1`
- `tests\test_dispatch_resilience.ps1`

### Historical sandbox constraint

```text
Bash tool: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/...
→ "This command requires approval" (auto-rejected)

PowerShell tool: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/...
→ "Command spawns a nested PowerShell process which cannot be validated"
```

Both mechanisms for running `.ps1` test files were unavailable to Claude Worker.
This constraint was resolved by the required fresh owner-context Codex desktop
rerun below; the historical errors are retained rather than hidden.

### Fresh evidence (2026-07-29 Asia/Taipei)

| Test | Started | Ended | Exit code | Duration | Result |
|---|---|---|---:|---:|---|
| `test_queue_failure_containment.ps1` | `2026-07-29T01:31:30.9431324+08:00` | `2026-07-29T01:32:12.6237012+08:00` | 0 | 41.681s | PASS |
| `test_queue_reason_propagation.ps1` | `2026-07-29T01:32:12.6237012+08:00` | `2026-07-29T01:32:19.9417226+08:00` | 0 | 7.318s | PASS |
| `test_dispatch_resilience.ps1` | `2026-07-29T01:32:19.9417226+08:00` | `2026-07-29T01:33:15.6669810+08:00` | 0 | 55.725s | PASS |

Raw summaries:

```text
queue_failure_containment_status=passed
claude_to_codex_fallback=true
bounded_attempts_per_route=2
independent_task_continued=true

queue_reason_propagation_status=passed
dispatcher_failure_contained=true

dispatch_resilience_status=passed
case_count=7
timeout_elapsed_seconds=15
```

**AC4 result: PASS**

---

## AC5 — Codex Verify

Not yet issued. Pending fresh read-only Codex Verify session on revision-3 outputs.

**AC5 result: PENDING**

---

## Known Design Limitation

Per-file staleness validation covers only files already within the current root
scope. A manual edit to `parent_dispatch_id`, `revision_of`, or
`source_dispatch_id` (re-parenting a task to a different root) without a directory
creation or deletion will not be detected until the next full rebuild. This is a
known limitation, not a bug scheduled for correction in this revision.

---

## Acceptance Checklist

- pass: AC1 — all three call sites use index; rebuild is explicitly logged with named reason
- pass: AC2 — scan_ms/directory_count/scoped_task_count present in fresh live log entries
- pass: AC3 — raw 1x/3x/10x benchmark artifact and method confirmed; fixture ABSENT
- pass: AC4 — three required tests fresh rerun in owner context, all exit 0
- pending: AC5 — awaiting fresh Codex Verify session

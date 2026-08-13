# Queue Active Index Revision Round 2 測試結果

dispatch_id: 2026-07-26-queue-active-index-optimization-revision-2
tested_at: 2026-07-28 Asia/Taipei
governance_version: 1.3.0
governance_hash: 0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1
test_status: locally_verified
underlying_workspace_change_required: false

## Governance readiness

```text
governance_gate=passed
governance_status=operational_review_required
task_execution_allowed=true
operational_drift_count=26
```

## Fresh test execution

Command pattern:

```text
powershell.exe -NoProfile -ExecutionPolicy Bypass -File <test-path>
```

Results:

| Test | Final exit code | Result |
|---|---:|---|
| `tests\test_queue_active_index.ps1` | 0 | PASS |
| `tests\test_queue_failure_containment.ps1` | 0 | PASS |
| `tests\test_queue_reason_propagation.ps1` | 0 | PASS |
| `tests\test_dispatch_resilience.ps1` | 0 | PASS after approved out-of-sandbox rerun |

Observed output:

```text
queue_active_index_status=passed
missing_index_rebuild_logged=true
scan_metrics_logged=true
fixture_cleanup_confirmed=True

queue_failure_containment_status=passed
claude_to_codex_fallback=true
bounded_attempts_per_route=2
independent_task_continued=true

queue_reason_propagation_status=passed
dispatcher_failure_contained=true

dispatch_resilience_status=passed
case_count=6
timeout_elapsed_seconds=6
```

The combined command reached its 120-second aggregate timeout only after the
first three tests had each completed with exit code 0 and the fourth test had
started. The fourth test was therefore rerun separately.

The first separate run of `test_dispatch_resilience.ps1` exited 1 with:

```text
Test-Path : Access is denied
```

This was a sandbox child-process permission failure. Per escalation policy, the
same test was rerun outside the sandbox after approval and completed with exit
code 0. Both attempts are disclosed; the first failure was not treated as a
product PASS.

## AC1 and AC2 evidence

Fresh `test_queue_active_index.ps1` evidence:

```text
missing_index_rebuild_logged=true
scan_metrics_logged=true
```

Actual queue log example:

```text
2026-07-28T03:06:04.9338497+08:00 dispatch_id=ci-queue-reason-root-27324-030555534 status=queue_scan detail=scan_ms=3052.41 directory_count=520 scoped_task_count=2 index_rebuilds=1
```

## AC3 benchmark evidence

Raw artifact:

`data\codex_tasks\2026-07-26-queue-active-index-optimization\OUTPUTS\BENCHMARK_RESULT.json`

SHA-256:

`1D3E4F9810B1E8A18F9EB41AF9732AE326590C125A8A1AEEF240487899F47516`

Method recorded in the artifact: one warm-up, 20 measured runs per scale,
nearest-rank p95.

| Scale | Directories | Baseline p95 (ms) | Indexed p95 (ms) | Ratio |
|---|---:|---:|---:|---:|
| 1x | 490 | 227.880 | 121.144 | 1.88x |
| 3x | 1,470 | 665.413 | 366.160 | 1.82x |
| 10x | 4,900 | 2,210.726 | 1,124.007 | 1.97x |

## Fixture cleanup evidence

The artifact records:

```text
fixture_root=C:\Users\brian\AppData\Local\Temp\AgentOS-queue-benchmark-30940-17ea1ee276db45e0aebb5e071f92dedb
```

Read-only residual scan:

```text
temp_fixture_residual_count=0
```

No deletion was performed in this revision.

The prescribed Queue regression tests retained uniquely named CI task and
queue-run evidence. Those exact paths are reported in `RESULT.md`; they were
not deleted because deletion requires explicit approval.

## Exact source bindings

```text
scripts\task_queue_runner.ps1
sha256=F420C4C537F84A41EA67C34E736433E65AEF44A7A597700BFCDB6D4D962648F2

scripts\rebuild_active_task_index.ps1
sha256=94EBBCF6FE0D2007D264FDD76F3058F8F041507A849F5FF9463017AC1AFF651A

tests\test_queue_active_index.ps1
sha256=B1C52424D8CCB4D58D581C4B6D737EEFC36B919961B023DFB40BDAF3CE8BD826

tests\benchmark_queue_active_index.ps1
sha256=95E0AC4579DEB9DF4B099B3F78F86E5B89A323794C2BB6DA80B875EFAE225355
```

## Known limitation

Per-file staleness validation covers files already in the current root scope.
A manual cross-root edit to `parent_dispatch_id`, `revision_of`, or
`source_dispatch_id` without directory creation/deletion is discovered only on
a later full rebuild. This is documented, not corrected in this revision.

## Acceptance checklist

- pass: AC1 missing-index rebuild is explicitly logged.
- pass: AC2 scan metrics are present in an actual queue event.
- pass: AC3 raw 1x/3x/10x benchmark artifact and method are readable.
- pass: AC4 all three required regression tests have fresh exit-code-0 runs.
- fail: AC5 remains pending a different fresh read-only Codex Verify session.

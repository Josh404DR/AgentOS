# Queue Active Index Revision 1 證據核對

dispatch_id: 2026-07-26-queue-active-index-optimization-revision-1
tested_at: 2026-07-28 Asia/Taipei
governance_version: 1.3.0
governance_hash: 0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1
test_status: PASS
scope: revision_evidence_only

## Governance readiness

```text
governance_gate=passed
governance_status=operational_review_required
task_execution_allowed=true
operational_drift_count=26
```

## AC3 benchmark artifact validation

Artifact:

`data\codex_tasks\2026-07-26-queue-active-index-optimization\OUTPUTS\BENCHMARK_RESULT.json`

SHA-256:

`1D3E4F9810B1E8A18F9EB41AF9732AE326590C125A8A1AEEF240487899F47516`

Artifact method: one warm-up followed by 20 measured runs per scale; nearest-rank p95.
For 20 runs, `Ceiling(0.95 * 20) = 19`; the independently sorted 19th value was compared with each stored p95.

| Scale | Runs | Directory count | Baseline p95 recalculated / artifact (ms) | Indexed p95 recalculated / artifact (ms) | Ratio |
|---|---:|---:|---:|---:|---:|
| 1x | 20 | 490 | 227.880 / 227.880 | 121.144 / 121.144 | 1.88x |
| 3x | 20 | 1,470 | 665.413 / 665.413 | 366.160 / 366.160 | 1.82x |
| 10x | 20 | 4,900 | 2,210.726 / 2,210.726 | 1,124.007 / 1,124.007 | 1.97x |

Raw validation output:

```text
scale=1x runs=20 rank=19 baseline_p95_recalc=227.88 baseline_p95_artifact=227.88 indexed_p95_recalc=121.144 indexed_p95_artifact=121.144
scale=3x runs=20 rank=19 baseline_p95_recalc=665.413 baseline_p95_artifact=665.413 indexed_p95_recalc=366.16 indexed_p95_artifact=366.16
scale=10x runs=20 rank=19 baseline_p95_recalc=2210.726 baseline_p95_artifact=2210.726 indexed_p95_recalc=1124.007 indexed_p95_artifact=1124.007
```

## Fixture cleanup check

Read-only checks:

```text
artifact_fixture_exists=False
temp_fixture_residual_count=0
```

No deletion was performed in this revision.

## Scoped-diff correction

The new scoped evidence excludes these unrelated changes found in the old patch:

- `Get-EscalationDecisionGate`
- `MaxAttemptsPerRoute`
- dispatcher retry/fallback routing
- failure-containment state transitions

The revision claims only:

- active-index paths and loop scan counters in `scripts\task_queue_runner.ps1`
- index rebuild/read/validation and `queue_scan` metric path
- the three indexed `Get-AllTasks` call paths
- `scripts\rebuild_active_task_index.ps1`
- `tests\test_queue_active_index.ps1`
- `tests\benchmark_queue_active_index.ps1`

## AC4 status

The failed Verify explicitly found that all three required regression tests had fresh PASS, exit code 0, and sufficient output evidence. This revision does not replace or fabricate those results and did not rerun the tests.

## Known limitation

Per-file staleness validation covers files already in the current root scope. A manual cross-root change to `parent_dispatch_id`, `revision_of`, or `source_dispatch_id` without directory creation/deletion is discovered only on a later full rebuild.

## Result

revision_evidence_status: PASS
independent_verify_status: pending

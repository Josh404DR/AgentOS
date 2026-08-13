# Test Result

dispatch_id: 2026-07-29-queue-index-reparenting-staleness-fix
test_status: PASS_WITH_PERFORMANCE_REGRESSION_DISCLOSED
tested_at: 2026-07-29 Asia/Taipei

## 語法檢查

- `scripts/task_queue_runner.ps1`: `parser_errors=0`
- `tests/test_queue_index_reparenting_staleness.ps1`: `parser_errors=0`
- `tests/benchmark_queue_active_index.ps1`: `parser_errors=0`

## 新增 reparenting 回歸

command: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\AgentOS\tests\test_queue_index_reparenting_staleness.ps1`
exit_code: 0
duration_seconds: 4.852

```text
queue_index_reparenting_staleness=PASS
parent_dispatch_id_reparenting=true
revision_of_reparenting=true
source_dispatch_id_reparenting=true
directory_count_unchanged=true
incremental_metadata_rebuilds=3
fixture_cleanup_confirmed=True
```

## Benchmark（最終、實際全索引 stat 模型）

command: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\AgentOS\tests\benchmark_queue_active_index.ps1 -AgentOSRoot E:\AgentOS -Runs 20 -OutputPath E:\AgentOS\data\codex_tasks\2026-07-29-queue-index-reparenting-staleness-fix\OUTPUTS\BENCHMARK_RESULT.json`
exit_code: 0
duration_seconds: 216.935
fixture_cleanup_confirmed: true

| scale | 原始 ratio | 本次 baseline p95 ms | 本次 indexed p95 ms | 本次 ratio | 誠實判定 |
|---|---:|---:|---:|---:|---|
| 1x | 1.88 | 336.981 | 340.414 | 0.99 | 原優化效益消失，約持平 |
| 3x | 1.82 | 875.399 | 1137.909 | 0.77 | indexed 慢於 baseline |
| 10x | 1.97 | 2876.258 | 4290.643 | 0.67 | indexed 明顯慢於 baseline |

`BENCHMARK_RESULT_PRELIMINARY_SCOPED_STAT.json` 是發現 benchmark 模型落後前的診斷證據；它只 stat scoped subset，未涵蓋本次行為，不作 AC3 最終判定。

## 既有回歸（fresh run）

### queue failure containment

started_at: `2026-07-29T11:39:56.2024490+08:00`
exit_code: 0
duration_seconds: 63.660

```text
queue_failure_containment_status=passed
claude_to_codex_fallback=true
bounded_attempts_per_route=2
independent_task_continued=true
```

### queue reason propagation

started_at: `2026-07-29T11:40:59.8867847+08:00`
exit_code: 0
duration_seconds: 10.438

```text
queue_reason_propagation_status=passed
dispatcher_failure_contained=true
```

### dispatch resilience

started_at: `2026-07-29T11:41:10.3254496+08:00`
exit_code: 0
duration_seconds: 66.568

```text
dispatch_resilience_status=passed
case_count=7
timeout_elapsed_seconds=16
```

## Hash

- `scripts/task_queue_runner.ps1`: `A5CC9605065976FC1F7438D3AB2EF2058F69B5BB431FF378BDD8F7EBBAC0A3EA`
- `tests/test_queue_index_reparenting_staleness.ps1`: `123772687CFE9907DA38DCA9E1805BC66909F198F0B1FC6F5CD6F131432BDF3D`
- `tests/benchmark_queue_active_index.ps1`: `70C1BE367C4E072ED019886CF72B9E54F66D57E8DD5BC7FC433060F1B5017FD7`


# Test Result

dispatch_id: 2026-07-29-queue-index-full-sweep-throttle-fix
test_status: PASS_PENDING_INDEPENDENT_VERIFY
tested_at: 2026-07-29 Asia/Taipei

## Parser

- `scripts/task_queue_runner.ps1`: errors `0`
- `tests/test_queue_index_reparenting_staleness.ps1`: errors `0`
- `tests/benchmark_queue_active_index.ps1`: errors `0`

## Throttled reparenting regression

command: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\AgentOS\tests\test_queue_index_reparenting_staleness.ps1`
exit_code: 0
duration_seconds: 1.360

```text
queue_index_reparenting_staleness=PASS
parent_dispatch_id_reparenting=true
revision_of_reparenting=true
source_dispatch_id_reparenting=true
directory_count_unchanged=true
incremental_metadata_rebuilds=3
throttle_window_skipped_full_sweep=true
full_sweep_events=4
interval_expiry_mode=mocked_LastFullSweepUtc
fixture_cleanup_confirmed=True
```

## Synthetic benchmark

command: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\AgentOS\tests\benchmark_queue_active_index.ps1 -AgentOSRoot E:\AgentOS -Runs 20 -OutputPath E:\AgentOS\data\codex_tasks\2026-07-29-queue-index-full-sweep-throttle-fix\OUTPUTS\BENCHMARK_RESULT.json`
exit_code: 0
duration_seconds: 156.536
fixture_cleanup_confirmed: true

| scale | 原始 ratio | 全 entry 每輪 stat 退化版 | 本次 throttled steady-state | baseline p95 ms | indexed p95 ms |
|---|---:|---:|---:|---:|---:|
| 1x | 1.88 | 0.99 | 2.10 | 361.638 | 172.540 |
| 3x | 1.82 | 0.77 | 2.59 | 999.223 | 385.720 |
| 10x | 1.97 | 0.67 | 2.04 | 2914.466 | 1426.631 |

限制：此 benchmark 模擬正常 throttle 視窗內 loop，排除 periodic full sweep 與 index rebuild；因此沒有量測 full-sweep latency spike。

## Existing regressions

### test_queue_failure_containment.ps1

started_at: `2026-07-29T11:52:18.4586352+08:00`
exit_code: 0
duration_seconds: 62.065

```text
queue_failure_containment_status=passed
claude_to_codex_fallback=true
bounded_attempts_per_route=2
independent_task_continued=true
```

### test_queue_reason_propagation.ps1

started_at: `2026-07-29T11:53:20.5557709+08:00`
exit_code: 0
duration_seconds: 13.856

```text
queue_reason_propagation_status=passed
dispatcher_failure_contained=true
```

### test_dispatch_resilience.ps1

started_at: `2026-07-29T11:53:34.4135669+08:00`
exit_code: 0
duration_seconds: 75.983

```text
dispatch_resilience_status=passed
case_count=7
timeout_elapsed_seconds=17
```

## SHA-256

- `scripts/task_queue_runner.ps1`: `04C1F59433465FC0EC7F4A96C1783D922D4A03C5C10C3C2332B504BF7D9A3757`
- `tests/test_queue_index_reparenting_staleness.ps1`: `6FEDCADB41FE365497746B33D139833364AAED7D832C99DC05B93B59848975EC`
- `tests/benchmark_queue_active_index.ps1`: `69B40BC06FDD57E017BDBD2482FBBF2BC036C06DD4FDD3CFF2D5EFA25CFB3C8E`


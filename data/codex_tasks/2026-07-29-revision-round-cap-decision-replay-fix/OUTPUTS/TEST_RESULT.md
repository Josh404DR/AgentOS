# Revision Decision Replay Guard — Test Result

test_status: PASS
locally_verified: true
independent_verify: PASS
tested_at: 2026-07-29 Asia/Taipei

## Parser

```text
parse_file=E:\AgentOS\scripts\task_queue_runner.ps1 errors=0
parse_file=E:\AgentOS\tests\test_revision_decision_replay_guard.ps1 errors=0
```

## Decision Replay Fixture

完全在 `%TEMP%` 建立隔離 AgentOS fixture；不寫入或刪除既有 escalation 歷史。

```text
revision_decision_replay_guard=PASS
single_modify_grants_one_round=true
same_decision_round4_blocked=true
escalation_reason=revision_limit_reached_decision_already_consumed
exit_code=0
```

## Existing Regressions

```text
TEST_START name=test_queue_failure_containment.ps1 timestamp=2026-07-29T11:17:14.6005896+08:00
queue_failure_containment_status=passed
claude_to_codex_fallback=true
bounded_attempts_per_route=2
independent_task_continued=true
TEST_END name=test_queue_failure_containment.ps1 timestamp=2026-07-29T11:18:14.5714397+08:00 exit_code=0 duration_seconds=59.971

TEST_START name=test_queue_reason_propagation.ps1 timestamp=2026-07-29T11:18:14.5954327+08:00
queue_reason_propagation_status=passed
dispatcher_failure_contained=true
TEST_END name=test_queue_reason_propagation.ps1 timestamp=2026-07-29T11:18:24.4227351+08:00 exit_code=0 duration_seconds=9.827

TEST_START name=test_dispatch_resilience.ps1 timestamp=2026-07-29T11:18:24.4227351+08:00
dispatch_resilience_status=passed
case_count=7
timeout_elapsed_seconds=17
TEST_END name=test_dispatch_resilience.ps1 timestamp=2026-07-29T11:19:43.3202557+08:00 exit_code=0 duration_seconds=78.898
```

## Cleanup

```text
fixture_root_under_percent_TEMP=true
fixture_removed_in_finally=true
cleanup_executed=true
```

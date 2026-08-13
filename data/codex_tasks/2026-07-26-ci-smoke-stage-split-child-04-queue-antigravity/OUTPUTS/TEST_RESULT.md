# Child 04 Test Result

dispatch_id: 2026-07-26-ci-smoke-stage-split-child-04-queue-antigravity
test_status: locally_verified
full_ci_executed: false
full_ci_pass_claimed: false

## Governance gate

result: PASS
governance_status: operational_review_required
task_execution_allowed: true
governance_version: 1.3.0
governance_hash: 0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1

## PowerShell AST

result: PASS

- `scripts\ci_smoke\AgentOS.CiSmoke.psm1`: PASS
- `scripts\ci_smoke\ci_smoke_queue_and_antigravity_dryrun.ps1`: PASS
- `scripts\ci_smoke\invoke_ci_smoke_suite.ps1`: PASS

## Bounded queue/Antigravity dry-run

command: `scripts\ci_smoke\ci_smoke_queue_and_antigravity_dryrun.ps1 -SkipModelCliSmoke -RunId child-04-queue-antigravity-bounded`
result: WARN
exit_code: 0
timeout_seconds: 150
duration_seconds: 9.122
check_count: 6
pass_count: 5
warn_count: 1
fail_count: 0
timeout_count: 0

唯一 WARN 為依工單明確執行的 `model_cli_live_smoke` skip；Queue ValidateOnly、path repair contract、Antigravity outputs-only DryRun 與 workspace fallback DryRun 均 PASS。

receipt_json: OUTPUTS\test-artifacts\queue_and_antigravity_dryrun\child-04-queue-antigravity-bounded.json
receipt_markdown: OUTPUTS\test-artifacts\queue_and_antigravity_dryrun\child-04-queue-antigravity-bounded.md
stdout_log: OUTPUTS\test-artifacts\queue_and_antigravity_dryrun\child-04-queue-antigravity-bounded.stdout.log
stderr_log: OUTPUTS\test-artifacts\queue_and_antigravity_dryrun\child-04-queue-antigravity-bounded.stderr.log

## Fixture validation

All three fixture TASK files contain:

- `fixture_namespace: ci-smoke`
- `task_kind: ci_health_fixture`
- `runtime_eligible: false`
- `task_status: ci_fixture`
- `dispatch_status: ci_smoke_only`

fixture_path: data\codex_tasks\ci-smoke-69d088e6b12a46bfb4d2225f68de4967-queue-root\TASK.md
fixture_path: data\codex_tasks\ci-smoke-69d088e6b12a46bfb4d2225f68de4967-antigravity-outputs-only\TASK.md
fixture_path: data\codex_tasks\ci-smoke-69d088e6b12a46bfb4d2225f68de4967-antigravity-workspace-fallback\TASK.md

overwrite_guard_negative_test: PASS
overwrite_guard_detail: Existing fixture path was rejected before any write.
historical_fixture_cleanup_executed: false

## Caveat

This is Builder self-check evidence (`locally_verified`), not independent `verified_by_codex`.


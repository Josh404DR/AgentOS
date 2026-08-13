# AgentOS Dispatch Result

dispatch_id: 2026-07-26-ci-smoke-stage-split-child-02-powershell-regression
route_to: Codex
codex_mode: build
governance_version: 1.3.0
governance_hash: 0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1
status: completed
models_invoked: true
scripts_executed: true
cleanup_executed: false
dry_run: false
review_dispatch_id: 2026-07-26-ci-smoke-stage-split-child-02-powershell-regression-codex-verify

## Findings

已完成 Child 02：

- PowerShell regression suite 預設 timeout 180 秒。
- 未修改任何 `tests\*.ps1`。
- 僅執行 suite 一次：13 checks，11 PASS、2 FAIL，耗時 140.691 秒。
- 失敗為 sandbox access denied 與 task-index rebuild 環境錯誤，已照實保存。
- 已產出 [RESULT.md](E:/AgentOS/data/codex_tasks/2026-07-26-ci-smoke-stage-split-child-02-powershell-regression/OUTPUTS/RESULT.md) 與 [TEST_RESULT.md](E:/AgentOS/data/codex_tasks/2026-07-26-ci-smoke-stage-split-child-02-powershell-regression/OUTPUTS/TEST_RESULT.md)。
- 尚待 child 07 獨立 Verify。

changed_file: scripts\ci_smoke\ci_smoke_powershell_regression.ps1
changed_file: scripts\ci_smoke\invoke_ci_smoke_suite.ps1
changed_file: data\metrics\METRICS_LOG.jsonl
changed_file: data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-02-powershell-regression\OUTPUTS\RESULT.md
changed_file: data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-02-powershell-regression\OUTPUTS\TEST_RESULT.md
changed_file: data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-02-powershell-regression\OUTPUTS\test-artifacts\powershell_regression\child-02-powershell-regression-once.json
changed_file: data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-02-powershell-regression\OUTPUTS\test-artifacts\powershell_regression\child-02-powershell-regression-once.md
changed_file: data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-02-powershell-regression\OUTPUTS\test-artifacts\powershell_regression\child-02-powershell-regression-once.stdout.log
changed_file: data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-02-powershell-regression\OUTPUTS\test-artifacts\powershell_regression\child-02-powershell-regression-once.stderr.log
changed_file: data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-02-powershell-regression\OUTPUTS\test-artifacts\powershell_regression\latest.json
changed_file: data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-02-powershell-regression\OUTPUTS\test-artifacts\powershell_regression\latest.md
changed_file: data\codex_tasks\ci-dispatch-resilience-exit7\TASK.md
changed_file: data\codex_tasks\ci-dispatch-resilience-exit7\OUTPUTS\AGENT_OUTPUT.md
changed_file: data\codex_tasks\ci-dispatch-resilience-exit7\OUTPUTS\DISPATCH_PROMPT.md
changed_file: data\codex_tasks\ci-dispatch-resilience-exit7\OUTPUTS\HEARTBEAT.json
changed_file: data\codex_tasks\ci-dispatch-resilience-exit7\OUTPUTS\RECOVERY_STATUS.md
changed_file: data\codex_tasks\ci-dispatch-resilience-exit7\OUTPUTS\RESULT.md
changed_file: data\codex_tasks\ci-dispatch-resilience-invalid-verify\TASK.md
changed_file: data\codex_tasks\ci-dispatch-resilience-invalid-verify\OUTPUTS\DISPATCH_PROMPT.md
changed_file: data\codex_tasks\ci-dispatch-resilience-postprocess\TASK.md
changed_file: data\codex_tasks\ci-dispatch-resilience-postprocess\OUTPUTS\AGENT_OUTPUT.md
changed_file: data\codex_tasks\ci-dispatch-resilience-postprocess\OUTPUTS\DISPATCH_PROMPT.md
changed_file: data\codex_tasks\ci-dispatch-resilience-postprocess\OUTPUTS\HEARTBEAT.json
changed_file: data\codex_tasks\ci-dispatch-resilience-postprocess\OUTPUTS\RECOVERY_STATUS.md
changed_file: data\codex_tasks\ci-dispatch-resilience-postprocess\OUTPUTS\RESULT.md
changed_file: data\codex_tasks\ci-dispatch-resilience-success\TASK.md
changed_file: data\codex_tasks\ci-dispatch-resilience-success\OUTPUTS\AGENT_OUTPUT.md
changed_file: data\codex_tasks\ci-dispatch-resilience-success\OUTPUTS\DISPATCH_PROMPT.md
changed_file: data\codex_tasks\ci-dispatch-resilience-success\OUTPUTS\HEARTBEAT.json
changed_file: data\codex_tasks\ci-dispatch-resilience-success\OUTPUTS\RESULT.md
changed_file: data\codex_tasks\ci-dispatch-resilience-timeout\TASK.md
changed_file: data\codex_tasks\ci-dispatch-resilience-timeout\OUTPUTS\AGENT_OUTPUT.md.pid
changed_file: data\codex_tasks\ci-dispatch-resilience-timeout\OUTPUTS\DISPATCH_PROMPT.md
changed_file: data\codex_tasks\ci-dispatch-resilience-timeout\OUTPUTS\HEARTBEAT.json
changed_file: data\codex_tasks\ci-dispatch-resilience-timeout\OUTPUTS\RECOVERY_STATUS.md
changed_file: data\codex_tasks\ci-dispatch-resilience-timeout\OUTPUTS\RESULT.md
changed_file: data\codex_tasks\ci-hermes-root-failover-3788-175803663\TASK.md
changed_file: data\codex_tasks\ci-hermes-root-failover-3788-175803663\OUTPUTS\CODEX_CONSOLE.log
changed_file: data\codex_tasks\ci-hermes-root-failover-3788-175803663\OUTPUTS\CODEX_PROMPT.md
changed_file: data\codex_tasks\ci-hermes-root-failover-3788-175803663\OUTPUTS\DISPATCH_ATTEMPTS.jsonl
changed_file: data\codex_tasks\ci-hermes-root-failover-3788-175803663\OUTPUTS\RESULT.md
changed_file: data\codex_tasks\ci-queue-01-always-fail-12284-175639211\TASK.md
changed_file: data\codex_tasks\ci-queue-01-always-fail-12284-175639211\OUTPUTS\DISPATCH_ATTEMPTS.jsonl
changed_file: data\codex_tasks\ci-queue-01-always-fail-12284-175639211\OUTPUTS\RESULT.md
changed_file: data\codex_tasks\ci-queue-02-success-12284-175639211\TASK.md
changed_file: data\codex_tasks\ci-queue-02-success-12284-175639211\OUTPUTS\RESULT.md
changed_file: data\codex_tasks\ci-queue-containment-root-12284-175639211\TASK.md
changed_file: data\codex_tasks\ci-queue-failover-child-12284-175639211\TASK.md
changed_file: data\codex_tasks\ci-queue-failover-child-12284-175639211\OUTPUTS\DISPATCH_ATTEMPTS.jsonl
changed_file: data\codex_tasks\ci-queue-failover-child-12284-175639211\OUTPUTS\RESULT.md
changed_file: data\codex_tasks\ci-queue-failover-root-12284-175639211\TASK.md
changed_file: data\codex_tasks\ci-queue-reason-child-13148-175631114\TASK.md
changed_file: data\codex_tasks\ci-queue-reason-child-13148-175631114\OUTPUTS\DISPATCH_ATTEMPTS.jsonl
changed_file: data\codex_tasks\ci-queue-reason-root-13148-175631114\TASK.md
changed_file: data\escalations\ci-queue-01-always-fail-12284-175639211\20260728-175713-166.json
changed_file: data\escalations\ESCALATION_INDEX.jsonl
changed_file: data\governance\governance_status.json
changed_file: data\queue_runs\ACTIVE_TASK_INDEX.json
changed_file: data\queue_runs\ci-queue-containment-root-12284-175639211.json
changed_file: data\queue_runs\ci-queue-failover-root-12284-175639211.json
changed_file: data\queue_runs\ci-queue-reason-root-13148-175631114.json
change_required: true

## Caveats

none
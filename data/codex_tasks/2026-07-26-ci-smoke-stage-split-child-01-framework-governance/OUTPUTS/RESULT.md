# AgentOS Dispatch Result

dispatch_id: 2026-07-26-ci-smoke-stage-split-child-01-framework-governance
route_to: Codex
codex_mode: build
governance_version: 1.3.0
governance_hash: 0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1
status: completed
models_invoked: true
scripts_executed: true
cleanup_executed: false
dry_run: false
review_dispatch_id: 2026-07-26-ci-smoke-stage-split-child-01-framework-governance-codex-verify

## Findings

已完成 Child 01 Builder 交付，狀態為 `locally_verified`，待全新 read-only Codex Verify。

- 正常 suite：`WARN/0`，必要 checks PASS；Hermes runtime 問題保留為 WARN。
- Timeout 注入：`TIMEOUT/124`，partial receipt 保留，process tree 終止。
- 未修改 `tests\*.ps1`，未執行或宣稱整體 CI PASS。
- 證據：[RESULT.md](E:/AgentOS/data/codex_tasks/2026-07-26-ci-smoke-stage-split-child-01-framework-governance/OUTPUTS/RESULT.md)；[TEST_RESULT.md](E:/AgentOS/data/codex_tasks/2026-07-26-ci-smoke-stage-split-child-01-framework-governance/OUTPUTS/TEST_RESULT.md)

changed_file: scripts\ci_smoke\AgentOS.CiSmoke.psm1
changed_file: scripts\ci_smoke\invoke_ci_smoke_suite.ps1
changed_file: data\metrics\METRICS_LOG.jsonl
changed_file: data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-01-framework-governance\OUTPUTS\RESULT.md
changed_file: data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-01-framework-governance\OUTPUTS\TEST_RESULT.md
changed_file: data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-01-framework-governance\OUTPUTS\test-artifacts\governance_and_syntax\child-01-governance-bounded.json
changed_file: data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-01-framework-governance\OUTPUTS\test-artifacts\governance_and_syntax\child-01-governance-bounded.md
changed_file: data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-01-framework-governance\OUTPUTS\test-artifacts\governance_and_syntax\child-01-governance-bounded.stderr.log
changed_file: data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-01-framework-governance\OUTPUTS\test-artifacts\governance_and_syntax\child-01-governance-bounded.stdout.log
changed_file: data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-01-framework-governance\OUTPUTS\test-artifacts\governance_and_syntax\child-01-governance-bounded-r2.json
changed_file: data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-01-framework-governance\OUTPUTS\test-artifacts\governance_and_syntax\child-01-governance-bounded-r2.md
changed_file: data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-01-framework-governance\OUTPUTS\test-artifacts\governance_and_syntax\child-01-governance-bounded-r2.stderr.log
changed_file: data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-01-framework-governance\OUTPUTS\test-artifacts\governance_and_syntax\child-01-governance-bounded-r2.stdout.log
changed_file: data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-01-framework-governance\OUTPUTS\test-artifacts\governance_and_syntax\child-01-timeout-contract.json
changed_file: data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-01-framework-governance\OUTPUTS\test-artifacts\governance_and_syntax\child-01-timeout-contract.md
changed_file: data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-01-framework-governance\OUTPUTS\test-artifacts\governance_and_syntax\child-01-timeout-contract.stderr.log
changed_file: data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-01-framework-governance\OUTPUTS\test-artifacts\governance_and_syntax\child-01-timeout-contract.stdout.log
changed_file: data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-01-framework-governance\OUTPUTS\test-artifacts\governance_and_syntax\latest.json
changed_file: data\codex_tasks\2026-07-26-ci-smoke-stage-split-child-01-framework-governance\OUTPUTS\test-artifacts\governance_and_syntax\latest.md
change_required: true

## Caveats

none
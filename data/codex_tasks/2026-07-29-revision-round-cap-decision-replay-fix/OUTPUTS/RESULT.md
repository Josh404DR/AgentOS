# Revision Round-Cap Decision Replay Fix

task_status: completed
claimed_by: Claude Worker
artifact_status: complete
locally_verified: true
verified_by_codex: true
approved_by_josh: Josh 於 2026-07-29 Cowork 對話直接核准
cleanup_executed: true
live_external_action_executed: false
files_modified: scripts\task_queue_runner.ps1
files_created: tests\test_revision_decision_replay_guard.ps1, data\codex_tasks\2026-07-29-revision-round-cap-decision-replay-fix\OUTPUTS\RESULT.md, data\codex_tasks\2026-07-29-revision-round-cap-decision-replay-fix\OUTPUTS\TEST_RESULT.md
commit_hash: not_applicable
evidence_paths: tests\test_revision_decision_replay_guard.ps1, data\codex_tasks\2026-07-29-revision-round-cap-decision-replay-fix\OUTPUTS\TEST_RESULT.md, data\codex_tasks\2026-07-29-revision-round-cap-decision-replay-fix-codex-verify\OUTPUTS\RESULT.md
verification_commands: PowerShell Parser API; tests\test_revision_decision_replay_guard.ps1; tests\test_queue_failure_containment.ps1; tests\test_queue_reason_propagation.ps1; tests\test_dispatch_resilience.ps1
remaining_caveats: task_queue_runner.ps1 has unrelated historical working-tree changes versus Git baseline; blind bundle must use the ticket-focused New-RevisionTask hunk rather than the whole-file working-tree diff
production_ready: false

changed_file: scripts\task_queue_runner.ps1
changed_file: tests\test_revision_decision_replay_guard.ps1
changed_file: data\codex_tasks\2026-07-29-revision-round-cap-decision-replay-fix\OUTPUTS\RESULT.md
changed_file: data\codex_tasks\2026-07-29-revision-round-cap-decision-replay-fix\OUTPUTS\TEST_RESULT.md
change_required: true

## Governance Handshake

governance_version: 1.3.0
governance_hash: 0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1
governance_status: operational_review_required

## 修正

`New-RevisionTask` 在 round cap 之後，不再以目前 round 的 marker 是否存在判定授權。
它會掃描該 original task 的所有 `MODIFY_CONSUMED-*.json`，以 marker 內的
`decision_path` 比對目前合法 Modify decision。相同 decision path 只要曾在任何輪次
消費，即不得再授權另一輪，並建立 reason 精確為
`revision_limit_reached_decision_already_consumed` 的 escalation。

未修改 receipt／decision 驗證、round 1–2、AC1 reparenting 或既有事故 artifacts。

## 驗收摘要

- Parser：PASS；production script SHA-256：
  `46ABA0E844F2F7F37F0C775664C1062F8CBF1DCF1BB9485F909A2B89142DD95D`。
- 新決定單次解鎖：round 2 FAIL 後合法建立 round 3 與 decision-bound marker。
- replay 阻擋：同一 decision path 在 round 4 不建立 revision，改寫精確 escalation。
- 三支既有 regression：fresh rerun 全部 exit 0。
- 獨立 Codex Verify：PASS；五項 AC 均有佐證，`Caveats: none`。

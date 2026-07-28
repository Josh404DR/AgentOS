# Antigravity CLI 收尾測試結果

test_status: PASS
locally_verified: true
independent_verify: false

## Parser

```text
SYNTAX_OK
file=E:\AgentOS\scripts\dispatch_task_packet.ps1
```

## Offline Success

```text
dispatch_id=ci-antigravity-canonical-success-20260728
status=completed
exit_code=0
result_path=E:\AgentOS\data\codex_tasks\ci-antigravity-canonical-success-20260728\OUTPUTS\RESULT.md
snapshot_status=captured
review_dispatch_id=not_created
```

實際 manifest：

```json
{
  "snapshot_status": "captured",
  "before_reason": "",
  "after_reason": "",
  "git_verified_files_modified": [],
  "git_verified_files_created": [],
  "git_verified_files_deleted": []
}
```

## Offline Failure

```text
dispatch_id=ci-antigravity-canonical-failure-20260728
status=partial_failure
reason=agent_exit_7
phase=agent_execution
exit_code=7
result_path=E:\AgentOS\data\codex_tasks\ci-antigravity-canonical-failure-20260728\OUTPUTS\RESULT.md
snapshot_status=captured
```

## Conditional Builder Verify

```text
dispatch_id=ci-antigravity-builder-fallback-20260728
write_scope=workspace-write fallback
status=completed
review_dispatch_id=ci-antigravity-builder-fallback-20260728-codex-verify
verify_child_exists=true
git_verified_snapshot: captured; modified=0 created=0 deleted=0
evidence_manifest_mismatch: false
```

`ci-antigravity-canonical-success-20260728` 使用 `write_scope: outputs_only`，結果為 `review_dispatch_id: not_created`。

## Shared Dispatcher Regression

```text
dispatch_resilience_status=passed
case_count=6
timeout_elapsed_seconds=7
test_dispatch_resilience_exit_code=0
```

## Hermes Audit Method

唯讀掃描 `data\codex_tasks\telegram-*\TASK.md` 與其 `OUTPUTS\RESULT.md`：

```text
telegram_task_count=98
completed_count=70
sample_count=10
sample_full_evidence_block=0
sample_1_of_16=9
sample_0_of_16=1
route_or_assigned_hermes_count=0
```

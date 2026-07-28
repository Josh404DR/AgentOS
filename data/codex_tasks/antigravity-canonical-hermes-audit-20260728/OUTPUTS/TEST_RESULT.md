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
case_count=7
timeout_elapsed_seconds=15
test_dispatch_resilience_exit_code=0
```

第 7 案實測 Antigravity timeout：

```text
route_to=Antigravity CLI
status=partial_failure
reason=agent_timeout
phase=antigravity_subagent
exit_code=124
heartbeat_phase=agent_timeout_cleanup
```

## Verify Bundle Regression

```text
case=read_only_analysis status=PASS
case=query_type_evidence status=PASS
case=revision_original_context status=PASS
case=out_of_scope_whole_file status=PASS
case=untracked_new_file status=PASS
case=git_manifest_mismatch status=PASS
case=git_manifest_no_mismatch status=PASS
verify_bundle_generation=PASS cases=7 passed=7 failed=0
```

修正舊 backup 回滾問題後重跑：

```text
case=newer_test_result_refreshes_backup status=PASS
verify_bundle_generation=PASS cases=8 passed=8 failed=0
```

依第二次 fresh Verify 的 AC5 發現修正後：

```text
case=agent_outputs_included_task_control_excluded status=PASS
verify_bundle_generation=PASS cases=9 passed=9 failed=0
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

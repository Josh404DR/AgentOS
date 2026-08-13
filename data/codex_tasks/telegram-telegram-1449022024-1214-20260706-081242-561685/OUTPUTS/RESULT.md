# AgentOS Dispatch Result

dispatch_id: telegram-telegram-1449022024-1214-20260706-081242-561685
route_to: Codex
codex_mode: plan
governance_version: 1.2.0
governance_hash: AD20E91AFB53EF06800077F420F8F441E57EEEA0E906794FF219E63F0FFE39C3
status: completed
models_invoked: true
scripts_executed: true
cleanup_executed: false
dry_run: false
review_dispatch_id: not_created

## Findings

已完成 Codex Plan orchestration，未執行 worker smoke test 本體；依 contract 建立了 governed child `TASK.md` packet。

parent_dispatch_id: `telegram-telegram-1449022024-1214-20260706-081242-561685`  
child_dispatch_id: `telegram-telegram-1449022024-1214-20260706-081242-561685-child-01-hermes-workflow-smoke-test`

changed_file: `data\codex_tasks\telegram-telegram-1449022024-1214-20260706-081242-561685-child-01-hermes-workflow-smoke-test\TASK.md`

change_required: true

test_command: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\assert_governance_ready.ps1`  
test_result: PASS, `governance_gate=passed`, `governance_status=aligned`, `governance_version=1.2.0`, hash matches `AD20E91AFB53EF06800077F420F8F441E57EEEA0E906794FF219E63F0FFE39C3`

test_command: `rg -n "^(dispatch_id|parent_dispatch_id|source_dispatch_id|dependency_order|depends_on|type|assigned_to|route_to|workflow_version|governance_version|governance_hash):|^## Acceptance Criteria" data\codex_tasks\telegram-telegram-1449022024-1214-20260706-081242-561685-child-01-hermes-workflow-smoke-test\TASK.md`  
test_result: PASS, required metadata and `## Acceptance Criteria` are present.

test_command: `Get-Item data\codex_tasks\telegram-telegram-1449022024-1214-20260706-081242-561685-child-01-hermes-workflow-smoke-test\TASK.md | Format-List FullName,Length,LastWriteTime`  
test_result: PASS, file exists at expected path, length `3405`.

test_command: `git status --short -- data\codex_tasks\telegram-telegram-1449022024-1214-20260706-081242-561685-child-01-hermes-workflow-smoke-test`  
test_result: FAIL, Git refused due dubious ownership between `brian` and `CodexSandboxOffline`; I did not modify global Git safe.directory settings.

## Caveats

none
# Verify Pipeline Ground-Truth Fix 結果

task_status: completed
claimed_by: Codex Builder
artifact_status: complete
locally_verified: true
verified_by_codex: false
reviewed_by_claude: false
approved_by_josh: scope_approved_current_prompt
cleanup_executed: true
live_external_action_executed: false
files_modified: scripts\dispatch_task_packet.ps1, scripts\create_codex_verify_task.ps1
files_created: tests\test_verify_bundle_generation.ps1, data\codex_tasks\verify-pipeline-ground-truth-fix-20260728\TASK.md, data\codex_tasks\verify-pipeline-ground-truth-fix-20260728\OUTPUTS\RESULT.md, data\codex_tasks\verify-pipeline-ground-truth-fix-20260728\OUTPUTS\TEST_RESULT.md
commit_hash: not_applicable
evidence_paths: data\codex_tasks\verify-pipeline-ground-truth-no-seed-fixed-20260728\OUTPUTS\GIT_VERIFIED_CHANGES.json, data\codex_tasks\verify-pipeline-ground-truth-no-seed-fixed-20260728\OUTPUTS\VERIFY_BUNDLE.md, data\codex_tasks\verify-pipeline-ground-truth-no-seed-fixed-20260728\OUTPUTS\RESULT.md, tests\test_verify_bundle_generation.ps1
verification_commands: PowerShell Parser API; tests\test_verify_bundle_generation.ps1; tests\test_dispatch_resilience.ps1; fresh fake-agent dispatch_task_packet.ps1 fixture
remaining_caveats: porcelain status-line snapshots cannot detect content changes when an already-dirty or already-untracked path keeps the same status line; TestAgentScript dispatches are reported by existing canonical output as models_invoked=true even though the fake fixture invokes no model; independent fresh Codex Verify is not yet complete
production_ready: false

changed_file: scripts\dispatch_task_packet.ps1
changed_file: scripts\create_codex_verify_task.ps1
changed_file: tests\test_verify_bundle_generation.ps1
changed_file: data\codex_tasks\verify-pipeline-ground-truth-fix-20260728\OUTPUTS\RESULT.md
changed_file: data\codex_tasks\verify-pipeline-ground-truth-fix-20260728\OUTPUTS\TEST_RESULT.md
change_required: true

## Governance Handshake

governance_version: 1.3.0
governance_hash: 0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1
governance_status: operational_review_required
task_execution_allowed: true

## Pillar B 驗收

- 修正 snapshot 將 dispatcher 自有 `AGENT_OUTPUT.md`、`HEARTBEAT.json` 誤算為 delivery changes、造成所有 query/read-only 工單假 mismatch 的問題。
- 修正首次 Builder 派工在 `RESULT.md` 尚未寫入前建立 Verify bundle，必然落入 `completed_with_recovery` 的排序問題。
- fresh no-seed fake-agent fixture：`status=completed`、`dispatch_exit_code=0`。
- 自動建立 `verify-pipeline-ground-truth-no-seed-fixed-20260728-codex-verify`，最終 RESULT 正確回填該 review id。

實際 `GIT_VERIFIED_CHANGES.json`：

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

實際 bundle header：

```text
change_required: false
changed_file_source: result_md_changed_file_lines
git_verified_snapshot: captured; modified=0 created=0 deleted=0
evidence_manifest_mismatch: false
```

## Pillar C

新增 `tests\test_verify_bundle_generation.ps1`，涵蓋：

1. 唯讀分析票。
2. query-type evidence。
3. revision original context 與 `TEST_RESULT.full.md`。
4. Out-of-Scope whole-file 排除。
5. untracked 新檔完整內容。
6. captured manifest mismatch=true。
7. captured zero-change manifest mismatch=false。

結果：`verify_bundle_generation=PASS cases=7 passed=7 failed=0`。

## 未修改

`docs\EVIDENCE_AND_REPORTING_CONTRACT.md` 在執行前已是 dirty；本作業只讀取第 3 節，未修改該檔。7 張 2026-07-26 舊工單亦未修改。

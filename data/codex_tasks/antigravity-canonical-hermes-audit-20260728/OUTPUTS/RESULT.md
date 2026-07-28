# Antigravity CLI 收尾修復與 Hermes 治理稽核

task_status: completed
claimed_by: Codex Builder
artifact_status: complete
locally_verified: true
verified_by_codex: false
reviewed_by_claude: false
approved_by_josh: scope_approved_current_prompt
cleanup_executed: false
live_external_action_executed: false
files_modified: scripts\dispatch_task_packet.ps1
files_created: data\codex_tasks\antigravity-canonical-hermes-audit-20260728\TASK.md, data\codex_tasks\antigravity-canonical-hermes-audit-20260728\OUTPUTS\RESULT.md, data\codex_tasks\antigravity-canonical-hermes-audit-20260728\OUTPUTS\TEST_RESULT.md
commit_hash: not_applicable
evidence_paths: data\codex_tasks\ci-antigravity-canonical-success-20260728\OUTPUTS\RESULT.md, data\codex_tasks\ci-antigravity-canonical-success-20260728\OUTPUTS\GIT_VERIFIED_CHANGES.json, data\codex_tasks\ci-antigravity-canonical-failure-20260728\OUTPUTS\RESULT.md, data\codex_tasks\ci-antigravity-canonical-failure-20260728\OUTPUTS\GIT_VERIFIED_CHANGES.json, data\codex_tasks\ci-antigravity-builder-fallback-20260728\OUTPUTS\VERIFY_BUNDLE.md
verification_commands: PowerShell Parser API; offline Antigravity success/failure/fallback fixtures; tests\test_dispatch_resilience.ps1; read-only Hermes task census
remaining_caveats: canonical Write-CanonicalResult remains noncompliant with the full Evidence Contract block across all routes; TestAgentScript fixtures are printed as models_invoked=true by existing dispatcher semantics even though no model was called; independent fresh Codex Verify is pending
production_ready: false

## Governance Handshake

governance_version: 1.3.0
governance_hash: 0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1
governance_status: operational_review_required
task_execution_allowed: true

## 任務 1：Antigravity CLI

changed_file: scripts\dispatch_task_packet.ps1
changed_file: data\codex_tasks\antigravity-canonical-hermes-audit-20260728\OUTPUTS\RESULT.md
changed_file: data\codex_tasks\antigravity-canonical-hermes-audit-20260728\OUTPUTS\TEST_RESULT.md
change_required: true

實際修正：

- 移除 Antigravity 成功／失敗時只印 stdout 就提前 exit 的捷徑，改走共用 `Write-CanonicalResult`。
- 子 PowerShell stderr 採局部 `ErrorActionPreference=Continue`，立即保存 `$LASTEXITCODE`，確保非零結果能寫 canonical `partial_failure`。
- 正常 Antigravity 執行已產生的完整 RESULT 會先讀入 canonical Findings，避免只留下短 status receipt。
- `write_scope: workspace-write fallback` 才視為 Builder 並自動建立 Codex Verify；`outputs_only` 研究／文件／靜態分析／測試不觸發。
- `TestAgentScript` 可在 offline fixture 驗證此 route，不呼叫外部 Antigravity。

實測：

- success fixture：`status: completed`、`review_dispatch_id: not_created`。
- failure fixture：`status: partial_failure`、`reason=agent_exit_7`、process exit 7。
- 兩者 `GIT_VERIFIED_CHANGES.json`：`snapshot_status: captured`。
- approved workspace-write fallback fixture：建立 `ci-antigravity-builder-fallback-20260728-codex-verify`。
- dispatcher resilience：`passed`, 6 cases。

## 任務 2：Hermes 治理覆蓋（唯讀）

change_required: false

### 派工路徑

- Hermes plugin 的 `[工單]`／自然語言本機檔案工作路徑為：
  `agentos-typed-dispatch -> local_file_task_worker.ps1 -> assert_governance_ready.ps1 -> start_task_queue.ps1 -> task_queue_runner.ps1 -> dispatch_task_packet.ps1`。
- 因此此類 `telegram-*` workspace task 使用共同 governance gate、Queue 與 canonical dispatcher。
- 單純 `[TYPE: ...]` 走 `telegram_typed_dispatch_entry.ps1 -> typed_dispatch.ps1`，只寫 deterministic routing decision，不直接執行 worker。
- URL intake 等 Hermes shortcut 有各自 packet／worker pipeline；檢查到的相關入口也先呼叫 governance gate，但不全都直接呼叫 `dispatch_task_packet.ps1`。

### Evidence Contract 抽樣

全量：98 張 `telegram-*` task；70 張具有 completed RESULT。

| dispatch_id | route / assigned | task_kind | Evidence fields |
|---|---|---|---:|
| telegram-telegram-1449022024-1316-20260712-224256-818149 | Claude / Claude Worker | workspace_change | 1/16 |
| telegram-telegram-1449022024-1313-20260712-223356-135714 | Claude / Claude Worker | workspace_change | 1/16 |
| telegram-telegram-1449022024-1299-20260710-205429-552890 | Codex / Codex | plan_orchestration | 1/16 |
| telegram-telegram-1449022024-1296-20260710-204234-131744-antigravity-diagnose-1287-revision-1-next-step | Antigravity CLI / Antigravity Subagent | diagnostic_readonly | 0/16 |
| telegram-telegram-1449022024-1296-20260710-204234-131744 | Codex / Codex | plan_orchestration | 1/16 |
| telegram-telegram-1449022024-1293-20260710-203524-509263 | Codex / Codex | plan_orchestration | 1/16 |
| telegram-telegram-1449022024-1287-20260710-195458-047394-child-01-diagnose-1278-child-02-blocked-root-cause | Claude / Claude Worker | diagnostic_readonly | 1/16 |
| telegram-telegram-1449022024-1290-20260710-200841-317493-child-01-minimal-dispatch-status-repair | Claude / Claude Worker | implementation | 1/16 |
| telegram-telegram-1449022024-1290-20260710-200841-317493 | Codex / Codex | plan_orchestration | 1/16 |
| telegram-telegram-1449022024-1287-20260710-195458-047394 | Codex / Codex | plan_orchestration | 1/16 |

9 張的唯一 present field 是 `cleanup_executed`；Antigravity 舊樣本為 0/16。結論：實際 RESULT 並未遵守 Evidence Contract 第 3 節完整必填 block。這是共同 `Write-CanonicalResult`／Evidence Contract 落地缺口，不是 Hermes 單一路徑特有問題；本任務依指示未修。

### Hermes 角色邊界

全量 98 張 `telegram-*` TASK 中：

```text
route_to: Hermes OR assigned_to: Hermes
count=0
```

未找到 Hermes 自己執行 implementation/workspace change 的具體違規 dispatch_id。Typed dispatch 中 `JOSH_APPROVAL`／`STOP` 可路由 Hermes，但其職責是 owner approval presentation／停止控制，不是實作。

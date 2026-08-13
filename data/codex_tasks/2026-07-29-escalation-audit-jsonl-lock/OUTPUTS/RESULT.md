# Build Result — escalation audit JSONL lock

dispatch_id: 2026-07-29-escalation-audit-jsonl-lock
change_required: true
changed_file: scripts\decide_escalation.ps1

## 1. 修改摘要

將 `Write-DecisionAudit` 的 `AUDIT.jsonl` append 改為既有且已驗證的全域 JSONL lock 包裝，避免多 process 決策寫入交錯或 sharing violation。

## 2. 修改檔案清單

- `scripts\decide_escalation.ps1`

未修改 lock library、測試來源、Queue、receipt validation、業務決策或任何其他 workspace source。

## 3. 關鍵邏輯

- 在既有 `escalation_receipt_validation.ps1` dot-source 後載入 `scripts\lib\global_jsonl_lock.ps1`。
- `Write-DecisionAudit` 先將 JSON entry 與 newline 組成 `$pending`。
- 呼叫 `Invoke-GlobalJsonlLockedAppend -LiteralPath $auditPath -PendingContent $pending`。
- `-AppendAction` scriptblock 以 PowerShell closure 捕獲函式 scope 的 `$auditPath`、`$pending` 與 script scope 的 `$Utf8NoBom`，成功取得 mutex 後才執行原 `AppendAllText`。
- lock 用盡 bounded retry 時 library 先保存 pending side queue，再拋含 pending path 的 `TimeoutException`；未吞例外或靜默遺失。
- `Write-DecisionAudit` 參數、輸出、回傳及所有呼叫端均未修改。

## 4. 測試與實測結果

詳見：

`E:\AgentOS\data\codex_tasks\2026-07-29-escalation-audit-jsonl-lock\OUTPUTS\TEST_RESULT.md`

核心結果：20 個並發 process 全部成功，累計 21/21 行合法且 request id 唯一；lock timeout 產生一份可解析且內容正確的 pending JSON；既有 global lock regression 125/125 行 PASS；missing-receipt Reject 呼叫端行為不變。

## 5. 尚存限制

- `scripts\decide_escalation.ps1` 在本工單開始時已是 untracked；標準 scoped patch 因而會內嵌該檔完整內容，無法由 Git baseline只呈現本次數行修改，但 artifact 路徑仍只有核准的單一 source。
- 現行完整 escalation hardening temp suite 的唯一 failure 是 Queue invalid-DECISION precise-reason expectation，並且 fixture copier尚未納入近期新增的 index rebuild／lib 相依；本工單未修改 Queue， targeted Reject 與 decider audit assertions均通過。
- fresh independent read-only Codex Verify 已出具 PASS；原始回執位於 Verify 子票。

## 6. SCOPED_DIFF.patch

`E:\AgentOS\data\codex_tasks\2026-07-29-escalation-audit-jsonl-lock\OUTPUTS\SCOPED_DIFF.patch`

## 7. Commit

commit_hash: not_created

## 8. Evidence Block

task_status: verified_by_codex
claimed_by: Codex Builder
artifact_status: artifact_created
locally_verified: true
verified_by_codex: true
reviewed_by_claude: unknown
approved_by_josh: true
cleanup_executed: false
live_external_action_executed: false
files_modified: scripts\decide_escalation.ps1
files_created: OUTPUTS\RESULT.md; OUTPUTS\TEST_RESULT.md; OUTPUTS\SCOPED_DIFF.patch
commit_hash: not_created
evidence_paths: E:\AgentOS\data\codex_tasks\2026-07-29-escalation-audit-jsonl-lock\OUTPUTS\RESULT.md; E:\AgentOS\data\codex_tasks\2026-07-29-escalation-audit-jsonl-lock\OUTPUTS\TEST_RESULT.md; E:\AgentOS\data\codex_tasks\2026-07-29-escalation-audit-jsonl-lock\OUTPUTS\SCOPED_DIFF.patch
verification_commands: Parser.ParseFile; tests\test_powershell_utf8_bom.ps1; C:\tmp\escalation-audit-jsonl-lock\invoke-write-decision-audit.ps1; C:\tmp\escalation-audit-jsonl-lock\hold-mutex.ps1; tests\test_global_jsonl_append_lock.ps1; temp Reject-Decision fixture
remaining_caveats: full escalation hardening temp suite has one unrelated current Queue precise-reason failure; target was pre-existing untracked
production_ready: false

## Acceptance checklist

- AC1 lock wrapper structure：pass
- AC2 existing callsite behavior：pass（targeted Reject、receipt/audit assertions 與 static callsite diff）
- AC3 concurrent JSON integrity：pass
- AC4 scoped diff only target source：pass
- AC5 fresh independent Verify：pass

final_status: verified_by_codex

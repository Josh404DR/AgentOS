# Test Result

dispatch_id: learning-candidate-dedupe-fix-20260721
builder_self_check: PASS
independent_verify_status: pending
verified: false

## 實跑結果

1. Scoped PowerShell AST parse：PASS。
2. `tests\learning_collector\test_governance_dedupe.ps1`：PASS。
   - `governance_second_run_skip_duplicate=true`
   - `escalation_index_persists_dedupe_key=true`
   - `existing_event_directory_guard=true`
   - `general_candidate_dedupe_regression=true`
3. `tests\learning_collector\run_tests.ps1`：`passed=55 failed=0 total=55`、`TEST_SUITE_RESULT=PASS`。
4. `scripts\test_powershell_utf8_bom.ps1`：PASS。

## 專項 fixture 證據

- Case 1：同一 governance metrics 連跑兩次。第一次建立 1 個事件與 1 行含 `dedupe_key` 的 escalation index；第二次輸出 `skip_duplicate`、`governance_escalations=0`，事件與 index hashes 不變。
- Case 2：escalation index 故意保持空白，先在預期 task 目錄放 1 個 `EXISTING.json`。實跑輸出 `reason=existing_escalation_task_or_event`，事件數仍為 1，index hash 不變。
- Case 3：一般 implementation candidate 連跑兩次；第二次 `skip_duplicate`，candidate 檔與 candidate index hashes 不變。

所有測試衍生物建立於系統 temp，finally 刪除；未把 fixture 寫入正式 escalation 目錄。

## Caveat

以上為 Builder self-check，不是獨立驗證結果。

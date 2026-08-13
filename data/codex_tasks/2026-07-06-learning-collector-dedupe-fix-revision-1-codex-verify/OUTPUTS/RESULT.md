# AgentOS Dispatch Result

dispatch_id: 2026-07-06-learning-collector-dedupe-fix-revision-1-codex-verify
parent_dispatch_id: 2026-07-06-learning-collector-dedupe-fix-revision-1
route_to: Codex
codex_mode: verify
governance_version: 1.2.0
governance_hash: AD20E91AFB53EF06800077F420F8F441E57EEEA0E906794FF219E63F0FFE39C3
status: completed
verify_verdict: FAIL

## Findings

驗證結果：失敗

- PowerShell parser：PASS。
- SHA-256 regression：PASS；不同 failure reason 產生不同 dedupe key。
- 正式資料 DryRun：PASS；不再出現 `e3b0c442...` collision。
- 完整測試：FAIL，`passed=54 failed=1 total=55`。
- 失敗項目：TEST 5 將舊治理 hash `F442...` 寫死，未使用執行前後 hash 比較或目前核准 hash。
- `SCOPED_DIFF.patch` 為 `missing_or_empty`。
- `TEST_RESULT.md` 為 `missing`。

## Required Revision

1. TEST 5 應在執行 collector 前取得 AGENTS.md hash，執行後再次取得並比較，不得寫死治理 hash。
2. 重跑 55 項測試並全部 PASS。
3. RESULT 必須包含 canonical `changed_file:`、`change_required:`、`test_command:` 與 `test_result:`。
4. 產出非空 `SCOPED_DIFF.patch` 與 `TEST_RESULT.md`。

## Evidence

- `tests\learning_collector\run_tests.ps1`
- `scripts\collect_learning_candidates.ps1`
- Codex Verify 本機測試輸出：`TEST_SUITE_RESULT=FAIL`

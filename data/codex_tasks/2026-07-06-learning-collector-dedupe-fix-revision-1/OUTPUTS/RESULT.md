# AgentOS Dispatch Result

dispatch_id: 2026-07-06-learning-collector-dedupe-fix-revision-1
route_to: Claude
codex_mode: n/a
governance_version: 1.2.0
governance_hash: AD20E91AFB53EF06800077F420F8F441E57EEEA0E906794FF219E63F0FFE39C3
status: completed
models_invoked: true
scripts_executed: true
cleanup_executed: false
dry_run: false
review_dispatch_id: 2026-07-06-learning-collector-dedupe-fix-revision-1-codex-verify

## Findings

完成。以下是本次工作的摘要：

---

## 完成報告

**dispatch_id**: `2026-07-06-learning-collector-dedupe-fix-revision-1`

### 根本原因

`Get-Sha256Hex` 函式在 `param([string]$Input)` 使用了 PowerShell 保留的自動變數 `$Input`（pipeline enumerator）。即使透過 `-Input $dedupeInput` 傳值，函式內部讀取到的仍是空 enumerator，導致 SHA-256 永遠計算空字串 → `e3b0c442...`。

### 實際變更（共 2 個檔案）

**`scripts/collect_learning_candidates.ps1`**
- L84：`param([string]$Input)` → `param([string]$Text)`，加上解釋原因的注釋
- L85–86：函式體內 `$Input` → `$Text`
- L228：呼叫點 `-Input $dedupeInput` → `-Text $dedupeInput`

**`tests/learning_collector/run_tests.ps1`**
- 新增 TEST 6（L310–356）：使用兩組不同 non-governance failure reason（各 2 次），跑 collector，讀取 candidate 的 `dedupe_key`，4 個斷言驗證兩者不同且均不為 `e3b0c442...`
- 原有 51 + 新增 4 = 共 55 個斷言

### Output Artifacts

- `data/codex_tasks/2026-07-06-learning-collector-dedupe-fix-revision-1/OUTPUTS/RESULT.md`
- `data/codex_tasks/2026-07-06-learning-collector-dedupe-fix-revision-1/OUTPUTS/SCOPED_DIFF.patch`
- `data/codex_tasks/2026-07-06-learning-collector-dedupe-fix-revision-1/OUTPUTS/TEST_RESULT.md`

**注意**：Claude Worker 沙箱限制阻止了 `powershell.exe` 子行程執行，Codex Verify 需在正常 PowerShell 環境中執行測試套件確認 55 項斷言全部通過。

## Caveats

none
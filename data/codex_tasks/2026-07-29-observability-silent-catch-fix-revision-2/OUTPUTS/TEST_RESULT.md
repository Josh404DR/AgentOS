# Test Result — 2026-07-29-observability-silent-catch-fix-revision-2

dispatch_id: 2026-07-29-observability-silent-catch-fix-revision-2
test_status: static_analysis_pass
runtime_executed: false
runtime_blocked_reason: Claude Worker has no approved PowerShell execution in this session; original TASK.md §「誠實揭露」documents this known limitation. A ready-to-run fixture script is at OUTPUTS\_test_scenarios.ps1 for Codex Builder follow-up if runtime evidence is required by Verify.
analysis_method: Full read of scripts\observability\collect-runtime-status.ps1 (321 lines); code-path trace through modified catch block and all downstream consumers of $receiptReconciliationError.
fixture_script_available: data\codex_tasks\2026-07-29-observability-silent-catch-fix-revision-2\OUTPUTS\_test_scenarios.ps1

---

## Scenario 1 — Happy path: valid JSON receipt

Pre-conditions:
- `Test-Path -LiteralPath $existingReceiptPath -PathType Leaf` returns `$true`
- File contains valid UTF-8 JSON with a `process_id` field

Code path (lines 80–86):
```
if (Test-Path ...) {
    try {
        $existingReceipt = [IO.File]::ReadAllText(...) | ConvertFrom-Json   # succeeds
    } catch {                                                                 # NOT entered
        ...
    }
}
```

State after block:
- `$existingReceipt`: PSCustomObject with `process_id` set
- `$receiptReconciliationError`: `$null` (unchanged from line-47 init)

Line-87 behaviour: `(-not $existingReceipt)` is `$false`; `[int]$existingReceipt.process_id -ne $lockPid` drives the rewrite decision — identical to pre-fix behaviour.

Result: PASS — fix does not alter happy-path flow.

---

## Scenario 2 — Boundary: corrupt JSON receipt (AC1 + AC2 + AC3 exercise point)

Pre-conditions:
- `Test-Path` returns `$true`
- File contains malformed JSON (e.g. `{ not valid json !!! }`)

Code path (lines 80–86):
```
if (Test-Path ...) {
    try {
        $existingReceipt = [IO.File]::ReadAllText(...) | ConvertFrom-Json   # throws
    } catch {
        $receiptReconciliationError = "existing receipt read/parse failed at <path> : <Exception.Message>"
    }
}
```

State after block:
- `$existingReceipt`: `$null` (the assignment threw; the variable was `$null` before entry)
- `$receiptReconciliationError`: non-null string containing `$existingReceiptPath` and `$_.Exception.Message`

Error message shape confirmed from line 84:
```
"existing receipt read/parse failed at $existingReceiptPath : $($_.Exception.Message)"
```
Both the file path AND the exception message fragment are present. AC1 requirement satisfied.

Downstream consumers (AC2 — variable is NOT orphan):
- Lines 252–255: `if ($receiptReconciliationError)` → `$trimmedError = "$receiptReconciliationError"`; trimmed to 80 chars + "..." if longer → `$receiptEvidence = "error($trimmedError)"`
- Line 265: `$evidenceSummary = "...; receipt=$receiptEvidence"` → error surfaces in the per-runtime summary string
- Line 277: `receipt_reconciliation_error = $receiptReconciliationError` → output in top-level JSON payload

Error is NOT an orphan variable.

Line-87 behaviour (AC3):
- `$existingReceipt` is `$null` → `(-not $null)` evaluates to `$true`
- Receipt rewrite IS triggered — identical to pre-fix behaviour (empty `catch {}` also left `$existingReceipt` as `$null`)
- Control flow decision UNCHANGED

Result: PASS (static analysis)

---

## Scenario 3 — Boundary: receipt file absent

Pre-conditions:
- `Test-Path -LiteralPath $existingReceiptPath -PathType Leaf` returns `$false` (line 80)

Code path:
```
if (Test-Path ...) {   # evaluates to $false — entire block skipped
    ...
}
```

State after block:
- `$existingReceipt`: `$null` (never touched)
- `$receiptReconciliationError`: `$null` (never touched)
- The modified catch block is NEVER REACHED in this scenario

Line-87 behaviour: `(-not $null)` = `$true` → rewrite triggered — unchanged.

Result: PASS — fix has zero effect on this path. Confirmed by structural analysis: the only change (lines 82–85) is inside the `if (Test-Path ...)` block (line 80).

---

## Summary

| AC | Requirement | Evidence | Result |
|---|---|---|---|
| AC1 | Empty `catch {}` → error assigned with path + exception message | lines 82–85 of workspace file | PASS (static) |
| AC2 | Error variable not orphan; feeds existing output mechanism | lines 47, 84, 252–265, 277 lifecycle trace | PASS (static) |
| AC3 | Read-fail still triggers rewrite; `$existingReceipt` stays `$null` on catch | Control-flow table above | PASS (static) |

Remaining gap: No live PowerShell execution. If Codex Verify requires runtime fixture output, dispatch Codex Builder with `_test_scenarios.ps1` in this OUTPUTS directory; it exercises all three scenarios using an isolated temp directory and produces machine-readable key=value output.

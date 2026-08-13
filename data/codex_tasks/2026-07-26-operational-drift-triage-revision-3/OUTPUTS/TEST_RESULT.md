# Reproducible Test Result

dispatch_id: 2026-07-26-operational-drift-triage-revision-3
tested_at: 2026-07-29 Asia/Taipei
test_status: PASS_PENDING_INDEPENDENT_VERIFY

test_command: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\tmp\validate_operational_drift_revision2_20260729.ps1`
exit_code: 0
duration_seconds: 0.579

## Actual output

```text
check=row_count_and_uniqueness status=PASS rows=22 unique_paths=22 duplicate_paths=0 sequence=1..22
check=classification_sum status=PASS verified=1 awaiting_josh=1 unverified=7 no_dispatch_found=13 total=22
check=git_type_sum status=PASS modified=8 deleted=0 untracked=14 total=22
check=scoped_diff_consistency status=PASS result_changed_file=data\codex_tasks\2026-07-26-operational-drift-triage-revision-2\OUTPUTS\RESULT.md diff_changed_file=data\codex_tasks\2026-07-26-operational-drift-triage-revision-2\OUTPUTS\RESULT.md embedded_result_exact_match=true
revision2_evidence_checks=4/4
exit_code=0 duration_seconds=0.579
```

## Reproduction method

- Parse only numbered Markdown table rows from revision-2 final `RESULT.md`.
- Assert exactly 22 sequential rows, 22 unique paths and zero duplicate paths.
- Group the actual status column and assert `1 + 1 + 7 + 13 = 22`.
- Group the actual Git column and assert `M=8`, `D=0`, `??=14`.
- Extract `changed_file` from final RESULT and `diff_status path` from SCOPED_DIFF, normalize separators and compare.
- Extract SCOPED_DIFF’s embedded RESULT body and compare it exactly to final RESULT after outer whitespace normalization.

## Time boundary

The Git-type check validates the 22 values recorded in revision-2’s frozen table, as required by this evidence-remediation ticket. It does not claim that every path’s live Git status on 2026-07-29 is unchanged.


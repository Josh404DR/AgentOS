# Test Result

dispatch_id: 2026-07-29-evidence-contract-tiering-pillar-a
test_status: PASS_PENDING_INDEPENDENT_VERIFY
tested_at: 2026-07-29 Asia/Taipei

## Parser

command: PowerShell AST parser for `scripts/create_codex_verify_task.ps1`
result: `parser_errors=0`

## Ten required structural cases

driver: `C:\tmp\test_evidence_contract_tiering_20260729.ps1`
fixture_location: outside repository temp
exit_code: 0
duration_seconds: 0.651

| case | result | assessment |
|---|---|---|
| read-only query, complete | PASS | lightweight 7/7 |
| read-only missing evidence_sources | PASS | lightweight 6/7; exact missing field |
| builder complete | PASS | full 16/16 |
| builder missing multiple | PASS | full 12/16; four exact missing fields |
| unknown value | PASS | populated |
| not_applicable value | PASS | populated |
| blank or punctuation-only value | PASS | lightweight 6/7; blank does not consume next line; `!!!`, `???`, `，。` are missing |
| task_kind/change_required conflict | PASS | full 16/16 |
| legacy RESULT | PASS | no crash; lightweight 0/7 |
| casing/Markdown/path variation | PASS | lightweight 7/7 |

result: `evidence_contract_tiering_cases=10/10`

## End-to-end VERIFY_BUNDLE fixtures

exit_code: 0
result: `e2e_bundle_cases=2/2`

```text
case=full-case
evidence_block_level: full
evidence_block_field_count: 16/16
evidence_block_warning: false
evidence_block_enforcement: phase_1_warning_only

case=light-case
evidence_block_level: lightweight
evidence_block_field_count: 6/7
evidence_block_missing_fields:
  - evidence_sources
evidence_block_warning: true
evidence_block_enforcement: phase_1_warning_only
fixture_cleanup_confirmed=True
```

## Scope evidence

- Workspace target files changed: exactly 2.
- No repo test file or new governance document created.
- Temp drivers and bundle fixtures cleaned after execution.
- No commit or push performed.

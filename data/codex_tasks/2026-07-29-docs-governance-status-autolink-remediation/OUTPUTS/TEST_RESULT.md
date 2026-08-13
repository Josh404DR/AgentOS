# Test Result

dispatch_id: 2026-07-29-docs-governance-status-autolink-remediation
test_status: PASS_PENDING_INDEPENDENT_VERIFY
tested_at: 2026-07-29 Asia/Taipei

## 1. Snapshot generator execution

test_command: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\AgentOS\scripts\write_governance_status_snapshot.ps1`
exit_code: 0
duration_seconds: 5.109

```text
snapshot_path=E:\AgentOS\docs\GOVERNANCE_STATUS_SNAPSHOT.md
governance_gate=passed
governance_status=operational_review_required
governance_version=1.3.0
governance_hash=0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1
governance_checked_at=2026-07-29T15:24:42.8188695+08:00
task_execution_allowed=true
write_exit_code=0
```

## 2. Snapshot/assertion consistency

test_command: rerun `scripts\assert_governance_ready.ps1`, parse the four stable fields from generated Markdown, and compare exact expected values.
exit_code: 0

```text
assert_governance_ready:
governance_gate=passed
governance_status=operational_review_required
governance_version=1.3.0
governance_hash=0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1
assert_exit_code=0

snapshot_field=governance_status expected=operational_review_required match=True
snapshot_field=governance_gate expected=passed match=True
snapshot_field=governance_version expected=1.3.0 match=True
snapshot_field=governance_hash expected=0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1 match=True
```

The second assertion naturally has a later `governance_checked_at`; stable
status/version/hash/gate fields match the generator’s actual output.

## 3. Encoding integrity by two independent readers

test_command: Node.js `TextDecoder('utf-8', { fatal: true })` over README and ARCHITECTURE.
test_command: .NET strict `UTF8Encoding(false, true).GetString(ReadAllBytes())` over the same files.
exit_code: 0

```text
node_utf8 path=E:/AgentOS/README.md fatal_decode=PASS replacement=0 latin_artifact=0 question_runs=0
node_utf8 path=E:/AgentOS/docs/ARCHITECTURE.md fatal_decode=PASS replacement=0 latin_artifact=0 question_runs=0
dotnet_fatal_utf8 path=E:\AgentOS\README.md status=PASS replacement=0 latin_C2_C3=0 question_runs=0
dotnet_fatal_utf8 path=E:\AgentOS\docs\ARCHITECTURE.md status=PASS replacement=0 latin_C2_C3=0 question_runs=0
```

An earlier exploratory PowerShell mojibake regex was invalid because its
character range was reversed; it produced no usable result and is not counted
as evidence. The two strict decoder checks above are the corrected evidence.

## 4. Content/line evidence

```text
README.md:7 — links AGENTS.md and docs/GOVERNANCE_STATUS_SNAPSHOT.md and says values are not copied.
docs\ARCHITECTURE.md:3 — governance_source: E:\AgentOS\AGENTS.md
docs\ARCHITECTURE.md:8 — links Governance Status Snapshot and says current status is not copied.
docs\GOVERNANCE_STATUS_SNAPSHOT.md:1,9 — generated snapshot exists and reports governance_version 1.3.0.
```

Search found no copied `governance_version`, `1.3.0`, or dated `Updated:`
value in README/ARCHITECTURE; the version occurs only in the generated snapshot.

## 5. Prior verifier evidence

The four archived result attempts contain three completed FAIL verdicts and
one partial_failure FAIL verdict. Current aggregate sibling RESULT is
partial_failure. PASS text in TASK/DISPATCH_PROMPT is response-template text,
not a completed verdict.

## 6. Append-only preservation

Before adding `CORRECTION_NOTE.md`, the original OUTPUTS tree contained 14
files. SHA-256 values were recorded before the write. After the write, all 14
pre-existing paths remain and retain their recorded hashes; the only new path
is `CORRECTION_NOTE.md`. No existing original artifact was modified or deleted.

```text
preexisting_count=14 unchanged_count=14 mismatch_count=0 mismatches=
current_file_count=15 correction_exists=True
```

## Artifacts

- `E:\AgentOS\data\codex_tasks\2026-07-29-docs-governance-status-autolink-remediation\OUTPUTS\SCOPED_DIFF.patch`
- `E:\AgentOS\data\codex_tasks\2026-07-26-docs-governance-status-autolink\OUTPUTS\CORRECTION_NOTE.md`

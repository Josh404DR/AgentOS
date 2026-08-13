# Test Result

task_id: 2026-07-26-agentos-structured-system-audit
executed_at: 2026-07-26T16:48:11+08:00..2026-07-26T16:55:12+08:00
environment: Windows PowerShell / CodexSandboxOffline
overall_status: partial

## Governance handshake and gate

Command:

```powershell
(Get-FileHash -Algorithm SHA256 -LiteralPath 'E:\AgentOS\AGENTS.md').Hash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "E:\AgentOS\scripts\assert_governance_ready.ps1"
```

Exit code: `0`

Output:

```text
governance_gate=passed
governance_status=operational_review_required
governance_version=1.3.0
governance_hash=0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1
governance_checked_at=2026-07-26T16:55:12.9469333+08:00
task_execution_allowed=true
token_cost=0
model_calls=0
operational_drift_count=22
```

Note: scanner output is retained verbatim. The audit separately marks
`review_required` because README contains stale governance facts.

## Full CI smoke

Command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "E:\AgentOS\scripts\agentos_ci_smoke.ps1"
```

Timeout: `180000 ms`

Exit code: `124` from the bounded shell runner

Output:

```text
command timed out after 180343 milliseconds
```

Result: no PASS/FAIL receipt; must not be reported as PASS.

## Targeted PowerShell regression suites

Command pattern:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File <test_path>
```

Execution window: 2026-07-26T16:51:49+08:00..2026-07-26T16:53:34+08:00

### tests\test_governance_tiers.ps1

Exit code: `0`

```text
governance_tiers_status=passed
policy_drift_count=0
operational_drift_count=22
readonly_status_unchanged=true
readonly_noncanonical_policy_fail_closed=true
approve_paths_missing_entry_preserved=true
```

### tests\test_dispatch_resilience.ps1

Exit code: `0`

```text
dispatch_resilience_status=passed
case_count=6
timeout_elapsed_seconds=15
```

### tests\test_queue_failure_containment.ps1

Exit code: `0`

```text
queue_failure_containment_status=passed
claude_to_codex_fallback=true
bounded_attempts_per_route=2
independent_task_continued=true
```

### tests\test_queue_reason_propagation.ps1

Exit code: `0`

```text
queue_reason_propagation_status=passed
dispatcher_failure_contained=true
status=partial_failure
reason=agent_timeout
phase=fake_worker
exit_code=124
queue_status=recovery_pending
tasks_executed=1
contained_failures=0
```

### tests\test_dashboard_ux_contract.ps1

Exit code: `0`

```text
dashboard_ux_contract=PASS
approval_queue_imported=true
approval_queue_rendered=true
unauthenticated_prompt=true
decision_endpoint=true
token_path_guidance=true
restart_guidance=true
reclaim_switch=true
utf8_content_type=true
utf8_body_bytes=true
```

### tests\test_powershell_utf8_bom.ps1

Exit code: `0`

```text
powershell_utf8_bom_regression=PASS
fault_injection_rejected=true
repository_scan_passed=true
```

## Python suites

Commands attempted:

```powershell
python -m pytest -q E:\AgentOS\tests\test_utf8_encoding_boundary.py
python -m pytest -q E:\AgentOS\tests\test_dashboard_security.py
```

Exit code: `103` for each.

Output:

```text
No Python at '"C:\Users\brian\AppData\Local\Microsoft\WindowsApps\PythonSoftwareFoundation.Python.3.11_qbz5n2kfra8p0\python.exe'
```

Bundled Python retry:

```powershell
& 'C:\Users\brian\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' -m pytest -q <two test files>
```

Exit code: `1`

Output:

```text
No module named pytest
```

Compile-only diagnostic:

```powershell
& 'C:\Users\brian\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' -m py_compile <test file>
```

Exit code: `0` for both Python files.

Result: syntax compiles, but tests were not executed; must not be reported as Python test PASS.

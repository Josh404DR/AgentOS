# AgentOS CI Smoke Suite: governance_and_syntax

run_id: ci-smoke-governance_and_syntax-20260807-092056-558
status: WARN
exit_code: 0
timeout_seconds: 60
duration_seconds: 55.998
python_launcher: 

| Check | Status | Exit code | Duration (s) | Detail |
| --- | --- | ---: | ---: | --- |
| suite_bootstrap | PASS | 0 | 0.051 | suite=governance_and_syntax timeout_seconds=60 |
| governance_gate | PASS | 0 | 18.142 | governance_gate=passed<br>governance_status=operational_review_required<br>governance_version=1.3.0<br>governance_hash=0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1<br>governance_checked_at=2026-08-07T09:21:15.6434023+08:00<br>task_execution_allowed=true<br>token_cost=0<br>model_calls=0<br>operational_drift_count=36 |
| powershell_syntax_core | PASS | 0 | 0.527 | parsed=24 |
| gateway_runtime_receipt_reconciliation | WARN | 1 | 0.834 | hermes-main-gateway lock owner is not alive. |
| hermes_autostart_dedupe | PASS | 0 | 9.231 | hermes_autostart_dedupe=clean |
| powershell_utf8_bom | PASS | 0 | 26.521 | powershell_utf8_bom_regression=PASS<br>fault_injection_rejected=true<br>repository_scan_passed=true |

## Fixture paths

- none

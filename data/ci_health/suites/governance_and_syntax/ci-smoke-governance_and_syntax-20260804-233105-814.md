# AgentOS CI Smoke Suite: governance_and_syntax

run_id: ci-smoke-governance_and_syntax-20260804-233105-814
status: WARN
exit_code: 0
timeout_seconds: 60
duration_seconds: 19.971
python_launcher: 

| Check | Status | Exit code | Duration (s) | Detail |
| --- | --- | ---: | ---: | --- |
| suite_bootstrap | PASS | 0 | 0.037 | suite=governance_and_syntax timeout_seconds=60 |
| governance_gate | PASS | 0 | 4.896 | governance_gate=passed<br>governance_status=operational_review_required<br>governance_version=1.3.0<br>governance_hash=0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1<br>governance_checked_at=2026-08-04T23:31:11.9868584+08:00<br>task_execution_allowed=true<br>token_cost=0<br>model_calls=0<br>operational_drift_count=35 |
| powershell_syntax_core | PASS | 0 | 0.126 | parsed=24 |
| gateway_runtime_receipt_reconciliation | WARN | 1 | 5.794 | hermes-main-gateway was not reconciled to running. |
| hermes_autostart_dedupe | WARN | 1 | 1.712 | primary autostart missing: HermesGatewayAutostart<br>primary autostart missing: HermesLiteAutostart |
| powershell_utf8_bom | PASS | 0 | 7.139 | powershell_utf8_bom_regression=PASS<br>fault_injection_rejected=true<br>repository_scan_passed=true |

## Fixture paths

- none

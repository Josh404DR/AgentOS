# AgentOS Dispatch Result

dispatch_id: ci-dispatch-resilience-invalid-verify
route_to: Codex
codex_mode: verify
governance_version: 1.3.0
governance_hash: 0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1
status: partial_failure
models_invoked: true
scripts_executed: true
cleanup_executed: false
dry_run: false
review_dispatch_id: not_created

## Findings

verify_verdict: NEEDS_HUMAN_DECISION

## Caveats

reason=invalid_verify_output phase=codex_verify_validation recovery_status_path=E:\AgentOS\data\codex_tasks\ci-dispatch-resilience-invalid-verify\OUTPUTS\RECOVERY_STATUS.md detail=Verifier returned a verdict without findings or evidence.
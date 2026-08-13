# AgentOS Dispatch Result

dispatch_id: ci-dispatch-resilience-exit7
route_to: Claude
codex_mode: n/a
governance_version: 1.3.0
governance_hash: 0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1
status: partial_failure
models_invoked: true
scripts_executed: true
cleanup_executed: false
dry_run: false
review_dispatch_id: not_created

## Findings

E:\AgentOS\tests\fixtures\fake_agent_exit7.ps1 : fake agent failure
    + CategoryInfo          : NotSpecified: (:) [Write-Error], WriteErrorException
    + FullyQualifiedErrorId : Microsoft.PowerShell.Commands.WriteErrorException,fake_agent_exit7.ps1

## Caveats

reason=agent_exit_7 phase=agent_execution exit_code=7 elapsed_seconds=0
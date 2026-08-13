param([string]$AgentOSRoot = "E:\AgentOS", [string]$OutputDir, [int]$TimeoutSeconds = 0, [int]$InjectHangSeconds = 0, [switch]$SkipModelCliSmoke, [string]$RunId)
& (Join-Path $PSScriptRoot "invoke_ci_smoke_suite.ps1") -SuiteName queue_and_antigravity_dryrun @PSBoundParameters
exit $LASTEXITCODE

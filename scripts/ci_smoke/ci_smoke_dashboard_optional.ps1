param([string]$AgentOSRoot = "E:\AgentOS", [string]$OutputDir, [int]$TimeoutSeconds = 0, [int]$InjectHangSeconds = 0, [switch]$RequireDashboard, [string]$RunId)
& (Join-Path $PSScriptRoot "invoke_ci_smoke_suite.ps1") -SuiteName dashboard_optional @PSBoundParameters
exit $LASTEXITCODE

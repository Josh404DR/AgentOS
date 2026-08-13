param([string]$AgentOSRoot = "E:\AgentOS", [string]$OutputDir, [int]$TimeoutSeconds = 0, [int]$InjectHangSeconds = 0, [string]$RunId)
& (Join-Path $PSScriptRoot "invoke_ci_smoke_suite.ps1") -SuiteName python_suites @PSBoundParameters
exit $LASTEXITCODE

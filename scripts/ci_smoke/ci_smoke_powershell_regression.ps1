[CmdletBinding()]
param(
    [string]$AgentOSRoot = "E:\AgentOS",
    [string]$OutputDir,
    [int]$TimeoutSeconds = 180,
    [int]$InjectHangSeconds = 0,
    [string]$RunId
)

& (Join-Path $PSScriptRoot "invoke_ci_smoke_suite.ps1") -SuiteName powershell_regression @PSBoundParameters
exit $LASTEXITCODE

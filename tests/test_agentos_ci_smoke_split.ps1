[CmdletBinding()]
param([string]$AgentOSRoot = "E:\AgentOS")

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $AgentOSRoot).Path
$outputDir = Join-Path $root "data\codex_tasks\2026-07-26-ci-smoke-stage-split\OUTPUTS\test-artifacts\automated-timeout"

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "scripts\agentos_ci_smoke.ps1") `
    -AgentOSRoot $root `
    -OutputDir $outputDir `
    -SuiteNames governance_and_syntax,dashboard_optional `
    -InjectTimeoutSuite governance_and_syntax `
    -InjectHangSeconds 6
$exitCode = $LASTEXITCODE
if ($exitCode -ne 124) { throw "Expected orchestrator timeout exit 124, got $exitCode" }
$global:LASTEXITCODE = 0

$summary = Get-Content -LiteralPath (Join-Path $outputDir "latest.json") -Raw | ConvertFrom-Json
if ($summary.status -ne "TIMEOUT") { throw "Expected TIMEOUT summary, got $($summary.status)" }
if (-not $summary.run_id) { throw "Orchestrator summary is missing run_id" }
$timedOut = @($summary.suites | Where-Object { $_.suite -eq "governance_and_syntax" -and $_.status -eq "TIMEOUT" })
if ($timedOut.Count -ne 1) { throw "Injected suite did not produce TIMEOUT receipt" }
$continued = @($summary.suites | Where-Object { $_.suite -eq "dashboard_optional" -and $_.status -in @("PASS", "WARN", "FAIL") })
if ($continued.Count -ne 1) { throw "Dashboard suite did not complete after prior suite timeout" }
foreach ($suite in $summary.suites) {
    if (-not $suite.run_id) { throw "Suite summary entry is missing run_id: $($suite.suite)" }
    if (-not (Test-Path -LiteralPath $suite.result_json -PathType Leaf)) {
        throw "Missing JSON receipt for $($suite.suite): $($suite.result_json)"
    }
    $markdown = [IO.Path]::ChangeExtension($suite.result_json, ".md")
    if (-not (Test-Path -LiteralPath $markdown -PathType Leaf)) {
        throw "Missing Markdown receipt for $($suite.suite): $markdown"
    }
    $suiteReceipt = Get-Content -LiteralPath $suite.result_json -Raw | ConvertFrom-Json
    if ($suiteReceipt.run_id -ne $suite.run_id) {
        throw "Suite receipt run_id mismatch: $($suite.suite)"
    }
}

Write-Output "ci_smoke_split_timeout_test=PASS"
Write-Output "orchestrator_summary=$(Join-Path $outputDir 'latest.json')"

[CmdletBinding()]
param(
    [string]$AgentOSRoot = "E:\AgentOS",
    [switch]$RequireDashboard,
    [switch]$RequireHermesRuntimes,
    [switch]$NoDashboard,
    [switch]$SkipModelCliSmoke,
    [string]$OutputDir,
    [ValidateSet("", "governance_and_syntax", "powershell_regression", "python_suites", "queue_and_antigravity_dryrun", "dashboard_optional")]
    [string]$InjectTimeoutSuite = "",
    [int]$InjectHangSeconds = 0,
    [string]$SuiteNames
)

$ErrorActionPreference = "Stop"
$utf8NoBom = [Text.UTF8Encoding]::new($false)
$root = (Resolve-Path -LiteralPath $AgentOSRoot).Path
if (-not $OutputDir) { $OutputDir = Join-Path $root "data\ci_health" }
$suiteOutputDir = Join-Path $OutputDir "suites"
New-Item -ItemType Directory -Force -Path $suiteOutputDir | Out-Null
$startedAt = Get-Date
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss-fff"

$suiteScripts = [ordered]@{
    governance_and_syntax = "ci_smoke_governance_and_syntax.ps1"
    powershell_regression = "ci_smoke_powershell_regression.ps1"
    python_suites = "ci_smoke_python_suites.ps1"
    queue_and_antigravity_dryrun = "ci_smoke_queue_and_antigravity_dryrun.ps1"
}
if (-not $NoDashboard) { $suiteScripts.dashboard_optional = "ci_smoke_dashboard_optional.ps1" }
if ($SuiteNames) {
    $requestedSuites = @($SuiteNames -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $suiteScripts = [ordered]@{}
    $allScripts = @{
        governance_and_syntax = "ci_smoke_governance_and_syntax.ps1"
        powershell_regression = "ci_smoke_powershell_regression.ps1"
        python_suites = "ci_smoke_python_suites.ps1"
        queue_and_antigravity_dryrun = "ci_smoke_queue_and_antigravity_dryrun.ps1"
        dashboard_optional = "ci_smoke_dashboard_optional.ps1"
    }
    foreach ($name in $requestedSuites) {
        if (-not $allScripts.ContainsKey($name)) { throw "Unknown suite name: $name" }
        $suiteScripts[$name] = $allScripts[$name]
    }
}

$suiteResults = [Collections.Generic.List[object]]::new()
foreach ($entry in $suiteScripts.GetEnumerator()) {
    $scriptPath = Join-Path $root "scripts\ci_smoke\$($entry.Value)"
    $suiteRunId = "ci-smoke-$($entry.Key)-$timestamp"
    $arguments = @{
        AgentOSRoot = $root
        OutputDir = $suiteOutputDir
        RunId = $suiteRunId
    }
    if ($entry.Key -eq "queue_and_antigravity_dryrun" -and $SkipModelCliSmoke) { $arguments.SkipModelCliSmoke = $true }
    if ($entry.Key -eq "dashboard_optional" -and $RequireDashboard) { $arguments.RequireDashboard = $true }
    if ($entry.Key -eq "governance_and_syntax" -and $RequireHermesRuntimes) { $arguments.RequireHermesRuntimes = $true }
    if ($InjectTimeoutSuite -eq $entry.Key) {
        $arguments.TimeoutSeconds = 2
        $arguments.InjectHangSeconds = if ($InjectHangSeconds -gt 2) { $InjectHangSeconds } else { 5 }
    }
    $global:LASTEXITCODE = 0
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath @(
        foreach ($pair in $arguments.GetEnumerator()) {
            "-$($pair.Key)"
            if ($pair.Value -isnot [bool]) { "$($pair.Value)" }
        }
    ) 2>&1
    $exitCode = $LASTEXITCODE
    $runJsonPath = Join-Path $suiteOutputDir "$($entry.Key)\$suiteRunId.json"
    if (Test-Path -LiteralPath $runJsonPath) {
        $suiteResult = Get-Content -LiteralPath $runJsonPath -Raw | ConvertFrom-Json
        $suiteResults.Add([ordered]@{
            suite = $entry.Key
            run_id = $suiteResult.run_id
            status = $suiteResult.status
            exit_code = $suiteResult.exit_code
            duration_seconds = $suiteResult.duration_seconds
            check_count = $suiteResult.check_count
            result_json = $runJsonPath
        }) | Out-Null
    } else {
        $suiteResults.Add([ordered]@{
            suite = $entry.Key
            run_id = $suiteRunId
            status = "FAIL"
            exit_code = $exitCode
            duration_seconds = $null
            check_count = 0
            result_json = $null
            detail = ($output -join [Environment]::NewLine)
        }) | Out-Null
    }
}

$endedAt = Get-Date
$timeoutCount = @($suiteResults | Where-Object status -eq "TIMEOUT").Count
$failCount = @($suiteResults | Where-Object status -eq "FAIL").Count
$warnCount = @($suiteResults | Where-Object status -eq "WARN").Count
$status = if ($timeoutCount) { "TIMEOUT" } elseif ($failCount) { "FAIL" } elseif ($warnCount) { "WARN" } else { "PASS" }
$exitCode = if ($timeoutCount) { 124 } elseif ($failCount) { 1 } else { 0 }
$result = [ordered]@{
    run_id = "ci-smoke-$timestamp"
    status = $status
    exit_code = $exitCode
    started_at = $startedAt.ToString("o")
    finished_at = $endedAt.ToString("o")
    duration_seconds = [Math]::Round(($endedAt - $startedAt).TotalSeconds, 3)
    agentos_root = $root
    suite_count = $suiteResults.Count
    fail_count = $failCount
    warn_count = $warnCount
    timeout_count = $timeoutCount
    suites = @($suiteResults)
}
$json = $result | ConvertTo-Json -Depth 8
$runJson = Join-Path $OutputDir "ci-smoke-$timestamp.json"
$runMd = Join-Path $OutputDir "ci-smoke-$timestamp.md"
[IO.File]::WriteAllText($runJson, $json + [Environment]::NewLine, $utf8NoBom)
[IO.File]::WriteAllText((Join-Path $OutputDir "latest.json"), $json + [Environment]::NewLine, $utf8NoBom)
$lines = [Collections.Generic.List[string]]::new()
@(
    "# AgentOS CI Smoke Summary", "", "run_id: $($result.run_id)",
    "status: $status", "exit_code: $exitCode",
    "duration_seconds: $($result.duration_seconds)", "",
    "| Suite | Run ID | Status | Exit Code | Duration (s) | Checks | Receipt |",
    "| --- | --- | --- | ---: | ---: | ---: | --- |"
) | ForEach-Object { $lines.Add($_) | Out-Null }
foreach ($suite in $suiteResults) {
    $lines.Add("| $($suite.suite) | $($suite.run_id) | $($suite.status) | $($suite.exit_code) | $($suite.duration_seconds) | $($suite.check_count) | $($suite.result_json) |") | Out-Null
}
$markdown = ($lines -join [Environment]::NewLine) + [Environment]::NewLine
[IO.File]::WriteAllText($runMd, $markdown, $utf8NoBom)
[IO.File]::WriteAllText((Join-Path $OutputDir "latest.md"), $markdown, $utf8NoBom)
Write-Output "agentos_ci_smoke_status=$status"
Write-Output "fail_count=$failCount"
Write-Output "warn_count=$warnCount"
Write-Output "timeout_count=$timeoutCount"
Write-Output "result_json=$runJson"
Write-Output "result_markdown=$runMd"
exit $exitCode

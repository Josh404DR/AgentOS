Set-StrictMode -Version Latest

$script:Utf8NoBom = [Text.UTF8Encoding]::new($false)

function Write-CiUtf8NoBom {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Text)
    $parent = Split-Path -Parent $Path
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    [IO.File]::WriteAllText($Path, $Text, $script:Utf8NoBom)
}

function Resolve-AgentOSPythonLauncher {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$AgentOSRoot)

    $absoluteRoot = (Resolve-Path -LiteralPath $AgentOSRoot).Path
    $localAppData = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    $candidates = @(
        [ordered]@{ kind = "project_venv"; path = [IO.Path]::GetFullPath((Join-Path $absoluteRoot "dashboard\backend\.venv\Scripts\python.exe")) },
        [ordered]@{ kind = "bundled_runtime"; path = [IO.Path]::GetFullPath((Join-Path $localAppData "hermes\hermes-agent\venv\Scripts\python.exe")) }
    )
    foreach ($pathPython in @(Get-Command python -All -CommandType Application -ErrorAction SilentlyContinue)) {
        $candidates += [ordered]@{
            kind = "system_path"
            path = [IO.Path]::GetFullPath($pathPython.Source)
        }
    }
    $probes = [Collections.Generic.List[object]]::new()
    foreach ($candidate in @($candidates | Group-Object path | ForEach-Object { $_.Group[0] })) {
        if (-not (Test-Path -LiteralPath $candidate.path -PathType Leaf)) {
            $probes.Add([ordered]@{
                kind = $candidate.kind
                path = $candidate.path
                status = "missing"
                exit_code = $null
                raw_output = "file not found"
            }) | Out-Null
            continue
        }
        try {
            $global:LASTEXITCODE = 0
            $probeOutput = & $candidate.path --version 2>&1
            $probeExitCode = $LASTEXITCODE
            $global:LASTEXITCODE = 0
            $rawOutput = (($probeOutput | ForEach-Object { "$_" }) -join [Environment]::NewLine).Trim()
            if ($probeExitCode -eq 0) {
                $resolvedPath = (Resolve-Path -LiteralPath $candidate.path).Path
                $probes.Add([ordered]@{
                    kind = $candidate.kind
                    path = $resolvedPath
                    status = "usable"
                    exit_code = 0
                    raw_output = $rawOutput
                }) | Out-Null
                return [pscustomobject]@{
                    kind = $candidate.kind
                    path = $resolvedPath
                    candidates = @($candidates)
                    probes = @($probes)
                }
            }
            $probes.Add([ordered]@{
                kind = $candidate.kind
                path = $candidate.path
                status = "unusable"
                exit_code = $probeExitCode
                raw_output = $rawOutput
            }) | Out-Null
        } catch {
            $global:LASTEXITCODE = 0
            $probes.Add([ordered]@{
                kind = $candidate.kind
                path = $candidate.path
                status = "unusable"
                exit_code = $null
                raw_output = $_.Exception.Message
            }) | Out-Null
        }
    }
    return [pscustomobject]@{
        kind = "unavailable"
        path = $null
        candidates = @($candidates)
        probes = @($probes)
    }
}

function New-CiSuiteContext {
    param(
        [Parameter(Mandatory)][string]$SuiteName,
        [Parameter(Mandatory)][string]$AgentOSRoot,
        [Parameter(Mandatory)][string]$OutputDir,
        [Parameter(Mandatory)][int]$TimeoutSeconds,
        [Parameter(Mandatory)][string]$RunId
    )
    $suiteDir = Join-Path $OutputDir $SuiteName
    New-Item -ItemType Directory -Force -Path $suiteDir | Out-Null
    [pscustomobject]@{
        SuiteName = $SuiteName
        Root = $AgentOSRoot
        OutputDir = $suiteDir
        TimeoutSeconds = $TimeoutSeconds
        RunId = $RunId
        StartedAt = Get-Date
        Checks = [Collections.Generic.List[object]]::new()
        Fixtures = [Collections.Generic.List[string]]::new()
        PythonLauncher = $null
    }
}

function Add-CiCheck {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet("PASS", "FAIL", "WARN", "TIMEOUT")][string]$Status,
        [string]$Detail = "",
        [string]$Command = "",
        [double]$DurationSeconds = 0,
        [Nullable[int]]$ExitCode
    )
    if ($null -eq $ExitCode) {
        $ExitCode = switch ($Status) {
            "PASS" { 0 }
            "WARN" { 0 }
            "TIMEOUT" { 124 }
            default { 1 }
        }
    }
    $Context.Checks.Add([ordered]@{
        name = $Name
        status = $Status
        exit_code = [int]$ExitCode
        detail = $Detail
        command = $Command
        duration_seconds = [Math]::Round($DurationSeconds, 3)
    }) | Out-Null
}

function Invoke-CiCommand {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Script,
        [string]$Command = "",
        [switch]$WarnOnly
    )
    $started = Get-Date
    try {
        $global:LASTEXITCODE = 0
        $output = & $Script 2>&1
        $exitCode = if ($null -ne $global:LASTEXITCODE) { $global:LASTEXITCODE } else { 0 }
        $text = (($output | ForEach-Object { "$_" }) -join [Environment]::NewLine).Trim()
        if ($exitCode -ne 0) {
            Add-CiCheck $Context $Name $(if ($WarnOnly) { "WARN" } else { "FAIL" }) "exit_code=$exitCode`n$text" $Command ((Get-Date) - $started).TotalSeconds $exitCode
        } else {
            Add-CiCheck $Context $Name "PASS" $text $Command ((Get-Date) - $started).TotalSeconds 0
        }
    } catch {
        Add-CiCheck $Context $Name $(if ($WarnOnly) { "WARN" } else { "FAIL" }) $_.Exception.Message $Command ((Get-Date) - $started).TotalSeconds 1
    } finally {
        $global:LASTEXITCODE = 0
        Write-CiSuiteSummary -Context $Context -Status "RUNNING" | Out-Null
    }
}

function Write-CiSuiteSummary {
    param(
        [Parameter(Mandatory)]$Context,
        [ValidateSet("RUNNING", "PASS", "FAIL", "WARN", "TIMEOUT")][string]$Status
    )
    $now = Get-Date
    $failCount = @($Context.Checks | Where-Object status -eq "FAIL").Count
    $warnCount = @($Context.Checks | Where-Object status -eq "WARN").Count
    $timeoutCount = @($Context.Checks | Where-Object status -eq "TIMEOUT").Count
    if (-not $Status -or $Status -eq "RUNNING") {
        $finalStatus = $Status
    } else {
        $finalStatus = $Status
    }
    $exitCode = switch ($finalStatus) {
        "PASS" { 0 }
        "WARN" { 0 }
        "RUNNING" { $null }
        "TIMEOUT" { 124 }
        default { 1 }
    }
    $result = [ordered]@{
        suite = $Context.SuiteName
        run_id = $Context.RunId
        status = $finalStatus
        exit_code = $exitCode
        timeout_seconds = $Context.TimeoutSeconds
        started_at = $Context.StartedAt.ToString("o")
        finished_at = $now.ToString("o")
        duration_seconds = [Math]::Round(($now - $Context.StartedAt).TotalSeconds, 3)
        agentos_root = $Context.Root
        python_launcher = $Context.PythonLauncher
        fail_count = $failCount
        warn_count = $warnCount
        timeout_count = $timeoutCount
        check_count = $Context.Checks.Count
        created_fixtures = @($Context.Fixtures)
        checks = @($Context.Checks)
    }
    $json = $result | ConvertTo-Json -Depth 10
    $runJson = Join-Path $Context.OutputDir "$($Context.RunId).json"
    $runMd = Join-Path $Context.OutputDir "$($Context.RunId).md"
    Write-CiUtf8NoBom $runJson ($json + [Environment]::NewLine)
    Write-CiUtf8NoBom (Join-Path $Context.OutputDir "latest.json") ($json + [Environment]::NewLine)
    $lines = [Collections.Generic.List[string]]::new()
    $pythonPath = if ($Context.PythonLauncher -and $Context.PythonLauncher.path) { $Context.PythonLauncher.path } else { "" }
    @(
        "# AgentOS CI Smoke Suite: $($Context.SuiteName)", "",
        "run_id: $($Context.RunId)",
        "status: $finalStatus", "exit_code: $exitCode",
        "timeout_seconds: $($Context.TimeoutSeconds)",
        "duration_seconds: $($result.duration_seconds)",
        "python_launcher: $pythonPath", "",
        "| Check | Status | Exit code | Duration (s) | Detail |",
        "| --- | --- | ---: | ---: | --- |"
    ) | ForEach-Object { $lines.Add($_) | Out-Null }
    foreach ($check in $Context.Checks) {
        $detail = ("$($check.detail)" -replace "\|", "/" -replace "`r?`n", "<br>")
        if ($detail.Length -gt 500) { $detail = $detail.Substring(0, 500) + "..." }
        $lines.Add("| $($check.name) | $($check.status) | $($check.exit_code) | $($check.duration_seconds) | $detail |") | Out-Null
    }
    $lines.Add("") | Out-Null
    $lines.Add("## Fixture paths") | Out-Null
    $lines.Add("") | Out-Null
    if ($Context.Fixtures.Count) {
        foreach ($fixturePath in $Context.Fixtures) {
            $lines.Add("- $fixturePath") | Out-Null
        }
    } else {
        $lines.Add("- none") | Out-Null
    }
    $markdown = ($lines -join [Environment]::NewLine) + [Environment]::NewLine
    Write-CiUtf8NoBom $runMd $markdown
    Write-CiUtf8NoBom (Join-Path $Context.OutputDir "latest.md") $markdown
    return [pscustomobject]@{ Result = $result; JsonPath = $runJson; MarkdownPath = $runMd }
}

function Complete-CiSuite {
    param([Parameter(Mandatory)]$Context)
    $status = if (@($Context.Checks | Where-Object status -eq "TIMEOUT").Count) {
        "TIMEOUT"
    } elseif (@($Context.Checks | Where-Object status -eq "FAIL").Count) {
        "FAIL"
    } elseif (@($Context.Checks | Where-Object status -eq "WARN").Count) {
        "WARN"
    } else {
        "PASS"
    }
    Write-CiSuiteSummary $Context $status
}

function Test-CiPowerShellSyntax {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string[]]$RelativePaths)
    $failures = @()
    foreach ($relative in $RelativePaths) {
        $path = Join-Path $Root $relative
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            $failures += "missing: $relative"
            continue
        }
        $errors = $null
        $tokens = $null
        [Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null
        if ($errors.Count) { $failures += "${relative}: " + (($errors | ForEach-Object Message) -join "; ") }
    }
    if ($failures.Count) { throw ($failures -join [Environment]::NewLine) }
    "parsed=$($RelativePaths.Count)"
}

function New-CiTaskFixture {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$DispatchId,
        [Parameter(Mandatory)][string]$WriteScope,
        [string]$SubagentMode = "static_analysis"
    )
    if ($DispatchId -notmatch "^ci-smoke-[a-z0-9][a-z0-9-]*$") {
        throw "CI fixture dispatch ID must use a path-safe ci-smoke-* namespace: $DispatchId"
    }
    $taskDir = Join-Path $Context.Root "data\codex_tasks\$DispatchId"
    if (Test-Path -LiteralPath $taskDir) {
        throw "Refusing to overwrite existing CI fixture or historical evidence: $taskDir"
    }
    New-Item -ItemType Directory -Path $taskDir | Out-Null
    $taskPath = Join-Path $taskDir "TASK.md"
    $hash = (Get-FileHash -LiteralPath (Join-Path $Context.Root "AGENTS.md") -Algorithm SHA256).Hash
    $version = ((Select-String -LiteralPath (Join-Path $Context.Root "AGENTS.md") -Pattern "^governance_version:\s*(.+)$").Matches.Groups[1].Value).Trim()
    $fallbackEvidence = if ($WriteScope -eq "workspace-write fallback") {
        @"
fallback_reason: Claude session limit smoke-test evidence

## Fallback Evidence

Claude Worker is treated as unavailable for this dry-run CI fixture only.
"@
    } else { "" }
    $content = @"
# AgentOS CI Smoke Fixture

dispatch_id: $DispatchId
fixture_namespace: ci-smoke
type: ANTIGRAVITY_CLI_SUBAGENT
assigned_to: Antigravity Subagent
route_to: Antigravity CLI
subagent_mode: $SubagentMode
impact_scope: ci_smoke
task_kind: ci_health_fixture
task_type: Simple
risk_level: low
write_scope: $WriteScope
runtime_eligible: false
requires_josh_approval: true
approval: CI smoke fixture; no live execution
source: ci_health
governance_version: $version
governance_hash: $hash
task_status: ci_fixture
dispatch_status: ci_smoke_only
$fallbackEvidence

## Task

Dry-run fixture only. Do not process as runtime work.
"@
    Write-CiUtf8NoBom $taskPath $content
    $Context.Fixtures.Add($taskPath) | Out-Null
    $taskPath
}

Export-ModuleMember -Function *

[CmdletBinding()]
param(
    [string]$AgentOSRoot = "E:\AgentOS",
    [switch]$RequireDashboard,
    [switch]$NoDashboard,
    [string]$OutputDir
)

$ErrorActionPreference = "Stop"
$Utf8NoBom = [Text.UTF8Encoding]::new($false)
$root = (Resolve-Path -LiteralPath $AgentOSRoot).Path
if (-not $OutputDir) {
    $OutputDir = Join-Path $root "data\ci_health"
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$startedAt = Get-Date
$checks = New-Object System.Collections.Generic.List[object]
$createdFixtures = New-Object System.Collections.Generic.List[string]

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    $parent = Split-Path -Parent $Path
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    [IO.File]::WriteAllText($Path, $Text, $Utf8NoBom)
}

function Add-Check {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][ValidateSet("PASS", "FAIL", "WARN")][string]$Status,
        [string]$Detail = "",
        [string]$Command = ""
    )
    $checks.Add([ordered]@{
        name = $Name
        status = $Status
        detail = $Detail
        command = $Command
    }) | Out-Null
}

function Invoke-CiCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Script,
        [string]$Command = "",
        [switch]$WarnOnly
    )
    try {
        $output = & $Script 2>&1
        $exit = if ($null -ne $global:LASTEXITCODE) { $global:LASTEXITCODE } else { 0 }
        $text = (($output | ForEach-Object { "$_" }) -join [Environment]::NewLine).Trim()
        if ($exit -ne 0) {
            Add-Check -Name $Name -Status $(if ($WarnOnly) { "WARN" } else { "FAIL" }) -Detail "exit_code=$exit`n$text" -Command $Command
        } else {
            Add-Check -Name $Name -Status "PASS" -Detail $text -Command $Command
        }
    } catch {
        Add-Check -Name $Name -Status $(if ($WarnOnly) { "WARN" } else { "FAIL" }) -Detail $_.Exception.Message -Command $Command
    } finally {
        $global:LASTEXITCODE = 0
    }
}

function Test-PowerShellSyntax {
    param([string[]]$RelativePaths)
    $failures = @()
    foreach ($relative in $RelativePaths) {
        $path = Join-Path $root $relative
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            $failures += "missing: $relative"
            continue
        }
        $errors = $null
        $tokens = $null
        [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null
        if ($errors.Count) {
            $failures += "${relative}: " + (($errors | ForEach-Object { $_.Message }) -join "; ")
        }
    }
    if ($failures.Count) {
        throw ($failures -join [Environment]::NewLine)
    }
    "parsed=$($RelativePaths.Count)"
}

function New-CiTask {
    param(
        [Parameter(Mandatory = $true)][string]$DispatchId,
        [Parameter(Mandatory = $true)][string]$WriteScope,
        [string]$SubagentMode = "static_analysis"
    )
    $taskDir = Join-Path $root (Join-Path "data\codex_tasks" $DispatchId)
    New-Item -ItemType Directory -Force -Path $taskDir | Out-Null
    $taskPath = Join-Path $taskDir "TASK.md"
    $governanceHash = (Get-FileHash -LiteralPath (Join-Path $root "AGENTS.md") -Algorithm SHA256).Hash
    $fallbackNote = if ($WriteScope -eq "workspace-write fallback") {
        @"
fallback_reason: Claude session limit smoke-test evidence

## Fallback Evidence

Claude Worker is treated as blocked for this CI fixture only. This fixture is dry-run only and must not be queued as real work.
"@
    } else {
        ""
    }
    $content = @"
# AgentOS CI Smoke Fixture

dispatch_id: $DispatchId
type: ANTIGRAVITY_CLI_SUBAGENT
assigned_to: Antigravity Subagent
worker_alias: pro
route_to: Antigravity CLI
codex_mode: n/a
subagent_mode: $SubagentMode
impact_scope: ci_smoke
task_kind: ci_health_fixture
task_type: Simple
workflow_version: 1.2
risk_level: low
risk_hits: none
complex_hits: none
write_scope: $WriteScope
requires_josh_approval: true
approval: CI smoke fixture; no live execution
source: ci_health
governance_version: 1.2.0
governance_hash: $governanceHash
task_status: ci_fixture
dispatch_status: ci_smoke_only
$fallbackNote
## Task

This fixture exists only for `scripts\agentos_ci_smoke.ps1` dry-run validation.
Do not process it as a real queue task.
"@
    Write-Utf8NoBom -Path $taskPath -Text $content
    $createdFixtures.Add($taskPath) | Out-Null
    return $taskPath
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$latestJson = Join-Path $OutputDir "latest.json"
$latestMd = Join-Path $OutputDir "latest.md"
$runJson = Join-Path $OutputDir "ci-smoke-$timestamp.json"
$runMd = Join-Path $OutputDir "ci-smoke-$timestamp.md"

Invoke-CiCommand -Name "governance_gate" -Command "scripts\assert_governance_ready.ps1" -Script {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "scripts\assert_governance_ready.ps1") -AgentOSRoot $root
}

Invoke-CiCommand -Name "powershell_syntax_core" -Command "PowerShell AST parse core scripts" -Script {
    Test-PowerShellSyntax @(
        "scripts\assert_governance_ready.ps1",
        "scripts\sync_shared_governance.ps1",
        "scripts\dispatch_task_packet.ps1",
        "scripts\task_queue_runner.ps1",
        "scripts\start_task_queue.ps1",
        "scripts\invoke_antigravity_subagent.ps1",
        "scripts\write_escalation.ps1",
        "scripts\workflow_supervisor.ps1",
        "scripts\local_file_task_worker.ps1",
        "scripts\typed_dispatch.ps1",
        "scripts\promote_draft.ps1",
        "scripts\register_hermes_lite_autostart.ps1",
        "scripts\repository_hygiene_check.ps1"
    )
}

Invoke-CiCommand -Name "verify_prompt_fixture" -Command "tests\fixtures\test_verify_prompt_verdict_injection.ps1" -Script {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "tests\fixtures\test_verify_prompt_verdict_injection.ps1")
}

Invoke-CiCommand -Name "classifier_regression" -Command "tests\classify_task_regression.ps1" -Script {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "tests\classify_task_regression.ps1") -AgentOSRoot $root
}

Invoke-CiCommand -Name "queue_starter_validate_only" -Command "scripts\start_task_queue.ps1 -ValidateOnly" -Script {
    $rootTask = Join-Path $root "data\codex_tasks\ci-smoke-queue-root\TASK.md"
    if (-not (Test-Path -LiteralPath $rootTask -PathType Leaf)) {
        $null = New-CiTask -DispatchId "ci-smoke-queue-root" -WriteScope "outputs_only" -SubagentMode "static_analysis"
    }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "scripts\start_task_queue.ps1") -RootDispatchId "ci-smoke-queue-root" -AgentOSRoot $root -ValidateOnly
}

Invoke-CiCommand -Name "queue_starter_path_repair_contract" -Command "Check start_task_queue.ps1 has Path/PATH repair before Start-Process" -Script {
    $starterText = [IO.File]::ReadAllText((Join-Path $root "scripts\start_task_queue.ps1"), [Text.Encoding]::UTF8)
    foreach ($pattern in @("function Repair-ProcessPathEnvironment", "SetEnvironmentVariable(`"PATH`", `$null, `"Process`")", "Repair-ProcessPathEnvironment", "Start-Process")) {
        if ($starterText -notlike "*$pattern*") { throw "missing pattern: $pattern" }
    }
    $callIndex = $starterText.IndexOf("`r`nRepair-ProcessPathEnvironment")
    if ($callIndex -lt 0) { $callIndex = $starterText.IndexOf("`nRepair-ProcessPathEnvironment") }
    $startProcessIndex = $starterText.IndexOf("`r`n`$process = Start-Process")
    if ($startProcessIndex -lt 0) { $startProcessIndex = $starterText.IndexOf("`n`$process = Start-Process") }
    if ($callIndex -lt 0 -or $startProcessIndex -lt 0 -or $callIndex -gt $startProcessIndex) {
        throw "Repair-ProcessPathEnvironment must appear before Start-Process"
    }
    "path_repair_contract=present"
}

$governancePassed = -not (@($checks | Where-Object { $_.name -eq "governance_gate" -and $_.status -eq "FAIL" }).Count)
if ($governancePassed) {
    Invoke-CiCommand -Name "antigravity_outputs_only_dryrun" -Command "scripts\invoke_antigravity_subagent.ps1 -DryRun outputs_only fixture" -Script {
        $taskPath = New-CiTask -DispatchId "ci-smoke-antigravity-outputs-only" -WriteScope "outputs_only" -SubagentMode "static_analysis"
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "scripts\invoke_antigravity_subagent.ps1") -TaskPath $taskPath -WorkerAlias pro -DryRun
    }

    Invoke-CiCommand -Name "antigravity_workspace_fallback_dryrun" -Command "scripts\invoke_antigravity_subagent.ps1 -DryRun workspace-write fallback fixture" -Script {
        $taskPath = New-CiTask -DispatchId "ci-smoke-antigravity-workspace-fallback" -WriteScope "workspace-write fallback" -SubagentMode "test_execution"
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "scripts\invoke_antigravity_subagent.ps1") -TaskPath $taskPath -WorkerAlias pro -DryRun
    }
} else {
    Add-Check -Name "antigravity_outputs_only_dryrun" -Status "WARN" -Detail "skipped because governance_gate failed" -Command "scripts\invoke_antigravity_subagent.ps1 -DryRun outputs_only fixture"
    Add-Check -Name "antigravity_workspace_fallback_dryrun" -Status "WARN" -Detail "skipped because governance_gate failed" -Command "scripts\invoke_antigravity_subagent.ps1 -DryRun workspace-write fallback fixture"
}

Invoke-CiCommand -Name "python_compile_core" -Command "python -m py_compile core Python files" -WarnOnly -Script {
    $files = @(
        "dashboard\backend\main.py",
        "integrations\hermes_plugins\agentos-typed-dispatch\__init__.py",
        "scripts\agentos_health_check_noagent.py",
        "scripts\daily_token_cost_summary_noagent.py"
    ) | ForEach-Object { Join-Path $root $_ }
    $userHomeFromLocalAppData = Split-Path (Split-Path $env:LOCALAPPDATA -Parent) -Parent
    $candidates = @(
        (Join-Path $root "dashboard\backend\.venv\Scripts\python.exe"),
        (Join-Path $userHomeFromLocalAppData ".cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"),
        (Join-Path $env:LOCALAPPDATA "hermes\hermes-agent\venv\Scripts\python.exe")
    )
    $pathPython = Get-Command python -ErrorAction SilentlyContinue
    if ($pathPython) { $candidates += $pathPython.Source.Trim('"') }

    $errors = @()
    foreach ($candidate in @($candidates | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }
        if ($candidate -match '\\WindowsApps\\') { continue }
        try {
            $output = & $candidate -m py_compile @files 2>&1
        } catch {
            $errors += "${candidate}: $($_.Exception.Message)"
            $global:LASTEXITCODE = 0
            continue
        }
        if ($LASTEXITCODE -eq 0) {
            "python=$candidate"
            return
        }
        $errors += "${candidate}: $($output -join ' ')"
        $global:LASTEXITCODE = 0
    }

    if ($errors.Count) { throw ($errors -join [Environment]::NewLine) }
    throw "python not found"
}

if (-not $NoDashboard) {
    Invoke-CiCommand -Name "dashboard_health_endpoint" -Command "GET http://127.0.0.1:8000/api/health" -WarnOnly:(!$RequireDashboard) -Script {
        $response = Invoke-RestMethod -Uri "http://127.0.0.1:8000/api/health" -TimeoutSec 3
        if ($response.status -ne "ok") { throw "unexpected dashboard status: $($response | ConvertTo-Json -Compress)" }
        "status=$($response.status) agentos_root=$($response.agentos_root)"
    }
}

$endedAt = Get-Date
$failCount = @($checks | Where-Object { $_.status -eq "FAIL" }).Count
$warnCount = @($checks | Where-Object { $_.status -eq "WARN" }).Count
$overall = if ($failCount -gt 0) { "FAIL" } elseif ($warnCount -gt 0) { "WARN" } else { "PASS" }
$checkArray = @($checks.ToArray())
$fixtureArray = @($createdFixtures.ToArray())
$result = [ordered]@{
    status = $overall
    started_at = $startedAt.ToString("o")
    finished_at = $endedAt.ToString("o")
    duration_seconds = [Math]::Round(($endedAt - $startedAt).TotalSeconds, 3)
    agentos_root = $root
    models_invoked = $false
    external_services_invoked = $false
    queue_rerun_executed = $false
    baseline_approval_executed = $false
    fail_count = $failCount
    warn_count = $warnCount
    check_count = $checks.Count
    created_fixtures = $fixtureArray
    checks = $checkArray
}

$json = ($result | ConvertTo-Json -Depth 8)
Write-Utf8NoBom -Path $runJson -Text ($json + [Environment]::NewLine)
Write-Utf8NoBom -Path $latestJson -Text ($json + [Environment]::NewLine)

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# AgentOS CI Smoke Result") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("status: $overall") | Out-Null
$lines.Add("started_at: $($result.started_at)") | Out-Null
$lines.Add("finished_at: $($result.finished_at)") | Out-Null
$lines.Add("models_invoked: false") | Out-Null
$lines.Add("external_services_invoked: false") | Out-Null
$lines.Add("queue_rerun_executed: false") | Out-Null
$lines.Add("baseline_approval_executed: false") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("| Check | Status | Detail |") | Out-Null
$lines.Add("| --- | --- | --- |") | Out-Null
foreach ($check in $checks) {
    $detail = ($check.detail -replace '\|', '/' -replace "`r?`n", "<br>")
    if ($detail.Length -gt 500) { $detail = $detail.Substring(0, 500) + "..." }
    $lines.Add("| $($check.name) | $($check.status) | $detail |") | Out-Null
}
Write-Utf8NoBom -Path $runMd -Text (($lines -join [Environment]::NewLine) + [Environment]::NewLine)
Write-Utf8NoBom -Path $latestMd -Text (($lines -join [Environment]::NewLine) + [Environment]::NewLine)

Write-Output "agentos_ci_smoke_status=$overall"
Write-Output "fail_count=$failCount"
Write-Output "warn_count=$warnCount"
Write-Output "result_json=$runJson"
Write-Output "result_markdown=$runMd"

if ($failCount -gt 0) {
    exit 1
}
exit 0

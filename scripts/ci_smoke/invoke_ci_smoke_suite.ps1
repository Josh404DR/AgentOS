[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("governance_and_syntax", "powershell_regression", "python_suites", "queue_and_antigravity_dryrun", "dashboard_optional")]
    [string]$SuiteName,
    [string]$AgentOSRoot = "E:\AgentOS",
    [string]$OutputDir,
    [int]$TimeoutSeconds = 0,
    [switch]$RequireDashboard,
    [switch]$RequireHermesRuntimes,
    [switch]$SkipModelCliSmoke,
    [int]$InjectHangSeconds = 0,
    [switch]$Worker,
    [string]$RunId
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $AgentOSRoot).Path
$modulePath = Join-Path $root "scripts\ci_smoke\AgentOS.CiSmoke.psm1"
Import-Module $modulePath -Force
$config = Get-Content -LiteralPath (Join-Path $root "scripts\ci_smoke\ci_smoke_suites.json") -Raw | ConvertFrom-Json
if ($TimeoutSeconds -le 0) { $TimeoutSeconds = [int]$config.$SuiteName.timeout_seconds }
if (-not $OutputDir) { $OutputDir = Join-Path $root "data\ci_health\suites" }
if (-not $RunId) { $RunId = "ci-smoke-$SuiteName-$(Get-Date -Format 'yyyyMMdd-HHmmss-fff')" }

function Stop-CiProcessTree([int]$ProcessId) {
    # taskkill /T is PID-scoped and terminates descendants without a slow WMI
    # census. Never match or terminate processes by executable name.
    try {
        & taskkill.exe /T /F /PID $ProcessId 2>&1 | Out-Null
    } catch { }
    Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
}

if (-not $Worker) {
    $suiteDir = Join-Path $OutputDir $SuiteName
    New-Item -ItemType Directory -Force -Path $suiteDir | Out-Null
    $stdout = Join-Path $suiteDir "$RunId.stdout.log"
    $stderr = Join-Path $suiteDir "$RunId.stderr.log"
    $arguments = @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $PSCommandPath,
        "-SuiteName", $SuiteName, "-AgentOSRoot", $root, "-OutputDir", $OutputDir,
        "-TimeoutSeconds", "$TimeoutSeconds", "-RunId", $RunId, "-Worker"
    )
    if ($RequireDashboard) { $arguments += "-RequireDashboard" }
    if ($RequireHermesRuntimes) { $arguments += "-RequireHermesRuntimes" }
    if ($SkipModelCliSmoke) { $arguments += "-SkipModelCliSmoke" }
    if ($InjectHangSeconds -gt 0) { $arguments += @("-InjectHangSeconds", "$InjectHangSeconds") }
    # Windows environment keys are case-insensitive, but inherited sandbox
    # environments can contain both Path and PATH. Start-Process rejects that
    # dictionary, so normalize it before creating the isolated suite worker.
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $cleanPath = (@($machinePath, $userPath) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ";"
    $originalPath = [Environment]::GetEnvironmentVariable("Path", "Process")
    try {
        [Environment]::SetEnvironmentVariable("PATH", $null, "Process")
        [Environment]::SetEnvironmentVariable("Path", $cleanPath, "Process")
        $process = Start-Process powershell.exe -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    } finally {
        [Environment]::SetEnvironmentVariable("Path", $originalPath, "Process")
    }
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        Stop-CiProcessTree $process.Id
        $process.WaitForExit()
        $runJsonPath = Join-Path $suiteDir "$RunId.json"
        $partial = $null
        if (Test-Path -LiteralPath $runJsonPath) {
            try {
                $partial = Get-Content -LiteralPath $runJsonPath -Raw | ConvertFrom-Json
            } catch {
                $partial = $null
            }
        }
        $context = New-CiSuiteContext $SuiteName $root $OutputDir $TimeoutSeconds $RunId
        if ($partial) {
            $context.StartedAt = [datetime]$partial.started_at
            $context.PythonLauncher = $partial.python_launcher
            foreach ($check in @($partial.checks)) { $context.Checks.Add($check) | Out-Null }
            foreach ($fixture in @($partial.created_fixtures)) { $context.Fixtures.Add("$fixture") | Out-Null }
        }
        Add-CiCheck $context "suite_timeout" "TIMEOUT" "Suite exceeded bounded timeout of $TimeoutSeconds seconds; completed check receipts were preserved and the worker process tree was terminated." $PSCommandPath $TimeoutSeconds 124
        $receipt = Write-CiSuiteSummary $context "TIMEOUT"
        Write-Output "ci_smoke_suite=$SuiteName"
        Write-Output "ci_smoke_suite_status=TIMEOUT"
        Write-Output "result_json=$($receipt.JsonPath)"
        Write-Output "result_markdown=$($receipt.MarkdownPath)"
        exit 124
    }
    $process.WaitForExit()
    $runJsonPath = Join-Path $suiteDir "$RunId.json"
    if (Test-Path -LiteralPath $runJsonPath) {
        $result = Get-Content -LiteralPath $runJsonPath -Raw | ConvertFrom-Json
        Write-Output "ci_smoke_suite=$SuiteName"
        Write-Output "ci_smoke_suite_status=$($result.status)"
        Write-Output "result_json=$runJsonPath"
        Write-Output "result_markdown=$([IO.Path]::ChangeExtension($runJsonPath, '.md'))"
        exit [int]$result.exit_code
    } else {
        $context = New-CiSuiteContext $SuiteName $root $OutputDir $TimeoutSeconds $RunId
        $stderrText = if (Test-Path -LiteralPath $stderr) {
            (Get-Content -LiteralPath $stderr -Raw).Trim()
        } else {
            ""
        }
        Add-CiCheck $context "suite_worker_receipt" "FAIL" "Suite worker exited without summary; stderr=$stderrText" $PSCommandPath 0 $process.ExitCode
        $receipt = Write-CiSuiteSummary $context "FAIL"
        Write-Output "ci_smoke_suite=$SuiteName"
        Write-Output "ci_smoke_suite_status=FAIL"
        Write-Output "result_json=$($receipt.JsonPath)"
        Write-Output "result_markdown=$($receipt.MarkdownPath)"
    }
    exit 1
}

$context = New-CiSuiteContext $SuiteName $root $OutputDir $TimeoutSeconds $RunId
Write-CiSuiteSummary $context "RUNNING" | Out-Null

function Invoke-PowerShellTest([string]$Name, [string]$RelativePath, [switch]$WarnOnly) {
    Invoke-CiCommand $context $Name {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root $RelativePath) -AgentOSRoot $root
    } $RelativePath -WarnOnly:$WarnOnly
}

function Invoke-Python([string]$Name, [string[]]$Arguments, [switch]$WarnOnly) {
    $started = Get-Date
    $launcher = [string]$context.PythonLauncher.path
    $command = "$launcher $($Arguments -join ' ')".Trim()
    if ([string]::IsNullOrWhiteSpace($launcher)) {
        Add-CiCheck $context $Name $(if ($WarnOnly) { "WARN" } else { "FAIL" }) `
            "launcher=<unavailable>; exit_code=1; raw_error=No usable Python launcher found." `
            $command ((Get-Date) - $started).TotalSeconds 1
        Write-CiSuiteSummary $context "RUNNING" | Out-Null
        return
    }

    $oldPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $global:LASTEXITCODE = 0
        $output = & $launcher @Arguments 2>&1
        $code = [int]$LASTEXITCODE
        $rawOutput = (($output | ForEach-Object { "$_" }) -join [Environment]::NewLine).Trim()
        $status = if ($code -eq 0) { "PASS" } elseif ($WarnOnly) { "WARN" } else { "FAIL" }
        $rawError = if ($code -eq 0) { "" } else { $rawOutput }
        $detail = "launcher=$launcher; exit_code=$code; raw_error=$rawError"
        if ($code -eq 0 -and $rawOutput) { $detail += "; output=$rawOutput" }
        Add-CiCheck $context $Name $status $detail $command ((Get-Date) - $started).TotalSeconds $code
    } catch {
        $code = if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { [int]$LASTEXITCODE } else { 1 }
        Add-CiCheck $context $Name $(if ($WarnOnly) { "WARN" } else { "FAIL" }) `
            "launcher=$launcher; exit_code=$code; raw_error=$($_.Exception.Message)" `
            $command ((Get-Date) - $started).TotalSeconds $code
    } finally {
        $ErrorActionPreference = $oldPreference
        $global:LASTEXITCODE = 0
        Write-CiSuiteSummary $context "RUNNING" | Out-Null
    }
}

Invoke-CiCommand $context "suite_bootstrap" { "suite=$SuiteName timeout_seconds=$TimeoutSeconds" } "suite bootstrap"
if ($InjectHangSeconds -gt 0) {
    Invoke-CiCommand $context "injected_child_hang" {
        & powershell.exe -NoProfile -Command "Start-Sleep -Seconds $InjectHangSeconds"
    } "child powershell: Start-Sleep -Seconds $InjectHangSeconds"
}

switch ($SuiteName) {
    "governance_and_syntax" {
        Invoke-CiCommand $context "governance_gate" {
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "scripts\assert_governance_ready.ps1") -AgentOSRoot $root
        } "scripts\assert_governance_ready.ps1"
        Invoke-CiCommand $context "powershell_syntax_core" {
            Test-CiPowerShellSyntax $root @(
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
                "scripts\model_cli_health_smoke.ps1",
                "scripts\retry_pending_knowledge_sync.ps1",
                "scripts\publish_url_knowledge.ps1",
                "scripts\url_knowledge_security.ps1",
                "scripts\decide_escalation.ps1",
                "scripts\escalation_receipt_validation.ps1",
                "scripts\set_workflow_control.ps1",
                "scripts\agentos_ci_smoke.ps1",
                "scripts\ci_smoke\invoke_ci_smoke_suite.ps1",
                "scripts\start.ps1",
                "scripts\start_hermes_lite.ps1",
                "scripts\observability\collect-runtime-status.ps1",
                "scripts\observability\write-gateway-runtime-receipt.ps1",
                "scripts\observability\test-runtime-receipt-reconciliation.ps1"
            )
        } "PowerShell AST parse core scripts"
        $gatewayProfileLocks = @(
            (Join-Path $env:LOCALAPPDATA "hermes\gateway.lock"),
            (Join-Path $env:LOCALAPPDATA "hermes-lite\gateway.lock")
        )
        if (@($gatewayProfileLocks | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Leaf) }).Count -eq 0) {
            Invoke-CiCommand $context "gateway_runtime_receipt_reconciliation" {
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
                    (Join-Path $root "scripts\observability\test-runtime-receipt-reconciliation.ps1") `
                    -AgentOSRoot $root
            } "scripts\observability\test-runtime-receipt-reconciliation.ps1" -WarnOnly:(-not $RequireHermesRuntimes)
        } else {
            Add-CiCheck $context "gateway_runtime_receipt_reconciliation" `
                $(if ($RequireHermesRuntimes) { "FAIL" } else { "WARN" }) `
                "Main/Lite profile locks are unavailable; live receipt reconciliation was not tested." `
                "scripts\observability\test-runtime-receipt-reconciliation.ps1"
            Write-CiSuiteSummary $context "RUNNING" | Out-Null
        }
        Invoke-CiCommand $context "hermes_autostart_dedupe" {
            $registryJson = Get-Content -LiteralPath (Join-Path $root "config\runtime_registry.json") -Raw | ConvertFrom-Json
            $failures = @()
            foreach ($runtimeEntry in $registryJson.runtimes) {
                if (-not $runtimeEntry.enabled) { continue }
                if ([string]$runtimeEntry.runtime_id -notlike "hermes-*") { continue }
                if ([string]$runtimeEntry.start_source.type -ne "scheduled_task") { continue }
                $primaryName = [string]$runtimeEntry.start_source.ref
                $primaryTask = Get-ScheduledTask -TaskName $primaryName -ErrorAction SilentlyContinue
                if (-not $primaryTask) {
                    $failures += "primary autostart missing: $primaryName"
                } elseif ("$($primaryTask.State)" -eq "Disabled") {
                    $failures += "primary autostart disabled: $primaryName"
                }
                foreach ($relatedName in @($runtimeEntry.related_scheduled_tasks)) {
                    if ([string]::IsNullOrWhiteSpace([string]$relatedName)) { continue }
                    $relatedTask = Get-ScheduledTask -TaskName ([string]$relatedName) -ErrorAction SilentlyContinue
                    if ($relatedTask -and "$($relatedTask.State)" -ne "Disabled") {
                        $failures += "duplicate autostart enabled: $relatedName (must stay disabled; primary=$primaryName)"
                    }
                }
            }
            if ($failures.Count) { throw ($failures -join [Environment]::NewLine) }
            "hermes_autostart_dedupe=clean"
        } "Get-ScheduledTask census vs runtime_registry related_scheduled_tasks" -WarnOnly:(-not $RequireHermesRuntimes)
        Invoke-PowerShellTest "powershell_utf8_bom" "tests\test_powershell_utf8_bom.ps1"
    }
    "powershell_regression" {
        $regressionTestsBeforeFixture = @(
            [ordered]@{ name = "dashboard_orphan_guard"; path = "tests\test_dashboard_orphan_guard.ps1" },
            [ordered]@{ name = "dashboard_ux_contract"; path = "tests\test_dashboard_ux_contract.ps1" }
        )
        foreach ($test in $regressionTestsBeforeFixture) {
            Invoke-PowerShellTest $test.name $test.path
        }
        Invoke-CiCommand $context "verify_prompt_fixture" {
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "data\tasks\fixtures\test_verify_prompt_verdict_injection.ps1")
        } "data\tasks\fixtures\test_verify_prompt_verdict_injection.ps1"
        $regressionTestsAfterFixture = @(
            [ordered]@{ name = "classifier_regression"; path = "tests\classify_task_regression.ps1" },
            [ordered]@{ name = "learning_governance_dedupe"; path = "tests\learning_collector\test_governance_dedupe.ps1" },
            [ordered]@{ name = "queue_reason_propagation"; path = "tests\test_queue_reason_propagation.ps1" },
            [ordered]@{ name = "queue_failure_containment"; path = "tests\test_queue_failure_containment.ps1" },
            [ordered]@{ name = "dispatch_resilience"; path = "tests\test_dispatch_resilience.ps1" },
            [ordered]@{ name = "escalation_decision_hardening"; path = "tests\test_escalation_decision_hardening.ps1" },
            [ordered]@{ name = "hermes_root_queue_e2e"; path = "tests\test_hermes_root_queue_e2e.ps1" },
            [ordered]@{ name = "url_knowledge_security"; path = "tests\test_url_knowledge_security.ps1" }
        )
        foreach ($test in $regressionTestsAfterFixture) {
            Invoke-PowerShellTest $test.name $test.path
        }
        Invoke-CiCommand $context "knowledge_sync_retry_dryrun" {
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "scripts\retry_pending_knowledge_sync.ps1") -AgentOSRoot $root -DryRun
        } "scripts\retry_pending_knowledge_sync.ps1 -DryRun"
    }
    "python_suites" {
        $context.PythonLauncher = Resolve-AgentOSPythonLauncher $root
        Invoke-CiCommand $context "python_launcher" {
            $probeDetail = $context.PythonLauncher.probes | ConvertTo-Json -Compress -Depth 5
            if (-not $context.PythonLauncher.path) { throw "No Python launcher available; probes=$probeDetail" }
            "kind=$($context.PythonLauncher.kind) path=$($context.PythonLauncher.path) probes=$probeDetail"
        } "Resolve-AgentOSPythonLauncher"
        Invoke-Python "url_knowledge_intake" @(
            "-m", "unittest",
            (Join-Path $root "tests\test_url_knowledge_intake.py"),
            (Join-Path $root "tests\test_knowledge_relations.py")
        )
        Invoke-Python "dashboard_security" @("-m", "unittest", (Join-Path $root "tests\test_dashboard_security.py"))
        Invoke-Python "knowledge_workspace" @("-m", "unittest", (Join-Path $root "tests\test_knowledge_workspace.py"))
        Invoke-Python "utf8_encoding_boundary" @((Join-Path $root "tests\test_utf8_encoding_boundary.py"))
        Invoke-Python "pytest_dependency" @("-m", "pytest", "--version")
        $compileFiles = @(
            "dashboard\backend\main.py",
            "dashboard\backend\dashboard_security.py",
            "integrations\hermes_plugins\agentos-typed-dispatch\__init__.py",
            "scripts\agentos_health_check_noagent.py",
            "scripts\daily_token_cost_summary_noagent.py",
            "scripts\fetch_url_source.py",
            "scripts\analyze_knowledge_relations.py"
        ) | ForEach-Object { Join-Path $root $_ }
        Invoke-Python "python_compile_core" (@("-m", "py_compile") + $compileFiles) -WarnOnly
    }
    "queue_and_antigravity_dryrun" {
        $fixturePrefix = "ci-smoke-$([guid]::NewGuid().ToString('N'))"
        Invoke-CiCommand $context "queue_starter_validate_only" {
            $queueDispatchId = "$fixturePrefix-queue-root"
            $taskPath = New-CiTaskFixture $context $queueDispatchId "outputs_only"
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "scripts\start_task_queue.ps1") -RootDispatchId $queueDispatchId -AgentOSRoot $root -ValidateOnly
        } "scripts\start_task_queue.ps1 -ValidateOnly"
        Invoke-CiCommand $context "queue_starter_path_repair_contract" {
            $text = [IO.File]::ReadAllText((Join-Path $root "scripts\start_task_queue.ps1"), [Text.Encoding]::UTF8)
            foreach ($pattern in @("function Repair-ProcessPathEnvironment", "Repair-ProcessPathEnvironment", "Start-Process")) {
                if ($text -notlike "*$pattern*") { throw "missing pattern: $pattern" }
            }
            "path_repair_contract=present"
        } "static path repair contract"
        Invoke-CiCommand $context "antigravity_outputs_only_dryrun" {
            $taskPath = New-CiTaskFixture $context "$fixturePrefix-antigravity-outputs-only" "outputs_only"
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "scripts\invoke_antigravity_subagent.ps1") -TaskPath $taskPath -WorkerAlias pro -DryRun
        } "scripts\invoke_antigravity_subagent.ps1 -DryRun outputs_only"
        Invoke-CiCommand $context "antigravity_workspace_fallback_dryrun" {
            $taskPath = New-CiTaskFixture $context "$fixturePrefix-antigravity-workspace-fallback" "workspace-write fallback" "test_execution"
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "scripts\invoke_antigravity_subagent.ps1") -TaskPath $taskPath -WorkerAlias pro -DryRun
        } "scripts\invoke_antigravity_subagent.ps1 -DryRun fallback"
        if ($SkipModelCliSmoke) {
            Add-CiCheck $context "model_cli_live_smoke" "WARN" "explicitly skipped; model availability not verified" "scripts\model_cli_health_smoke.ps1"
            Write-CiSuiteSummary $context "RUNNING" | Out-Null
        } else {
            Invoke-CiCommand $context "model_cli_live_smoke" {
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "scripts\model_cli_health_smoke.ps1") -AgentOSRoot $root
            } "scripts\model_cli_health_smoke.ps1"
        }
    }
    "dashboard_optional" {
        $context.PythonLauncher = Resolve-AgentOSPythonLauncher $root
        Invoke-CiCommand $context "python_launcher_resolution" {
            $probeDetail = $context.PythonLauncher.probes | ConvertTo-Json -Compress -Depth 5
            if (-not $context.PythonLauncher.path) {
                throw "No Python launcher available; probes=$probeDetail"
            }
            "kind=$($context.PythonLauncher.kind) path=$($context.PythonLauncher.path) probes=$probeDetail"
        } "Resolve-AgentOSPythonLauncher"
        Invoke-Python "ci_fixture_namespace" @(
            "-m", "unittest", (Join-Path $root "tests\test_ci_fixture_namespace.py")
        )
        Invoke-CiCommand $context "dashboard_health_endpoint" {
            $response = Invoke-RestMethod -Uri "http://127.0.0.1:8000/api/health" -TimeoutSec 3
            if ($response.status -ne "ok") { throw "unexpected dashboard status: $($response | ConvertTo-Json -Compress)" }
            "status=$($response.status) agentos_root=$($response.agentos_root)"
        } "GET http://127.0.0.1:8000/api/health" -WarnOnly:(-not $RequireDashboard)
    }
}

$receipt = Complete-CiSuite $context
Write-Output "ci_smoke_suite=$SuiteName"
Write-Output "ci_smoke_suite_status=$($receipt.Result.status)"
Write-Output "result_json=$($receipt.JsonPath)"
Write-Output "result_markdown=$($receipt.MarkdownPath)"
if ($receipt.Result.status -eq "FAIL") { exit 1 }
if ($receipt.Result.status -eq "TIMEOUT") { exit 124 }
exit 0

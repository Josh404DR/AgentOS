param(
    [Parameter(Mandatory = $true)]
    [string]$TaskPath,

    [Parameter(Mandatory = $true)]
    [ValidateSet("free-a", "free-b", "free-c", "pro")]
    [string]$WorkerAlias,

    [ValidateRange(1, 30)]
    [int]$TimeoutMinutes = 10,

    [string]$AgentOSRoot,

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$AgentOSRoot = if ([string]::IsNullOrWhiteSpace($AgentOSRoot)) {
    Split-Path $PSScriptRoot -Parent
} else {
    $AgentOSRoot
}
$AgentOSRoot = (Resolve-Path -LiteralPath $AgentOSRoot).Path
$ConfigPath = Join-Path $AgentOSRoot "config\antigravity_subagents.json"
$RolePath = Join-Path $AgentOSRoot "integrations\antigravity\AGENTOS_ROLE.md"
$GatePath = Join-Path $AgentOSRoot "scripts\assert_governance_ready.ps1"

foreach ($requiredPath in @($ConfigPath, $RolePath, $GatePath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required file not found: $requiredPath"
    }
}

$gateOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $GatePath -AgentOSRoot $AgentOSRoot 2>&1
if (-not ($gateOutput -match "governance_status=aligned")) {
    throw "Governance status is not aligned. Execution blocked."
}

$resolvedTask = (Resolve-Path -LiteralPath $TaskPath -ErrorAction Stop).Path
$taskRoot = Join-Path $AgentOSRoot "data\codex_tasks\"
if (-not $resolvedTask.StartsWith($taskRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "TaskPath must be inside $taskRoot"
}
if ((Split-Path $resolvedTask -Leaf) -ne "TASK.md") {
    throw "TaskPath filename must be TASK.md"
}

$taskText = Get-Content -LiteralPath $resolvedTask -Raw -Encoding UTF8
if ($taskText -notmatch "(?im)^assigned_to:\s*Antigravity Subagent\s*$") {
    throw "TASK.md must contain assigned_to: Antigravity Subagent"
}
if ($taskText -notmatch "(?im)^write_scope:\s*([^\r\n]+)$") {
    throw "TASK.md is missing write_scope"
}
$writeScope = $Matches[1].Trim().ToLowerInvariant()
if ($writeScope -notin @("outputs_only", "workspace-write fallback")) {
    throw "TASK.md write_scope must be outputs_only or workspace-write fallback"
}
if ($taskText -notmatch "(?im)^risk_level:\s*([^\r\n]+)$") {
    throw "TASK.md is missing risk_level"
}
$riskLevel = $Matches[1].Trim().ToLowerInvariant()
if ($riskLevel -ne "low") {
    throw "Antigravity fallback only allows risk_level low; actual=$riskLevel"
}
if ($taskText -notmatch "(?im)^subagent_mode:\s*([^\r\n]+)$") {
    throw "TASK.md is missing subagent_mode"
}
$subagentMode = $Matches[1].Trim().ToLowerInvariant()

if ($writeScope -eq "workspace-write fallback") {
    if ($taskText -notmatch "(?im)^approval:\s*\S+") {
        throw "workspace-write fallback requires approval evidence in TASK.md"
    }
    $hasFallbackEvidence = $taskText -match "(?i)(fallback_reason|session limit|quota|service unavailable|service-unavailable|Claude.*blocked|Claude.*unavailable|Claude.*額度|Claude.*限制)"
    if (-not $hasFallbackEvidence) {
        throw "workspace-write fallback requires Claude quota/session/service-unavailable evidence in TASK.md"
    }
}

$config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$worker = @($config.workers | Where-Object { $_.alias -eq $WorkerAlias })
if ($worker.Count -ne 1) {
    throw "Worker alias is missing or duplicated in configuration: $WorkerAlias"
}
$worker = $worker[0]
if (-not $worker.enabled -and -not $DryRun) {
    throw "Worker '$WorkerAlias' is disabled. Complete Windows account and CLI authentication first."
}
if ($worker.allowed_risk_levels -notcontains $riskLevel) {
    throw "Worker '$WorkerAlias' does not allow risk_level '$riskLevel'."
}
if ($worker.allowed_modes -notcontains $subagentMode) {
    throw "Worker '$WorkerAlias' does not allow subagent_mode '$subagentMode'."
}

$currentWindowsUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name.Split("\")[-1]
if (-not $DryRun -and $currentWindowsUser -ne $worker.windows_user) {
    throw "Worker '$WorkerAlias' must run as Windows user '$($worker.windows_user)', current user is '$currentWindowsUser'."
}

$outputDir = Join-Path (Split-Path $resolvedTask -Parent) "OUTPUTS"
if (-not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$writeInstruction = if ($writeScope -eq "workspace-write fallback") {
    @"
You are running in workspace-write fallback mode because Claude Worker is blocked.
You may modify only files explicitly named in TASK.md.
You must preserve unrelated workspace changes.
You must not approve baseline, delete evidence, commit, push, deploy, change credentials, create schedules, or act as final verifier.
"@
} else {
    @"
You may write only inside: $outputDir
Do not modify any other file.
"@
}

$prompt = @"
Read and obey:
1. $AgentOSRoot\AGENTS.md
2. $AgentOSRoot\integrations\antigravity\AGENTOS_ROLE.md
3. $AgentOSRoot\prompts\role_headers\claude_worker.md
4. $resolvedTask

You are worker alias '$WorkerAlias'.
Execute only the latest task and Revision sections.
$writeInstruction
Write RESULT.md, SCOPED_DIFF.patch, and TEST_RESULT.md in Traditional Chinese.
Existing OUTPUTS are not proof of completion.
"@

$dryRunReceipt = [ordered]@{
    worker_alias = $WorkerAlias
    windows_user = $worker.windows_user
    task_path = $resolvedTask
    risk_level = $riskLevel
    subagent_mode = $subagentMode
    write_scope = $writeScope
    dry_run = [bool]$DryRun
    checked_at = (Get-Date).ToString("o")
}

if ($DryRun) {
    $dryRunReceipt | ConvertTo-Json -Depth 5
    exit 0
}

$agyPath = Join-Path $env:LOCALAPPDATA "agy\bin\agy.exe"
if (-not (Test-Path -LiteralPath $agyPath -PathType Leaf)) {
    throw "Antigravity CLI not installed for Windows user '$currentWindowsUser': $agyPath"
}

$lockPath = Join-Path $outputDir "ANTIGRAVITY_RUN.lock"
$lockStream = $null
try {
    $lockStream = [IO.File]::Open($lockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $lockStream.SetLength(0)
    $lockBody = [Text.Encoding]::UTF8.GetBytes(($dryRunReceipt | ConvertTo-Json -Depth 5))
    $lockStream.Write($lockBody, 0, $lockBody.Length)
    $lockStream.Flush()

    $cliOutput = & $agyPath --sandbox --print-timeout "$($TimeoutMinutes)m" --print $prompt 2>&1
    $cliExitCode = $LASTEXITCODE
    $stdoutPath = Join-Path $outputDir "ANTIGRAVITY_CLI_STDOUT.md"
    [IO.File]::WriteAllText($stdoutPath, ($cliOutput -join [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))

    if ($cliExitCode -ne 0) {
        throw "Antigravity CLI failed with exit code $cliExitCode. See $stdoutPath"
    }

    foreach ($artifactName in @("RESULT.md", "SCOPED_DIFF.patch", "TEST_RESULT.md")) {
        $artifactPath = Join-Path $outputDir $artifactName
        if (-not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
            throw "Required artifact missing after execution: $artifactPath"
        }
    }
} finally {
    if ($null -ne $lockStream) {
        $lockStream.Dispose()
    }
}

Write-Output "antigravity_subagent_status=completed"
Write-Output "worker_alias=$WorkerAlias"
Write-Output "task_path=$resolvedTask"
Write-Output "output_dir=$outputDir"

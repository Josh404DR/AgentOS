[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("free-a", "free-b", "free-c", "pro")]
    [string]$WorkerAlias,

    [string]$AgentOSRoot = "E:\AgentOS",
    [switch]$Once,
    [int]$PollSeconds = 300,
    [int]$MaxTasksPerRun = 5,
    [ValidateRange(1, 30)]
    [int]$TimeoutMinutes = 10,
    [switch]$DryRun
)

# poll_antigravity_worker.ps1
#
# Per-account satellite poller for the Antigravity CLI Subagent worker pool.
# This script has zero AI decision-making authority: it deterministically scans
# data\codex_tasks\*\TASK.md for tasks already routed to "Antigravity CLI" and
# resolved (by the same matching rule dispatch_task_packet.ps1 uses) to THIS
# worker's own alias, then calls the already-governed
# scripts\invoke_antigravity_subagent.ps1 for each match.
#
# Intended use: registered as a per-Windows-account scheduled task, "Run only
# when user is logged on", under the SAME Windows account that owns this
# worker alias (see config\antigravity_subagents.json). It refuses to run
# under any other account.
#
# This script is not on the governed-file list (scripts\sync_shared_governance.ps1)
# and does not modify AGENTS.md, current_state.md, or any governed script.
# It only ever invokes invoke_antigravity_subagent.ps1, which itself enforces
# write_scope: outputs_only.

$ErrorActionPreference = "Stop"
$Utf8NoBom = [Text.UTF8Encoding]::new($false)
$TasksRoot = Join-Path $AgentOSRoot "data\codex_tasks"
$ConfigPath = Join-Path $AgentOSRoot "config\antigravity_subagents.json"
$InvokeScript = Join-Path $AgentOSRoot "scripts\invoke_antigravity_subagent.ps1"
$GatePath = Join-Path $AgentOSRoot "scripts\assert_governance_ready.ps1"
$LogPath = Join-Path $AgentOSRoot "logs\antigravity_poll_$WorkerAlias.log"

foreach ($requiredPath in @($ConfigPath, $InvokeScript, $GatePath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required file not found: $requiredPath"
    }
}

function Write-Log([string]$Message) {
    $line = "$(Get-Date -Format o) worker=$WorkerAlias $Message"
    $parent = Split-Path -Parent $LogPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
    Write-Output $line
}

function Get-Field([string]$Text, [string]$Name) {
    $match = [regex]::Match(
        $Text,
        "(?mi)^\s*" + [regex]::Escape($Name) + "\s*:\s*(.+?)\s*$"
    )
    if ($match.Success) { return $match.Groups[1].Value.Trim().Trim('"').Trim("'") }
    return ""
}

function Resolve-TargetAlias([string]$TaskText, $Config) {
    $explicit = Get-Field $TaskText "worker_alias"
    if ($explicit) { return $explicit }
    $mode = Get-Field $TaskText "subagent_mode"
    $risk = Get-Field $TaskText "risk_level"
    $matched = @($Config.workers | Where-Object {
        $_.enabled -and
        $_.allowed_modes -contains $mode -and
        $_.allowed_risk_levels -contains $risk
    } | Select-Object -First 1)
    if ($matched.Count -eq 1) { return $matched[0].alias }
    return $null
}

# Hard safety check: this poller may only ever act as its own worker's Windows account.
$currentWindowsUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name.Split("\")[-1]
$configForSelf = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$selfWorker = @($configForSelf.workers | Where-Object { $_.alias -eq $WorkerAlias })
if ($selfWorker.Count -ne 1) {
    throw "Worker alias '$WorkerAlias' is missing or duplicated in $ConfigPath"
}
$selfWorker = $selfWorker[0]
if ($currentWindowsUser -ne $selfWorker.windows_user) {
    throw "poll_antigravity_worker.ps1 for '$WorkerAlias' must run as Windows user '$($selfWorker.windows_user)'; current user is '$currentWindowsUser'."
}
if (-not $selfWorker.enabled) {
    throw "Worker '$WorkerAlias' is disabled in $ConfigPath. Enable it before polling."
}

function Invoke-PollOnce {
    if (-not (Test-Path -LiteralPath $TasksRoot)) {
        Write-Log "skip_cycle reason=no_tasks_root"
        return
    }

    $gateOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $GatePath -AgentOSRoot $AgentOSRoot 2>&1
    if ($LASTEXITCODE -ne 0 -or -not ($gateOutput -match "task_execution_allowed=true")) {
        Write-Log "skip_cycle reason=governance_gate_denied"
        return
    }

    $config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $processed = 0

    $taskDirs = Get-ChildItem -LiteralPath $TasksRoot -Directory
    foreach ($dir in $taskDirs) {
        if ($processed -ge $MaxTasksPerRun) { break }

        $taskPath = Join-Path $dir.FullName "TASK.md"
        if (-not (Test-Path -LiteralPath $taskPath -PathType Leaf)) { continue }

        $text = [IO.File]::ReadAllText($taskPath, [Text.Encoding]::UTF8)
        $route = Get-Field $text "route_to"
        if ($route -ne "Antigravity CLI") { continue }

        $status = Get-Field $text "dispatch_status"
        if ($status -ne "ready_to_route") { continue }

        $assignedTo = Get-Field $text "assigned_to"
        if ($assignedTo -notmatch "Antigravity Subagent") { continue }

        $resultPath = Join-Path $dir.FullName "OUTPUTS\RESULT.md"
        if (Test-Path -LiteralPath $resultPath -PathType Leaf) { continue }

        $lockPath = Join-Path $dir.FullName "OUTPUTS\ANTIGRAVITY_RUN.lock"
        if (Test-Path -LiteralPath $lockPath -PathType Leaf) {
            Write-Log "skip_task id=$($dir.Name) reason=already_locked"
            continue
        }

        $targetAlias = Resolve-TargetAlias $text $config
        if ($targetAlias -ne $WorkerAlias) { continue }

        Write-Log "dispatching id=$($dir.Name)"
        try {
            $invokeArgs = @{
                TaskPath       = $taskPath
                WorkerAlias    = $WorkerAlias
                TimeoutMinutes = $TimeoutMinutes
            }
            if ($DryRun) { $invokeArgs["DryRun"] = $true }
            $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $InvokeScript @invokeArgs 2>&1
            Write-Log "result id=$($dir.Name) exit=$LASTEXITCODE output=$($output -join ' | ')"
        } catch {
            Write-Log "error id=$($dir.Name) message=$($_.Exception.Message)"
        }
        $processed++
    }

    Write-Log "cycle_complete processed=$processed"
}

if ($Once) {
    Invoke-PollOnce
} else {
    while ($true) {
        Invoke-PollOnce
        Start-Sleep -Seconds $PollSeconds
    }
}

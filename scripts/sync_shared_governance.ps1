[CmdletBinding()]
param(
    [switch]$ApproveBaseline,
    [string[]]$ApprovePaths = @(),
    [switch]$ReadOnly,
    [string]$AgentOSRoot = "E:\AgentOS"
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $AgentOSRoot).Path
$canonical = Join-Path $root "AGENTS.md"
$statusDir = Join-Path $root "data\governance"
$baselinePath = Join-Path $statusDir "governance_baseline.json"
$statusPath = Join-Path $statusDir "governance_status.json"

$policyGoverned = @(
    "AGENTS.md",
    "CLAUDE.md",
    "agents\roles\claude.md",
    "agents\roles\codex.md",
    "agents\roles\hermes.md",
    "docs\governance\EVIDENCE_AND_REPORTING_CONTRACT.md",
    "docs\governance\COST_SAVING_ROUTING_PROTOCOL.md",
    "docs\governance\RISK_RULES.md",
    "docs\governance\WORKFLOW_V1_2_CONTRACT.md",
    "scripts\assert_governance_ready.ps1",
    "scripts\sync_shared_governance.ps1"
)

$operationalMonitored = @(
    "current_state.md",
    "docs\ARCHITECTURE.md",
    "prompts\context_packs\hermes_system_prompt_v2.txt",
    "prompts\context_packs\hermes_system_prompt_v2.md",
    "prompts\response_templates\verification_result_zh_tw.md",
    "scripts\typed_dispatch.ps1",
    "scripts\local_file_task_worker.ps1",
    "scripts\url_intake_task_packet.ps1",
    "scripts\url_intake_worker.ps1",
    "scripts\threads_url_intake.ps1",
    "scripts\dispatch_task_packet.ps1",
    "scripts\task_queue_runner.ps1",
    "scripts\start_task_queue.ps1",
    "scripts\start_hermes_lite.ps1",
    "scripts\classify_task.ps1",
    "scripts\write_escalation.ps1",
    "scripts\write_task_metric.ps1",
    "scripts\hermes_claude_bridge.ps1",
    "scripts\hermes_codex_bridge.ps1",
    "scripts\hermes_tripartite_bridge.ps1",
    "scripts\free_model_window.ps1",
    "scripts\publish_url_knowledge.ps1",
    "integrations\hermes_plugins\agentos-typed-dispatch\__init__.py",
    "dashboard\backend\main.py",
    "dashboard\frontend\app\page.tsx",
    "dashboard\frontend\app\globals.css",
    "dashboard\frontend\components\DecisionMap.tsx",
    "dashboard\frontend\components\GovernanceStatus.tsx",
    "dashboard\frontend\components\TaskUniverse.tsx",
    "dashboard\frontend\lib\api.ts"
)

function Get-RelativeFiles([string]$Directory, [string[]]$Extensions, [string]$ExcludePattern = "") {
    $full = Join-Path $root $Directory
    if (-not (Test-Path -LiteralPath $full -PathType Container)) { return @() }
    return @(Get-ChildItem -LiteralPath $full -Recurse -File |
        Where-Object {
            $_.Extension -in $Extensions -and
            (-not $ExcludePattern -or $_.FullName -notmatch $ExcludePattern)
        } |
        ForEach-Object { $_.FullName.Substring($root.Length + 1) })
}

$promptFiles = Get-RelativeFiles "prompts" @(".md", ".txt")
$dashboardFiles = Get-RelativeFiles "dashboard" @(".py", ".ts", ".tsx", ".css", ".md", ".ps1") '\\node_modules\\|\\\.next\\|\\\.venv\\|\\__pycache__\\|\\next-env\.d\.ts$'
$claudeOpsFiles = Get-RelativeFiles "docs\claude_ops" @(".md")

$policyGoverned = @($policyGoverned | Sort-Object -Unique)
$operationalMonitored = @($operationalMonitored + $promptFiles + $dashboardFiles + $claudeOpsFiles |
    Where-Object { $_ -notin $policyGoverned } | Sort-Object -Unique)
$allTracked = @($policyGoverned + $operationalMonitored | Sort-Object -Unique)

<# legacy dynamic enumeration replaced by Get-RelativeFiles
$promptFiles = Get-ChildItem -LiteralPath (Join-Path $root "prompts") -Recurse -File |
    Where-Object { $_.Extension -in @(".md", ".txt") } |
    ForEach-Object { $_.FullName.Substring($root.Length + 1) }
$dashboardFiles = Get-ChildItem -LiteralPath (Join-Path $root "dashboard") -Recurse -File |
    Where-Object {
        $_.Extension -in @(".py", ".ts", ".tsx", ".css", ".md", ".ps1") -and
        $_.FullName -notmatch '\\node_modules\\|\\\.next\\|\\\.venv\\|\\__pycache__\\' -and
        $_.Name -ne "next-env.d.ts"
    } |
    ForEach-Object { $_.FullName.Substring($root.Length + 1) }
$claudeOpsFiles = Get-ChildItem -LiteralPath (Join-Path $root "docs\claude_ops") -Recurse -File |
    Where-Object { $_.Extension -in @(".md") } |
    ForEach-Object { $_.FullName.Substring($root.Length + 1) }
$governed = @($governed + $promptFiles + $dashboardFiles + $claudeOpsFiles | Sort-Object -Unique)
#>

if (-not (Test-Path -LiteralPath $canonical -PathType Leaf)) {
    throw "Canonical governance file missing: $canonical"
}

if ($ReadOnly) {
    if ($ApproveBaseline -or $ApprovePaths.Count) {
        throw "ReadOnly cannot be combined with baseline approval."
    }
    if (-not (Test-Path -LiteralPath $statusDir -PathType Container)) {
        throw "Governance status directory is missing for read-only scan: $statusDir"
    }
} else {
    New-Item -ItemType Directory -Path $statusDir -Force | Out-Null
}

function Get-Entry([string]$relativePath, [string]$class) {
    $fullPath = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        return [ordered]@{ path = $relativePath; class = $class; exists = $false; sha256 = $null }
    }
    return [ordered]@{
        path = $relativePath
        class = $class
        exists = $true
        sha256 = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash
    }
}

$entries = @(
    $policyGoverned | ForEach-Object { Get-Entry $_ "policy" }
    $operationalMonitored | ForEach-Object { Get-Entry $_ "operational" }
)
$versionMatch = [regex]::Match(
    [IO.File]::ReadAllText($canonical, [Text.Encoding]::UTF8),
    '(?m)^governance_version:\s*(\S+)'
)
$version = if ($versionMatch.Success) { $versionMatch.Groups[1].Value } else { "unknown" }

if ($ApproveBaseline -and $ApprovePaths.Count) {
    throw "Use either -ApproveBaseline or -ApprovePaths, not both."
}

if ($ApproveBaseline) {
    $baseline = [ordered]@{
        governance_version = $version
        approved_at = (Get-Date).ToString("o")
        approved_by = "Josh-authorized Codex governance task"
        files = $entries
    }
    [IO.File]::WriteAllText(
        $baselinePath,
        ($baseline | ConvertTo-Json -Depth 6),
        (New-Object Text.UTF8Encoding($false))
    )
}

$baselineData = if (Test-Path -LiteralPath $baselinePath) {
    Get-Content -Raw -LiteralPath $baselinePath -Encoding UTF8 | ConvertFrom-Json
} else {
    $null
}

if ($ApprovePaths.Count) {
    if (-not $baselineData) { throw "Baseline is missing; explicit -ApproveBaseline is required once." }
    $normalized = @($ApprovePaths | ForEach-Object { $_ -split ',' } |
        ForEach-Object { ($_ -replace '/', '\').Trim().TrimStart('.','\') } |
        Where-Object { $_ } | Sort-Object -Unique)
    $unknown = @($normalized | Where-Object { $_ -notin $allTracked })
    if ($unknown.Count) { throw "ApprovePaths contains untracked governance paths: $($unknown -join ', ')" }
    $updated = [Collections.Generic.List[object]]::new()
    foreach ($old in @($baselineData.files)) {
        $current = @($entries | Where-Object { $_.path -eq $old.path } | Select-Object -First 1)
        if ($old.path -in $normalized -and $current.Count) { $updated.Add($current[0]) }
        else { $updated.Add($old) }
    }
    foreach ($path in $normalized) {
        if (-not @($updated | Where-Object { $_.path -eq $path }).Count) {
            $current = @($entries | Where-Object { $_.path -eq $path } | Select-Object -First 1)
            if ($current.Count) { $updated.Add($current[0]) }
        }
    }
    $baseline = [ordered]@{
        governance_version = $version
        approved_at = (Get-Date).ToString("o")
        approved_by = "Josh-authorized scoped governance update"
        approved_paths = $normalized
        files = @($updated)
    }
    [IO.File]::WriteAllText($baselinePath, ($baseline | ConvertTo-Json -Depth 7), (New-Object Text.UTF8Encoding($false)))
    $baselineData = $baseline | ConvertTo-Json -Depth 7 | ConvertFrom-Json
}

$policyDrift = @()
$operationalDrift = @()
foreach ($entry in $entries) {
    $expected = if ($baselineData) {
        $baselineData.files | Where-Object { $_.path -eq $entry.path } | Select-Object -First 1
    } else {
        $null
    }
    if (-not $entry.exists) {
        $item = [ordered]@{ path = $entry.path; class = $entry.class; reason = "missing" }
        if ($entry.class -eq "policy") { $policyDrift += $item } else { $operationalDrift += $item }
    } elseif (-not $expected) {
        $item = [ordered]@{ path = $entry.path; class = $entry.class; reason = "not_in_baseline" }
        if ($entry.class -eq "policy") { $policyDrift += $item } else { $operationalDrift += $item }
    } elseif ($entry.sha256 -ne $expected.sha256) {
        $item = [ordered]@{ path = $entry.path; class = $entry.class; reason = "hash_changed" }
        if ($entry.class -eq "policy") { $policyDrift += $item } else { $operationalDrift += $item }
    }
}

$status = [ordered]@{
    governance_status = if (-not $baselineData -or $policyDrift.Count) { "review_required" } elseif ($operationalDrift.Count) { "operational_review_required" } else { "aligned" }
    governance_version = $version
    canonical_path = $canonical
    canonical_hash = ($entries | Where-Object path -eq "AGENTS.md").sha256
    checked_at = (Get-Date).ToString("o")
    token_cost = 0
    model_calls = 0
    deletion_executed = $false
    governed_file_count = $policyGoverned.Count
    monitored_file_count = $operationalMonitored.Count
    drift_count = $policyDrift.Count
    operational_drift_count = $operationalDrift.Count
    drift = $policyDrift
    operational_drift = $operationalDrift
}
if (-not $ReadOnly) {
    [IO.File]::WriteAllText(
        $statusPath,
        ($status | ConvertTo-Json -Depth 6),
        (New-Object Text.UTF8Encoding($false))
    )
}

Write-Output "governance_status=$($status.governance_status)"
Write-Output "governance_version=$version"
Write-Output "canonical_hash=$($status.canonical_hash)"
Write-Output "drift_count=$($policyDrift.Count)"
Write-Output "operational_drift_count=$($operationalDrift.Count)"
Write-Output "status_path=$statusPath"
Write-Output "scan_mode=$(if ($ReadOnly) { 'read_only' } else { 'write_status' })"
Write-Output "token_cost=0"
Write-Output "model_calls=0"

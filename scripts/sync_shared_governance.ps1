[CmdletBinding()]
param(
    [switch]$ApproveBaseline,
    [string]$AgentOSRoot = "E:\AgentOS"
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $AgentOSRoot).Path
$canonical = Join-Path $root "AGENTS.md"
$statusDir = Join-Path $root "data\governance"
$baselinePath = Join-Path $statusDir "governance_baseline.json"
$statusPath = Join-Path $statusDir "governance_status.json"

$governed = @(
    "AGENTS.md",
    "CLAUDE.md",
    "current_state.md",
    "agents\roles\claude.md",
    "agents\roles\codex.md",
    "agents\roles\hermes.md",
    "docs\ARCHITECTURE.md",
    "docs\EVIDENCE_AND_REPORTING_CONTRACT.md",
    "docs\COST_SAVING_ROUTING_PROTOCOL.md",
    "docs\governance\RISK_RULES.md",
    "docs\governance\WORKFLOW_V1_2_CONTRACT.md",
    "prompts\context_packs\hermes_system_prompt_v2.txt",
    "prompts\context_packs\hermes_system_prompt_v2.md",
    "prompts\response_templates\verification_result_zh_tw.md",
    "scripts\assert_governance_ready.ps1",
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
    "dashboard\frontend\lib\api.ts",
    "scripts\sync_shared_governance.ps1"
)

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

if (-not (Test-Path -LiteralPath $canonical -PathType Leaf)) {
    throw "Canonical governance file missing: $canonical"
}

New-Item -ItemType Directory -Path $statusDir -Force | Out-Null

function Get-Entry([string]$relativePath) {
    $fullPath = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        return [ordered]@{ path = $relativePath; exists = $false; sha256 = $null }
    }
    return [ordered]@{
        path = $relativePath
        exists = $true
        sha256 = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash
    }
}

$entries = @($governed | ForEach-Object { Get-Entry $_ })
$versionMatch = [regex]::Match(
    [IO.File]::ReadAllText($canonical, [Text.Encoding]::UTF8),
    '(?m)^governance_version:\s*(\S+)'
)
$version = if ($versionMatch.Success) { $versionMatch.Groups[1].Value } else { "unknown" }

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

$drift = @()
foreach ($entry in $entries) {
    $expected = if ($baselineData) {
        $baselineData.files | Where-Object { $_.path -eq $entry.path } | Select-Object -First 1
    } else {
        $null
    }
    if (-not $entry.exists) {
        $drift += [ordered]@{ path = $entry.path; reason = "missing" }
    } elseif (-not $expected) {
        $drift += [ordered]@{ path = $entry.path; reason = "not_in_baseline" }
    } elseif ($entry.sha256 -ne $expected.sha256) {
        $drift += [ordered]@{ path = $entry.path; reason = "hash_changed" }
    }
}

$status = [ordered]@{
    governance_status = if (-not $baselineData) { "review_required" } elseif ($drift.Count) { "review_required" } else { "aligned" }
    governance_version = $version
    canonical_path = $canonical
    canonical_hash = ($entries | Where-Object path -eq "AGENTS.md").sha256
    checked_at = (Get-Date).ToString("o")
    token_cost = 0
    model_calls = 0
    deletion_executed = $false
    governed_file_count = $entries.Count
    drift_count = $drift.Count
    drift = $drift
}
[IO.File]::WriteAllText(
    $statusPath,
    ($status | ConvertTo-Json -Depth 6),
    (New-Object Text.UTF8Encoding($false))
)

Write-Output "governance_status=$($status.governance_status)"
Write-Output "governance_version=$version"
Write-Output "canonical_hash=$($status.canonical_hash)"
Write-Output "drift_count=$($drift.Count)"
Write-Output "status_path=$statusPath"
Write-Output "token_cost=0"
Write-Output "model_calls=0"

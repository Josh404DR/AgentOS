[CmdletBinding()]
param([string]$AgentOSRoot = "E:\AgentOS")

$ErrorActionPreference = "Stop"
$utf8NoBom = [Text.UTF8Encoding]::new($false)
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) "AgentOS-queue-index-$PID-$([guid]::NewGuid().ToString('N'))"
$resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
$resolvedFixture = [IO.Path]::GetFullPath($fixtureRoot)
if (-not $resolvedFixture.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase)) {
    throw "unsafe fixture path: $resolvedFixture"
}

try {
    New-Item -ItemType Directory -Force -Path (Join-Path $fixtureRoot "scripts") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $fixtureRoot "data\codex_tasks\fixture-root\OUTPUTS") | Out-Null
    Copy-Item -LiteralPath (Join-Path $AgentOSRoot "scripts\task_queue_runner.ps1") `
        -Destination (Join-Path $fixtureRoot "scripts\task_queue_runner.ps1")
    Copy-Item -LiteralPath (Join-Path $AgentOSRoot "scripts\rebuild_active_task_index.ps1") `
        -Destination (Join-Path $fixtureRoot "scripts\rebuild_active_task_index.ps1")
    Copy-Item -LiteralPath (Join-Path $AgentOSRoot "scripts\escalation_receipt_validation.ps1") `
        -Destination (Join-Path $fixtureRoot "scripts\escalation_receipt_validation.ps1")
    $task = @"
dispatch_id: fixture-root
parent_dispatch_id: none
dependency_order: 0
depends_on: none
type: ROOT
route_to: Hermes
task_status: created
dispatch_status: created
governance_version: 1.3.0
governance_hash: fixture
"@
    [IO.File]::WriteAllText(
        (Join-Path $fixtureRoot "data\codex_tasks\fixture-root\TASK.md"),
        $task,
        $utf8NoBom
    )

    $runner = Join-Path $fixtureRoot "scripts\task_queue_runner.ps1"
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner `
        -AgentOSRoot $fixtureRoot -RootDispatchId "fixture-root" -ValidateOnly 2>&1
    if ($LASTEXITCODE -ne 0) { throw "ValidateOnly failed: $($output -join "`n")" }
    $text = $output -join "`n"
    $queueLog = [IO.File]::ReadAllText((Join-Path $fixtureRoot "logs\task-queue.log"), [Text.Encoding]::UTF8)
    if ($queueLog -notmatch 'status=index_rebuild_triggered detail=reason=index_missing mode=full') {
        throw "missing-index rebuild event not found: $queueLog"
    }
    if ($text -notmatch 'status=queue_scan detail=scan_ms=[0-9.]+ directory_count=1 scoped_task_count=1') {
        throw "queue scan metrics not found: $text"
    }
    if (-not (Test-Path -LiteralPath (Join-Path $fixtureRoot "data\queue_runs\ACTIVE_TASK_INDEX.json") -PathType Leaf)) {
        throw "index was not created"
    }
    Write-Output "queue_active_index_status=passed"
    Write-Output "missing_index_rebuild_logged=true"
    Write-Output "scan_metrics_logged=true"
} finally {
    if (Test-Path -LiteralPath $fixtureRoot -PathType Container) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
    Write-Output "fixture_cleanup_path=$fixtureRoot"
    Write-Output "fixture_cleanup_confirmed=$(-not (Test-Path -LiteralPath $fixtureRoot))"
}

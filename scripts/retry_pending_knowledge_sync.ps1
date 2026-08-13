[CmdletBinding()]
param(
    [string]$AgentOSRoot = "E:\AgentOS",
    [string]$PythonPath = "C:\Users\brian\AppData\Local\Programs\Python\Python310\python.exe",
    [ValidateRange(1, 20)][int]$MaxItems = 3,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$utf8 = [Text.UTF8Encoding]::new($false)
$root = (Resolve-Path -LiteralPath $AgentOSRoot).Path
$gate = Join-Path $root "scripts\assert_governance_ready.ps1"
$gateOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $gate -AgentOSRoot $root
if ($LASTEXITCODE -ne 0 -or -not ($gateOutput -match "task_execution_allowed=true")) {
    throw "Governance gate denied knowledge sync retry."
}
$queueDir = Join-Path $root "data\knowledge_sync_queue"
$syncScript = Join-Path $root "scripts\sync_notebooklm.py"
$logDir = Join-Path $root "data\memory\sync_logs\knowledge_nodes"
if (-not (Test-Path -LiteralPath $queueDir -PathType Container)) {
    Write-Output "knowledge_sync_retry_status=no_pending_queue"
    exit 0
}

$processed = 0
$uploaded = 0
$deferred = 0
$entries = Get-ChildItem -LiteralPath $queueDir -Filter "*.json" -File |
    Sort-Object LastWriteTime |
    Select-Object -First $MaxItems
foreach ($file in $entries) {
    try { $entry = Get-Content -Raw -LiteralPath $file.FullName -Encoding UTF8 | ConvertFrom-Json }
    catch { Write-Output "queue_item=$($file.Name)|status=invalid_json"; continue }
    if ($entry.status -ne "pending_retry") { continue }
    $processed++
    $nodePath = [string]$entry.node_path
    $exportDir = [string]$entry.export_dir
    if (-not $nodePath.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -or
        -not $exportDir.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -or
        -not (Test-Path -LiteralPath $nodePath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $exportDir -PathType Container)) {
        Write-Output "queue_item=$($file.Name)|status=invalid_scope"
        continue
    }
    if ($DryRun) {
        Write-Output "queue_item=$($file.Name)|status=would_retry"
        continue
    }
    $started = Get-Date
    & $PythonPath $syncScript `
        "--export-dir" $exportDir `
        "--notebook-id" ([string]$entry.notebook_id) `
        "--log-dir" $logDir `
        "--title-mode" "relpath-hash"
    $syncExit = $LASTEXITCODE
    $latestLog = Get-ChildItem -LiteralPath $logDir -Filter "notebooklm_sync_*.md" -File |
        Where-Object LastWriteTime -ge $started.AddSeconds(-2) |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    $logText = if ($latestLog) { Get-Content -Raw -LiteralPath $latestLog.FullName -Encoding UTF8 } else { "" }
    $entry.attempts = [int]$entry.attempts + 1
    $entry.last_attempt_at = (Get-Date -Format o)
    $entry.sync_log_path = if ($latestLog) { $latestLog.FullName } else { "not_available" }
    if ($syncExit -eq 0 -and $logText -match '\*\*Final Status\*\*:\s*`live_sync_success`') {
        $node = [IO.File]::ReadAllText($nodePath, [Text.Encoding]::UTF8).Replace(
            "- notebooklm_sync_status: pending_retry", "- notebooklm_sync_status: uploaded"
        )
        [IO.File]::WriteAllText($nodePath, $node, $utf8)
        $entry.status = "uploaded"
        $entry.last_error = ""
        $uploaded++
        Write-Output "queue_item=$($file.Name)|status=uploaded"
    } else {
        $entry.status = "pending_retry"
        $entry.last_error = "notebooklm_auth_or_connection_failure"
        $deferred++
        Write-Output "queue_item=$($file.Name)|status=deferred"
    }
    [IO.File]::WriteAllText(
        $file.FullName,
        ($entry | ConvertTo-Json -Depth 6) + [Environment]::NewLine,
        $utf8
    )
}

Write-Output "knowledge_sync_retry_status=completed"
Write-Output "processed=$processed"
Write-Output "uploaded=$uploaded"
Write-Output "deferred=$deferred"

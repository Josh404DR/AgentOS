[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RootDispatchId,
    [Parameter(Mandatory = $true)]
    [ValidateSet("pause", "resume", "retry")][string]$Action,
    [string]$AgentOSRoot = "E:\AgentOS"
)

$ErrorActionPreference = "Stop"
$Utf8NoBom = [Text.UTF8Encoding]::new($false)
$safeId = [regex]::Replace($RootDispatchId, '[^A-Za-z0-9_.-]+', '-').Trim('-')
$taskPath = Join-Path $AgentOSRoot "data\codex_tasks\$safeId\TASK.md"
if (-not (Test-Path -LiteralPath $taskPath -PathType Leaf)) {
    throw "Root task not found: $taskPath"
}
$dir = Join-Path $AgentOSRoot "data\workflow_control\$safeId"
$controlPath = Join-Path $dir "CONTROL.json"
$eventsPath = Join-Path $AgentOSRoot "data\workflow_control\CONTROL_EVENTS.jsonl"
New-Item -ItemType Directory -Path $dir -Force | Out-Null
$state = switch ($Action) {
    "pause" { "pause_requested" }
    "resume" { "running" }
    "retry" { "running" }
}
$payload = [ordered]@{
    root_dispatch_id = $safeId
    state = $state
    retry_requested = $Action -eq "retry"
    retry_mode = if ($Action -eq "retry") { "unfinished_steps_only" } else { "none" }
    updated_at = (Get-Date).ToString("o")
    updated_by = "Josh_dashboard_control"
}
[IO.File]::WriteAllText($controlPath, ($payload | ConvertTo-Json -Depth 5), $Utf8NoBom)
$event = [ordered]@{
    root_dispatch_id = $safeId
    action = $Action
    state = $state
    created_at = $payload.updated_at
    actor = "Josh"
}
Add-Content -LiteralPath $eventsPath -Value ($event | ConvertTo-Json -Compress) -Encoding UTF8
Write-Output "workflow_control_status=updated"
Write-Output "root_dispatch_id=$safeId"
Write-Output "action=$Action"
Write-Output "state=$state"
Write-Output "control_path=$controlPath"

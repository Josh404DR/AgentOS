[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$TaskId,
    [Parameter(Mandatory = $true)]
    [ValidateSet("approve", "modify", "stop")][string]$Decision,
    [string]$Note = "",
    [string]$AgentOSRoot = "E:\AgentOS"
)

$ErrorActionPreference = "Stop"
$Utf8NoBom = [Text.UTF8Encoding]::new($false)
$safeId = [regex]::Replace($TaskId, '[^A-Za-z0-9_.-]+', '-').Trim('-')
$dir = Join-Path $AgentOSRoot "data\escalations\$safeId"
if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
    throw "Escalation not found: $safeId"
}
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss-fff"
$decisionPath = Join-Path $dir "DECISION-$timestamp.json"
$resolutionPath = Join-Path $dir "RESOLUTION.json"
$payload = [ordered]@{
    task_id = $safeId
    decision = $Decision
    note = $Note
    decided_by = "Josh"
    decided_at = (Get-Date).ToString("o")
}
[IO.File]::WriteAllText($decisionPath, ($payload | ConvertTo-Json -Depth 5), $Utf8NoBom)
$resolution = [ordered]@{
    task_id = $safeId
    resolution_type = "josh_decision"
    decision = $Decision
    resolved_at = $payload.decided_at
    resolved_by = "Josh"
    summary = if ($Note) { $Note } else { "Josh selected $Decision in Dashboard." }
    evidence = @($decisionPath)
    josh_action_required = $false
    recommended_status = if ($Decision -eq "stop") { "stopped" } else { "resolved" }
}
[IO.File]::WriteAllText($resolutionPath, ($resolution | ConvertTo-Json -Depth 5), $Utf8NoBom)
Write-Output "escalation_decision_status=recorded"
Write-Output "task_id=$safeId"
Write-Output "decision=$Decision"
Write-Output "decision_path=$decisionPath"
Write-Output "resolution_path=$resolutionPath"

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$TaskId,
    [Parameter(Mandatory = $true)][string]$TaskType,
    [string]$Worker = "Claude",
    [string]$Verifier = "Codex",
    [Parameter(Mandatory = $true)][string]$Verdict,
    [int]$RetryCount = 0,
    [string]$FailReason = "",
    [bool]$EscalationRequired = $false,
    [string]$TokenActual = "unknown",
    [string]$DurationActual = "unknown",
    [Parameter(Mandatory = $true)][string]$FinalStatus,
    [string]$AgentOSRoot = "E:\AgentOS"
)

$ErrorActionPreference = "Stop"
$utf8 = [Text.UTF8Encoding]::new($false)
$dir = Join-Path $AgentOSRoot "data\metrics"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$path = Join-Path $dir "METRICS_LOG.jsonl"
if (Test-Path -LiteralPath $path) {
    foreach ($line in Get-Content -LiteralPath $path -Encoding UTF8) {
        if (-not $line.Trim()) { continue }
        try {
            $existing = $line | ConvertFrom-Json
            if ($existing.task_id -eq $TaskId -and
                $existing.verdict -eq $Verdict -and
                [int]$existing.retry_count -eq $RetryCount -and
                $existing.final_status -eq $FinalStatus) {
                Write-Output "metrics_status=already_recorded"
                Write-Output "metrics_path=$path"
                exit 0
            }
        } catch {
            continue
        }
    }
}
$entry = [ordered]@{
    task_id = $TaskId
    task_type = $TaskType
    worker = $Worker
    verifier = $Verifier
    verdict = $Verdict
    retry_count = $RetryCount
    fail_reason = $FailReason
    escalation_required = $EscalationRequired
    token_actual = $TokenActual
    duration_actual = $DurationActual
    final_status = $FinalStatus
    recorded_at = (Get-Date -Format o)
}
[IO.File]::AppendAllText(
    $path,
    (($entry | ConvertTo-Json -Compress) + [Environment]::NewLine),
    $utf8
)
Write-Output "metrics_status=recorded"
Write-Output "metrics_path=$path"

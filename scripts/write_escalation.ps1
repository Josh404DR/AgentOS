[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$TaskId,
    [Parameter(Mandatory = $true)]
    [ValidateSet("simple_fail","complex_fail","risky_task","classification_unclear","verify_needs_human","raw_intake","raw_intake_approval")]
    [string]$Source,
    [Parameter(Mandatory = $true)][string]$Reason,
    [Parameter(Mandatory = $true)]
    [ValidateSet("approve_risky_action","clarify_requirement","accept_partial_delivery","stop_task","retry_with_changes","raw_intake","raw_intake_approval")]
    [string]$DecisionType,
    [Parameter(Mandatory = $true)][string]$SummaryForJosh,
    [string[]]$Evidence = @(),
    [string]$AgentOSRoot = "E:\AgentOS"
)

$ErrorActionPreference = "Stop"
$utf8 = [Text.UTF8Encoding]::new($false)
$safeId = [regex]::Replace($TaskId, '[^A-Za-z0-9_.-]+', '-')
$root = Join-Path $AgentOSRoot "data\escalations"
$taskDir = Join-Path $root $safeId
New-Item -ItemType Directory -Force -Path $taskDir | Out-Null
$createdAt = Get-Date -Format o
$stamp = Get-Date -Format "yyyyMMdd-HHmmss-fff"
$path = Join-Path $taskDir "$stamp.json"
$indexPath = Join-Path $root "ESCALATION_INDEX.jsonl"

if (Test-Path -LiteralPath $indexPath) {
    foreach ($line in Get-Content -LiteralPath $indexPath -Encoding UTF8) {
        if (-not $line.Trim()) { continue }
        try {
            $existing = $line | ConvertFrom-Json
            if ($existing.task_id -eq $TaskId -and
                $existing.source -eq $Source -and
                $existing.reason -eq $Reason -and
                $existing.status -eq "awaiting_josh") {
                Write-Output "escalation_status=already_exists"
                Write-Output "escalation_path=$($existing.artifact_path)"
                Write-Output "escalation_index=$indexPath"
                exit 0
            }
        } catch {
            continue
        }
    }
}

$payload = [ordered]@{
    task_id = $TaskId
    source = $Source
    reason = $Reason
    decision_type = $DecisionType
    summary_for_josh = $SummaryForJosh
    options = @(
        [ordered]@{ label = "Approve"; effect = ([char[]]@(0x5141,0x8A31,0x5728,0x6838,0x51C6,0x7BC4,0x570D,0x5167,0x7E7C,0x7E8C,0x57F7,0x884C) -join '') },
        [ordered]@{ label = "Modify"; effect = ([char[]]@(0x8ABF,0x6574,0x9700,0x6C42,0x5F8C,0x91CD,0x8DD1) -join '') },
        [ordered]@{ label = "Stop"; effect = ([char[]]@(0x505C,0x6B62,0x4EFB,0x52D9) -join '') }
    )
    evidence = @($Evidence)
    created_at = $createdAt
    status = "awaiting_josh"
}

$json = $payload | ConvertTo-Json -Depth 8
[IO.File]::WriteAllText($path, $json + [Environment]::NewLine, $utf8)
$indexLine = ([ordered]@{
    task_id = $TaskId
    source = $Source
    reason = $Reason
    artifact_path = $path
    created_at = $createdAt
    status = "awaiting_josh"
} | ConvertTo-Json -Compress)
[IO.File]::AppendAllText($indexPath, $indexLine + [Environment]::NewLine, $utf8)

Write-Output "escalation_status=created"
Write-Output "escalation_path=$path"
Write-Output "escalation_index=$indexPath"

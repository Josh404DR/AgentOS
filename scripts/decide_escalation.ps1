[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$TaskId,
    [Parameter(Mandatory = $true)]
    [ValidateSet("approve", "modify", "stop")][string]$Decision,
    [string]$Note = "",
    [Parameter(Mandatory = $true)][string]$ActorId,
    [string]$AuthMethod = "",
    [Parameter(Mandatory = $true)][string]$RequestId,
    [string]$ReceiptPath = "",
    [int]$SuspiciousDecisionSeconds = 10,
    [string]$AgentOSRoot = "E:\AgentOS"
)

$ErrorActionPreference = "Stop"
$Utf8NoBom = [Text.UTF8Encoding]::new($false)
. (Join-Path $AgentOSRoot "scripts\escalation_receipt_validation.ps1")
. (Join-Path $AgentOSRoot "scripts\lib\global_jsonl_lock.ps1")

$safeId = Get-AgentOSEscalationSafeId $TaskId
$dir = Join-Path $AgentOSRoot "data\escalations\$safeId"
$auditDir = Join-Path $AgentOSRoot "data\escalation_audit\$safeId"
$auditPath = Join-Path $auditDir "AUDIT.jsonl"

function Write-DecisionAudit([string]$Status, [string]$Reason, [bool]$Suspicious, [string]$Artifact = "") {
    New-Item -ItemType Directory -Force -Path $auditDir | Out-Null
    $entry = [ordered]@{
        timestamp = (Get-Date).ToString("o")
        task_id = $safeId
        action = "escalation.decision"
        status = $Status
        reason = $Reason
        actor_id = $ActorId
        authentication_method = $AuthMethod
        request_id = $RequestId
        receipt_path = $ReceiptPath
        suspicious_fast_decision = $Suspicious
        artifact_path = $Artifact
    } | ConvertTo-Json -Compress
    $pending = $entry + [Environment]::NewLine
    Invoke-GlobalJsonlLockedAppend -LiteralPath $auditPath -PendingContent $pending -AppendAction {
        [IO.File]::AppendAllText($auditPath, $pending, $Utf8NoBom)
    }
}

function Reject-Decision([string]$Reason) {
    Write-DecisionAudit "rejected" $Reason $false
    Write-Output "escalation_decision_status=rejected"
    Write-Output "task_id=$safeId"
    Write-Output "task_status=awaiting_josh"
    Write-Output "reason=$Reason"
    Write-Output "audit_path=$auditPath"
    exit 12
}

if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
    throw "Escalation not found: $safeId"
}
if (-not $ReceiptPath) { Reject-Decision "decision_receipt_missing" }

$validation = Test-AgentOSEscalationReceipt -AgentOSRoot $AgentOSRoot `
    -TaskId $TaskId -Decision $Decision -ActorId $ActorId -AuthMethod $AuthMethod `
    -RequestId $RequestId -ReceiptPath $ReceiptPath
if (-not $validation.Valid) { Reject-Decision ([string]$validation.Reason) }

# A receipt is one-time. A second DECISION may not reuse it.
foreach ($existingPath in Get-ChildItem -LiteralPath $dir -Filter "DECISION-*.json" -File -ErrorAction SilentlyContinue) {
    try {
        $existing = [IO.File]::ReadAllText($existingPath.FullName, [Text.Encoding]::UTF8) | ConvertFrom-Json
        if ($existing.receipt -and [string]$existing.receipt.sha256 -eq [string]$validation.Hash) {
            Reject-Decision "decision_receipt_already_consumed"
        }
    } catch { continue }
}

$createdAt = $null
foreach ($candidate in Get-ChildItem -LiteralPath $dir -Filter "*.json" -File |
    Where-Object { $_.Name -notlike "DECISION-*" -and $_.Name -notlike "RESOLUTION*" } |
    Sort-Object LastWriteTime) {
    try {
        $event = [IO.File]::ReadAllText($candidate.FullName, [Text.Encoding]::UTF8) | ConvertFrom-Json
        if ([string]$event.task_id -eq $TaskId -and $event.created_at) {
            $candidateCreatedAt = [DateTimeOffset]::Parse([string]$event.created_at)
            # One task_id may have multiple append-only escalation generations.
            # Bind a new decision to the latest event, never the oldest file.
            if (-not $createdAt -or $candidateCreatedAt -gt $createdAt) {
                $createdAt = $candidateCreatedAt
            }
        }
    } catch { continue }
}
if (-not $createdAt) { Reject-Decision "escalation_created_at_missing" }

$now = [DateTimeOffset]::Now
$deltaSeconds = ($now - $createdAt).TotalSeconds
$suspicious = $deltaSeconds -ge 0 -and $deltaSeconds -lt $SuspiciousDecisionSeconds
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss-fff"
$decisionPath = Join-Path $dir "DECISION-$timestamp.json"
$existingResolution = Join-Path $dir "RESOLUTION.json"
$resolutionPath = if (Test-Path -LiteralPath $existingResolution) {
    Join-Path $dir "RESOLUTION-$timestamp.json"
} else {
    $existingResolution
}
$decidedAt = $now.ToString("o")
$payload = [ordered]@{
    schema_version = "2"
    task_id = $safeId
    decision = $Decision
    note = $Note
    decided_by = $ActorId
    authentication_method = $AuthMethod
    request_id = $RequestId
    decided_at = $decidedAt
    escalation_created_at = $createdAt.ToString("o")
    decision_delay_seconds = [Math]::Round($deltaSeconds, 3)
    suspicious_fast_decision = $suspicious
    receipt = [ordered]@{
        path = $validation.Path
        sha256 = $validation.Hash
        type = [string]$validation.Receipt.receipt_type
        issued_at = [string]$validation.Receipt.issued_at
        expires_at = [string]$validation.Receipt.expires_at
        verified_at = $decidedAt
    }
}
[IO.File]::WriteAllText($decisionPath, ($payload | ConvertTo-Json -Depth 8) + [Environment]::NewLine, $Utf8NoBom)
$resolution = [ordered]@{
    schema_version = "2"
    task_id = $safeId
    resolution_type = "verified_owner_decision"
    decision = $Decision
    resolved_at = $decidedAt
    resolved_by = $ActorId
    authentication_method = $AuthMethod
    request_id = $RequestId
    decision_path = $decisionPath
    receipt_path = $validation.Path
    receipt_sha256 = $validation.Hash
    suspicious_fast_decision = $suspicious
    summary = if ($Note) { $Note } else { "The verified owner selected $Decision." }
    evidence = @($decisionPath, $validation.Path)
    josh_action_required = $false
    recommended_status = if ($Decision -eq "stop") { "stopped" } else { "resolved" }
}
[IO.File]::WriteAllText($resolutionPath, ($resolution | ConvertTo-Json -Depth 8) + [Environment]::NewLine, $Utf8NoBom)
Write-DecisionAudit "recorded" "verified_owner_receipt" $suspicious $decisionPath

Write-Output "escalation_decision_status=recorded"
Write-Output "task_id=$safeId"
Write-Output "decision=$Decision"
Write-Output "decision_path=$decisionPath"
Write-Output "resolution_path=$resolutionPath"
Write-Output "receipt_path=$($validation.Path)"
Write-Output "receipt_sha256=$($validation.Hash)"
Write-Output "suspicious_fast_decision=$($suspicious.ToString().ToLowerInvariant())"
Write-Output "audit_path=$auditPath"

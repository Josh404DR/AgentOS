[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$DraftId,
    [string]$AgentOSRoot = "E:\AgentOS"
)

$ErrorActionPreference = "Stop"
$utf8 = [Text.UTF8Encoding]::new($false)

# Step 1: Normalize safe id for the source draft and derive target promoted task id
$safeDraftId = [regex]::Replace($DraftId, '[^A-Za-z0-9_.-]+', '-')
$draftDir = Join-Path $AgentOSRoot "data\tasks\$safeDraftId"
$draftTaskPath = Join-Path $draftDir "TASK.md"

if (-not (Test-Path -LiteralPath $draftTaskPath -PathType Leaf)) {
    Write-Error "promote_draft: draft TASK.md not found: $draftTaskPath"
    exit 10
}

$draftRaw = Get-Content -Raw -LiteralPath $draftTaskPath -Encoding UTF8
$draftContent = $draftRaw -replace "`r`n", "`n" -replace "`r", "`n"

$dispatchMatch = [regex]::Match($draftContent, '(?m)^dispatch_id:\s*(\S+)\s*$')
if (-not $dispatchMatch.Success) {
    Write-Error "promote_draft: draft TASK.md missing dispatch_id"
    exit 11
}
$promotedTaskId = $dispatchMatch.Groups[1].Value
$safePromotedId = [regex]::Replace($promotedTaskId, '[^A-Za-z0-9_.-]+', '-')

# Step 2: Three-way consistency checks — no StartsWith or prefix matching anywhere

# 2a: RESOLUTION.json decision must identify the draft being promoted
$escalationDir = Join-Path $AgentOSRoot "data\escalations\$safeDraftId"
$resolutionPath = Join-Path $escalationDir "RESOLUTION.json"
if (-not (Test-Path -LiteralPath $resolutionPath -PathType Leaf)) {
    Write-Error "promote_draft: RESOLUTION.json not found: $resolutionPath"
    exit 12
}
$resolution = Get-Content -Raw -LiteralPath $resolutionPath -Encoding UTF8 | ConvertFrom-Json
if ($resolution.task_id -ne $safeDraftId) {
    Write-Error "promote_draft: RESOLUTION task_id '$($resolution.task_id)' != safeDraftId '$safeDraftId'"
    exit 13
}
if ($resolution.decision -ne "approve") {
    Write-Error "promote_draft: RESOLUTION decision '$($resolution.decision)' is not 'approve'"
    exit 14
}

# 2b: Escalation event task_id must equal the complete draft id string exactly — no StartsWith
$escalationFiles = Get-ChildItem -LiteralPath $escalationDir -Filter "*.json" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne "RESOLUTION.json" -and $_.Name -notlike "DECISION-*" -and $_.Name -ne "PROMOTED.json" }
$eventMatch = $null
$eventMatchPath = $null
foreach ($ef in $escalationFiles) {
    try {
        $ev = Get-Content -Raw -LiteralPath $ef.FullName -Encoding UTF8 | ConvertFrom-Json
        # Exact string equality required — StartsWith is explicitly forbidden
        if ($ev.task_id -eq $DraftId) {
            $eventMatch = $ev
            $eventMatchPath = $ef.FullName
            break
        }
    } catch { continue }
}
if ($null -eq $eventMatch) {
    Write-Error "promote_draft: no escalation event with task_id exactly '$DraftId' in $escalationDir"
    exit 15
}

# 2c: Draft TASK.md must self-declare draft_id matching DraftId exactly
$draftIdMatch = [regex]::Match($draftContent, '(?m)^draft_id:\s*(.+?)\s*$')
if (-not $draftIdMatch.Success) {
    Write-Error "promote_draft: draft TASK.md is missing a draft_id: line"
    exit 16
}
$declaredId = $draftIdMatch.Groups[1].Value.Trim()
if ($declaredId -ne $DraftId) {
    Write-Error "promote_draft: draft_id '$declaredId' != DraftId '$DraftId'"
    exit 17
}

# Step 3: Reject if target promoted TASK.md already exists
$targetDir = Join-Path $AgentOSRoot "data\tasks\$safePromotedId"
$targetTaskPath = Join-Path $targetDir "TASK.md"
if (Test-Path -LiteralPath $targetTaskPath -PathType Leaf) {
    Write-Error "promote_draft: target TASK.md already exists: $targetTaskPath"
    exit 18
}

# Step 4: Governance binding check
$govStatusPath = Join-Path $AgentOSRoot "data\governance\governance_status.json"
if (-not (Test-Path -LiteralPath $govStatusPath -PathType Leaf)) {
    Write-Error "promote_draft: governance_status.json not found: $govStatusPath"
    exit 19
}
$govStatus = Get-Content -Raw -LiteralPath $govStatusPath -Encoding UTF8 | ConvertFrom-Json
if ($govStatus.governance_status -ne "aligned") {
    Write-Error "promote_draft: governance_status=$($govStatus.governance_status), need aligned"
    exit 20
}
$govVersion = $govStatus.governance_version
$govHash = $govStatus.canonical_hash

# Step 5: Write promoted task TASK.md and PROMOTED.json evidence marker
$promotedAt = (Get-Date).ToString("o")
New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

$lines = $draftContent -split "`n"
$newLines = [System.Collections.Generic.List[string]]::new()
$statusReplaced = $false
foreach ($line in $lines) {
    if (-not $statusReplaced -and $line -match '^status:\s*\S+') {
        $newLines.Add("status: promoted")
        $newLines.Add("promoted_at: $promotedAt")
        $newLines.Add("governance_version: $govVersion")
        $newLines.Add("governance_hash: $govHash")
        $statusReplaced = $true
    } else {
        $newLines.Add($line)
    }
}
$promotedContent = $newLines -join "`n"
[IO.File]::WriteAllText($targetTaskPath, $promotedContent, $utf8)

$promotedJson = [ordered]@{
    source_draft_id       = $DraftId
    source_draft_path     = $draftTaskPath
    target_task_id        = $promotedTaskId
    target_task_path      = $targetTaskPath
    escalation_event_task_id = $eventMatch.task_id
    resolution_task_id    = $resolution.task_id
    decision              = $resolution.decision
    governance_version    = $govVersion
    governance_hash       = $govHash
    promoted_at           = $promotedAt
}
$promotedJsonPath = Join-Path $escalationDir "PROMOTED.json"
[IO.File]::WriteAllText($promotedJsonPath, ($promotedJson | ConvertTo-Json -Depth 5) + [Environment]::NewLine, $utf8)

Write-Output "promote_status=success"
Write-Output "source_draft_id=$DraftId"
Write-Output "target_task_id=$promotedTaskId"
Write-Output "target_task_path=$targetTaskPath"
Write-Output "promoted_json_path=$promotedJsonPath"
Write-Output "governance_version=$govVersion"
Write-Output "governance_hash=$govHash"
Write-Output "promoted_at=$promotedAt"

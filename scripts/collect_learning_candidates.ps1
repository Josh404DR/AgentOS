#Requires -Version 5.1
# collect_learning_candidates.ps1
# Deterministic learning candidate collector for AgentOS Workflow v1.2.
# No model calls. No external services. Append-only output.
# Usage: .\collect_learning_candidates.ps1 [-AgentOSRoot <path>] [-Threshold <int>] [-DryRun]
# Override input/output paths for testing: -MetricsLogPath, -EscalationIndexPath, -EscalationDir, -CandidateDir

[CmdletBinding()]
param(
    [string]$AgentOSRoot        = "E:\AgentOS",
    [int]$Threshold             = 2,
    [string]$MetricsLogPath     = "",
    [string]$EscalationIndexPath = "",
    [string]$EscalationDir      = "",
    [string]$CandidateDir       = "",
    [string]$CollectorVersion   = "1.0.0",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Paths ──────────────────────────────────────────────────────────────────
$root = (Resolve-Path -LiteralPath $AgentOSRoot).Path
if (-not $MetricsLogPath)      { $MetricsLogPath      = Join-Path $root "data\metrics\METRICS_LOG.jsonl" }
if (-not $EscalationIndexPath) { $EscalationIndexPath = Join-Path $root "data\escalations\ESCALATION_INDEX.jsonl" }
if (-not $EscalationDir)       { $EscalationDir       = Join-Path $root "data\escalations" }
if (-not $CandidateDir)        { $CandidateDir        = Join-Path $root "data\learning_candidates" }

$candidateIndexPath = Join-Path $CandidateDir "LEARNING_CANDIDATE_INDEX.jsonl"
$schemaVersion      = "1.0.0"

# ── Governance Context ──────────────────────────────────────────────────────
$govStatusPath = Join-Path $root "data\governance\governance_status.json"
$govVersion    = "unknown"
$govHash       = "unknown"
if (Test-Path -LiteralPath $govStatusPath -PathType Leaf) {
    $govStatus  = Get-Content -Raw -LiteralPath $govStatusPath -Encoding UTF8 | ConvertFrom-Json
    $govVersion = $govStatus.governance_version
    $govHash    = $govStatus.canonical_hash
}

# ── Governance keyword set (determines change_class) ───────────────────────
$governanceKeywords = @(
    "governance", "routing", "risk_rule", "risk_rules", "agents_md",
    "agents\.md", "completion_standard", "workflow_contract", "safety",
    "security_policy", "role_definition", "prompt_template", "escalation_policy"
)
$governancePattern = ($governanceKeywords | ForEach-Object { [regex]::Escape($_) }) -join "|"

function Get-ChangeClass {
    param([string]$ReasonKey)
    if ($ReasonKey -match $governancePattern) { return "governance_change" }
    return "implementation_change"
}

# ── Impact from frequency ──────────────────────────────────────────────────
function Get-Impact {
    param([int]$Count)
    if ($Count -ge 5) { return "high" }
    if ($Count -ge 3) { return "medium" }
    return "low"
}

# ── Deterministic recommendation text ─────────────────────────────────────
function Get-Recommendation {
    param([string]$ReasonKey, [string]$ChangeClass)
    if ($ChangeClass -eq "governance_change") {
        return "此失敗原因涉及治理、路由或安全層面。需要 Josh 評估是否調整相關治理文件、規則或角色定義。請查閱對應的 escalation artifact 取得詳情。"
    }
    switch -Wildcard ($ReasonKey) {
        "*garbled*"                      { return "Verify 因原始請求亂碼而假 FAIL：檢查 dispatcher 子程序主控台編碼（chcp 65001）與 UTF-8 prompt 傳遞路徑是否退化，並確認相關 launcher 未被改回未設定編碼的版本。" }
        "*misrouted*"                    { return "查詢型請求被派給無網路權限的 workspace worker：檢查 classify_task.ps1 的 INFO_QUERY 判定規則與 local_file_task_worker.ps1 的路由分支是否涵蓋此訊息型態。" }
        "*verify_output_missing*"        { return "確認 Codex Verify 的 RESULT.md 是否依照 acceptance criteria 正確產出，並補充遺漏的輸出路徑或格式說明。" }
        "*sandbox_blocks*"               { return "評估是否提供 Codex Verify 更多靜態 artifact，以取代需要執行環境的驗證步驟；或在工單中補充等效靜態證據。" }
        "*codex_verify_needs_human*"     { return "分析 Codex Verify 回傳 NEEDS_HUMAN_DECISION 的根本原因，考慮在 acceptance criteria 中增加明確判斷標準以減少人工決策需求。" }
        "*fixture*"                      { return "Fixture 類別的重複事件不代表實際工作流程問題；建議確認相關 fixture 是否已妥善標記並與正式流程隔離。" }
        "*unknown_retry*"                { return "有多個工單在無明確 fail_reason 的情況下進行重試；建議確保 METRICS_LOG 記錄完整的失敗原因以利後續分析。" }
        default                          { return "分析重複出現的失敗原因（$ReasonKey），評估是否需要更新工作流程步驟、驗收條件或相關腳本。" }
    }
}

# ── SHA-256 helper (no external calls) ────────────────────────────────────
# $Input is a PowerShell automatic variable; use $Text to avoid shadowing.
function Get-Sha256Hex {
    param([string]$Text)
    $sha256    = [System.Security.Cryptography.SHA256]::Create()
    $bytes     = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $hashBytes = $sha256.ComputeHash($bytes)
    return ($hashBytes | ForEach-Object { $_.ToString("x2") }) -join ""
}

# ── Load events ────────────────────────────────────────────────────────────
Write-Output "collector_version=$CollectorVersion"
Write-Output "threshold=$Threshold"
Write-Output "dry_run=$($DryRun.IsPresent)"
Write-Output "governance_version=$govVersion"
Write-Output "governance_hash=$govHash"

$events = [System.Collections.Generic.List[hashtable]]::new()

# -- METRICS_LOG: entries with fail_reason or retry_count >= 1
if (Test-Path -LiteralPath $MetricsLogPath -PathType Leaf) {
    $metricsLines = Get-Content -LiteralPath $MetricsLogPath -Encoding UTF8
    foreach ($line in $metricsLines) {
        $line = $line.Trim()
        if ([string]::IsNullOrEmpty($line)) { continue }
        try { $entry = $line | ConvertFrom-Json } catch { continue }
        $taskId      = if ($entry.PSObject.Properties["task_id"])      { "$($entry.task_id)" }      else { "" }
        $failReason  = if ($entry.PSObject.Properties["fail_reason"])  { "$($entry.fail_reason)" }  else { "" }
        $retryCount  = if ($entry.PSObject.Properties["retry_count"])  { [int]$entry.retry_count }   else { 0 }
        $recordedAt  = if ($entry.PSObject.Properties["recorded_at"])  { "$($entry.recorded_at)" }  else { "" }

        if (-not [string]::IsNullOrWhiteSpace($failReason)) {
            $events.Add(@{
                task_id     = $taskId
                fail_reason = $failReason
                retry_count = $retryCount
                source      = "metrics_fail"
                path        = $MetricsLogPath
                recorded_at = $recordedAt
            })
        } elseif ($retryCount -ge 1) {
            $events.Add(@{
                task_id     = $taskId
                fail_reason = "unknown_retry"
                retry_count = $retryCount
                source      = "metrics_retry"
                path        = $MetricsLogPath
                recorded_at = $recordedAt
            })
        }
    }
}
Write-Output "metrics_events_loaded=$($events.Count)"

# -- ESCALATION_INDEX: entries whose RESOLUTION.json exists in EscalationDir/<task_id>/
$resolvedCount = 0
if (Test-Path -LiteralPath $EscalationIndexPath -PathType Leaf) {
    $escalationLines = Get-Content -LiteralPath $EscalationIndexPath -Encoding UTF8
    foreach ($line in $escalationLines) {
        $line = $line.Trim()
        if ([string]::IsNullOrEmpty($line)) { continue }
        try { $entry = $line | ConvertFrom-Json } catch { continue }
        $taskId    = if ($entry.PSObject.Properties["task_id"]) { "$($entry.task_id)" } else { "" }
        $reason    = if ($entry.PSObject.Properties["reason"])  { "$($entry.reason)" }  else { "" }
        $createdAt = if ($entry.PSObject.Properties["created_at"]) { "$($entry.created_at)" } else { "" }

        if ([string]::IsNullOrWhiteSpace($taskId) -or [string]::IsNullOrWhiteSpace($reason)) { continue }

        # Check for RESOLUTION.json in the escalation subdirectory
        $resPath = Join-Path $EscalationDir "$taskId\RESOLUTION.json"
        if (-not (Test-Path -LiteralPath $resPath -PathType Leaf)) { continue }

        try {
            $resolution = Get-Content -Raw -LiteralPath $resPath -Encoding UTF8 | ConvertFrom-Json
            $resolvedAt = if ($resolution.PSObject.Properties["resolved_at"]) { "$($resolution.resolved_at)" } else { $createdAt }
        } catch {
            $resolvedAt = $createdAt
        }

        $events.Add(@{
            task_id         = $taskId
            fail_reason     = $reason
            retry_count     = 0
            source          = "resolved_escalation"
            path            = $resPath
            recorded_at     = $resolvedAt
            resolution_path = $resPath
        })
        $resolvedCount++
    }
}
Write-Output "resolved_escalation_events_loaded=$resolvedCount"
Write-Output "total_events=$($events.Count)"

# ── Group by normalized failure_reason_key ─────────────────────────────────
$groups = @{}
foreach ($ev in $events) {
    $key = $ev.fail_reason.ToLower().Trim()
    if (-not $groups.ContainsKey($key)) { $groups[$key] = [System.Collections.Generic.List[hashtable]]::new() }
    $groups[$key].Add($ev)
}
Write-Output "unique_failure_reason_keys=$($groups.Count)"

# ── Load existing candidates (for dedup) ───────────────────────────────────
$existingDedupeKeys = [System.Collections.Generic.HashSet[string]]::new()
if (Test-Path -LiteralPath $candidateIndexPath -PathType Leaf) {
    $indexLines = Get-Content -LiteralPath $candidateIndexPath -Encoding UTF8
    foreach ($line in $indexLines) {
        $line = $line.Trim()
        if ([string]::IsNullOrEmpty($line)) { continue }
        try {
            $entry = $line | ConvertFrom-Json
            if ($entry.PSObject.Properties["dedupe_key"] -and -not [string]::IsNullOrWhiteSpace($entry.dedupe_key)) {
                $null = $existingDedupeKeys.Add("$($entry.dedupe_key)")
            }
        } catch { continue }
    }
}
Write-Output "existing_candidates=$($existingDedupeKeys.Count)"

# ── Process groups ─────────────────────────────────────────────────────────
$now            = [System.DateTimeOffset]::UtcNow.ToOffset([System.TimeSpan]::FromHours(8))
$datePrefix     = $now.ToString("yyyyMMdd")
$isoNow         = $now.ToString("yyyy-MM-ddTHH:mm:sszzz")

$createdCount   = 0
$skippedLow     = 0
$skippedDedupe  = 0
$escalatedCount = 0

if (-not $DryRun) {
    if (-not (Test-Path -LiteralPath $CandidateDir -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $CandidateDir -Force
    }
}

foreach ($key in $groups.Keys) {
    $evList = $groups[$key]

    if ($evList.Count -lt $Threshold) {
        $skippedLow++
        Write-Output "skip_low_frequency: key=$key count=$($evList.Count) threshold=$Threshold"
        continue
    }

    $sourceTaskIds = ($evList | ForEach-Object { $_.task_id } | Sort-Object -Unique)
    $dedupeInput   = $key + ":" + ($sourceTaskIds -join ",")
    $dedupeKey     = Get-Sha256Hex -Text $dedupeInput

    if ($existingDedupeKeys.Contains($dedupeKey)) {
        $skippedDedupe++
        Write-Output "skip_duplicate: key=$key dedupe_key=$($dedupeKey.Substring(0,16))..."
        continue
    }

    $changeClass    = Get-ChangeClass -ReasonKey $key
    $recommendation = Get-Recommendation -ReasonKey $key -ChangeClass $changeClass
    $impact         = Get-Impact -Count $evList.Count
    $candidateId    = "LC-$datePrefix-$($dedupeKey.Substring(0,8))"

    $sourcePaths     = ($evList | ForEach-Object { $_.path } | Sort-Object -Unique)
    $reasonExamples  = ($evList | ForEach-Object { $_.fail_reason } | Select-Object -First 5 | Sort-Object -Unique)

    $retryEvidence = @(
        $evList | Where-Object { $_.retry_count -ge 1 } | ForEach-Object {
            @{
                task_id     = $_.task_id
                retry_count = $_.retry_count
                fail_reason = $_.fail_reason
                recorded_at = $_.recorded_at
            }
        }
    )

    $resolvedEvidence = @(
        $evList | Where-Object { $_.source -eq "resolved_escalation" } | ForEach-Object {
            $ev = $_
            $resObj = @{
                task_id         = $ev.task_id
                reason          = $ev.fail_reason
                resolution_path = $ev.resolution_path
                resolved_at     = $ev.recorded_at
            }
            $resObj
        }
    )

    $candidate = [ordered]@{
        candidate_id          = $candidateId
        schema_version        = $schemaVersion
        created_at            = $isoNow
        collector_version     = $CollectorVersion
        governance_version    = $govVersion
        governance_hash       = $govHash
        source_task_ids       = @($sourceTaskIds)
        source_evidence_paths = @($sourcePaths)
        failure_reason_key    = $key
        failure_reason_examples = @($reasonExamples)
        frequency             = $evList.Count
        threshold             = $Threshold
        retry_evidence        = $retryEvidence
        resolved_evidence     = $resolvedEvidence
        impact                = $impact
        recommendation        = $recommendation
        change_class          = $changeClass
        josh_approval_status  = "pending"
        dedupe_key            = $dedupeKey
        status                = "open"
    }

    $candidateJson = $candidate | ConvertTo-Json -Depth 10 -Compress:$false

    if ($DryRun) {
        Write-Output "DRY_RUN candidate_id=$candidateId change_class=$changeClass frequency=$($evList.Count) key=$key"
        $null = $existingDedupeKeys.Add($dedupeKey)
        $createdCount++
        continue
    }

    if ($changeClass -eq "governance_change") {
        # Route to escalation instead of creating a candidate file
        $escTaskId  = "learning-candidate-$candidateId"
        $escDir     = Join-Path $EscalationDir $escTaskId
        if (-not (Test-Path -LiteralPath $escDir -PathType Container)) {
            $null = New-Item -ItemType Directory -Path $escDir -Force
        }
        $escTimestamp   = $now.ToString("yyyyMMdd-HHmmss-fff")
        $escArtifact    = Join-Path $escDir "$escTimestamp.json"
        $escalationEntry = [ordered]@{
            task_id            = $escTaskId
            source             = "learning_candidate_governance"
            reason             = "governance_change_candidate:$key"
            decision_type      = "governance_review"
            summary_for_josh   = "學習候選項目（$candidateId）的建議涉及治理層面（$key），需要 Josh 評估後才能建立後續工單或修改治理文件。詳見此 escalation artifact 的 candidate 欄位。"
            candidate          = $candidate
            evidence           = @($sourcePaths)
            created_at         = $isoNow
            status             = "awaiting_josh"
        }
        $escalationJson = $escalationEntry | ConvertTo-Json -Depth 10 -Compress:$false
        Set-Content -LiteralPath $escArtifact -Value $escalationJson -Encoding UTF8

        # Append to ESCALATION_INDEX (append-only)
        $indexEntry = [ordered]@{
            task_id      = $escTaskId
            source       = "learning_candidate_governance"
            reason       = "governance_change_candidate:$key"
            artifact_path = $escArtifact
            created_at   = $isoNow
            status       = "awaiting_josh"
        }
        $indexLine = $indexEntry | ConvertTo-Json -Compress
        Add-Content -LiteralPath $EscalationIndexPath -Value $indexLine -Encoding UTF8

        Write-Output "governance_escalation_created: candidate_id=$candidateId task_id=$escTaskId artifact=$escArtifact"
        $null = $existingDedupeKeys.Add($dedupeKey)
        $escalatedCount++
    } else {
        # Write candidate artifact (create-new only)
        $candidatePath = Join-Path $CandidateDir "$candidateId.json"
        Set-Content -LiteralPath $candidatePath -Value $candidateJson -Encoding UTF8

        # Append to LEARNING_CANDIDATE_INDEX (append-only)
        $indexEntry = [ordered]@{
            candidate_id   = $candidateId
            failure_reason_key = $key
            frequency      = $evList.Count
            change_class   = $changeClass
            impact         = $impact
            dedupe_key     = $dedupeKey
            created_at     = $isoNow
            status         = "open"
            artifact_path  = $candidatePath
        }
        $indexLine = $indexEntry | ConvertTo-Json -Compress
        Add-Content -LiteralPath $candidateIndexPath -Value $indexLine -Encoding UTF8

        Write-Output "candidate_created: candidate_id=$candidateId change_class=$changeClass frequency=$($evList.Count) impact=$impact artifact=$candidatePath"
        $null = $existingDedupeKeys.Add($dedupeKey)
        $createdCount++
    }
}

# ── Summary ────────────────────────────────────────────────────────────────
Write-Output "--- SUMMARY ---"
Write-Output "candidates_created=$createdCount"
Write-Output "governance_escalations=$escalatedCount"
Write-Output "skipped_low_frequency=$skippedLow"
Write-Output "skipped_duplicate=$skippedDedupe"
Write-Output "candidate_index=$candidateIndexPath"
Write-Output "model_calls=0"
Write-Output "external_services=0"

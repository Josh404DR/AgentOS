# Shared deterministic validator for escalation owner receipts.
# Dot-source this file; it performs no action by itself.

function Get-AgentOSEscalationSafeId([string]$TaskId) {
    return [regex]::Replace($TaskId, '[^A-Za-z0-9_.-]+', '-').Trim('-')
}

function Get-AgentOSEscalationReceiptCanonical([object]$Receipt) {
    $fields = @(
        "schema_version=$([string]$Receipt.schema_version)",
        "receipt_type=$([string]$Receipt.receipt_type)",
        "task_id=$([string]$Receipt.task_id)",
        "decision=$([string]$Receipt.decision)",
        "actor_id=$([string]$Receipt.actor_id)",
        "authentication_method=$([string]$Receipt.authentication_method)",
        "request_id=$([string]$Receipt.request_id)",
        "issued_at=$([string]$Receipt.issued_at)",
        "expires_at=$([string]$Receipt.expires_at)",
        "session_validated=$(([bool]$Receipt.session_validated).ToString().ToLowerInvariant())",
        "csrf_validated=$(([bool]$Receipt.csrf_validated).ToString().ToLowerInvariant())",
        "origin_validated=$(([bool]$Receipt.origin_validated).ToString().ToLowerInvariant())",
        "local_client_validated=$(([bool]$Receipt.local_client_validated).ToString().ToLowerInvariant())",
        "telegram_identity=$([string]$Receipt.telegram_identity)",
        "confirmation_code_consumed=$(([bool]$Receipt.confirmation_code_consumed).ToString().ToLowerInvariant())"
    )
    return ($fields -join "`n") + "`n"
}

function Get-AgentOSHmacHex([byte[]]$Key, [string]$Text) {
    $hmac = [Security.Cryptography.HMACSHA256]::new($Key)
    try {
        return ([BitConverter]::ToString(
            $hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))
        ) -replace '-', '')
    } finally {
        $hmac.Dispose()
    }
}

function Test-AgentOSPathHasReparsePoint([string]$BasePath, [string]$TargetPath) {
    $base = [IO.Path]::GetFullPath($BasePath).TrimEnd('\')
    $target = [IO.Path]::GetFullPath($TargetPath)
    if (-not $target.StartsWith($base + '\', [StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }
    $cursor = $base
    $relative = $target.Substring($base.Length).TrimStart('\')
    foreach ($segment in $relative.Split('\', [StringSplitOptions]::RemoveEmptyEntries)) {
        $cursor = Join-Path $cursor $segment
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                return $true
            }
        }
    }
    return $false
}

function Test-AgentOSEscalationReceipt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$AgentOSRoot,
        [Parameter(Mandatory = $true)][string]$TaskId,
        [Parameter(Mandatory = $true)][string]$Decision,
        [Parameter(Mandatory = $true)][string]$ActorId,
        [Parameter(Mandatory = $true)][string]$AuthMethod,
        [Parameter(Mandatory = $true)][string]$RequestId,
        [Parameter(Mandatory = $true)][string]$ReceiptPath,
        [switch]$AllowExpired
    )

    $reject = @('', 'current_chat_explicit_instruction', 'prior_instruction')
    if ($AuthMethod.Trim().ToLowerInvariant() -in $reject) {
        return [pscustomobject]@{ Valid=$false; Reason='authentication_method_not_verifiable'; Receipt=$null; Hash='' }
    }
    $safeId = Get-AgentOSEscalationSafeId $TaskId
    $taskDir = Join-Path $AgentOSRoot "data\escalations\$safeId"
    $receiptDir = Join-Path $taskDir 'receipts'
    try {
        $fullReceipt = [IO.Path]::GetFullPath($ReceiptPath)
        $fullReceiptDir = [IO.Path]::GetFullPath($receiptDir).TrimEnd('\')
    } catch {
        return [pscustomobject]@{ Valid=$false; Reason='receipt_path_invalid'; Receipt=$null; Hash='' }
    }
    if (-not $fullReceipt.StartsWith($fullReceiptDir + '\', [StringComparison]::OrdinalIgnoreCase)) {
        return [pscustomobject]@{ Valid=$false; Reason='receipt_path_outside_escalation'; Receipt=$null; Hash='' }
    }
    if (-not (Test-Path -LiteralPath $fullReceipt -PathType Leaf)) {
        return [pscustomobject]@{ Valid=$false; Reason='receipt_missing'; Receipt=$null; Hash='' }
    }
    if (Test-AgentOSPathHasReparsePoint $taskDir $fullReceipt) {
        return [pscustomobject]@{ Valid=$false; Reason='receipt_reparse_point_rejected'; Receipt=$null; Hash='' }
    }
    try {
        $receipt = [IO.File]::ReadAllText($fullReceipt, [Text.Encoding]::UTF8) | ConvertFrom-Json
    } catch {
        return [pscustomobject]@{ Valid=$false; Reason='receipt_json_invalid'; Receipt=$null; Hash='' }
    }
    if ([string]$receipt.schema_version -ne '1') {
        return [pscustomobject]@{ Valid=$false; Reason='receipt_schema_invalid'; Receipt=$receipt; Hash='' }
    }
    foreach ($pair in @(
        @([string]$receipt.task_id, $TaskId, 'receipt_task_mismatch'),
        @([string]$receipt.decision, $Decision, 'receipt_decision_mismatch'),
        @([string]$receipt.actor_id, $ActorId, 'receipt_actor_mismatch'),
        @([string]$receipt.authentication_method, $AuthMethod, 'receipt_auth_method_mismatch'),
        @([string]$receipt.request_id, $RequestId, 'receipt_request_mismatch')
    )) {
        if ($pair[0] -cne $pair[1]) {
            return [pscustomobject]@{ Valid=$false; Reason=$pair[2]; Receipt=$receipt; Hash='' }
        }
    }
    $type = ([string]$receipt.receipt_type).ToLowerInvariant()
    if ($type -eq 'dashboard_owner_session') {
        if ($AuthMethod -ne 'local_owner_token' -or
            -not [bool]$receipt.session_validated -or
            -not [bool]$receipt.csrf_validated -or
            -not [bool]$receipt.origin_validated -or
            -not [bool]$receipt.local_client_validated) {
            return [pscustomobject]@{ Valid=$false; Reason='dashboard_receipt_claims_invalid'; Receipt=$receipt; Hash='' }
        }
    } elseif ($type -eq 'telegram_one_time_confirmation') {
        $ownerTelegram = [Environment]::GetEnvironmentVariable('AGENTOS_OWNER_TELEGRAM_ID')
        if ($AuthMethod -ne 'telegram_one_time_confirmation' -or
            -not $ownerTelegram -or
            [string]$receipt.telegram_identity -cne $ownerTelegram -or
            -not [bool]$receipt.confirmation_code_consumed) {
            return [pscustomobject]@{ Valid=$false; Reason='telegram_receipt_claims_invalid'; Receipt=$receipt; Hash='' }
        }
    } else {
        return [pscustomobject]@{ Valid=$false; Reason='receipt_type_not_allowed'; Receipt=$receipt; Hash='' }
    }
    try {
        $issued = [DateTimeOffset]::Parse([string]$receipt.issued_at)
        $expires = [DateTimeOffset]::Parse([string]$receipt.expires_at)
    } catch {
        return [pscustomobject]@{ Valid=$false; Reason='receipt_timestamp_invalid'; Receipt=$receipt; Hash='' }
    }
    $now = [DateTimeOffset]::Now
    if ($expires -le $issued -or ((-not $AllowExpired) -and $now -gt $expires) -or $issued -gt $now.AddSeconds(5)) {
        return [pscustomobject]@{ Valid=$false; Reason='receipt_expired_or_time_invalid'; Receipt=$receipt; Hash='' }
    }
    $authDir = [Environment]::GetEnvironmentVariable('AGENTOS_DASHBOARD_AUTH_DIR')
    if (-not $authDir) { $authDir = Join-Path $AgentOSRoot 'data\dashboard_auth' }
    $keyPath = Join-Path $authDir 'decision-receipt.key'
    if (-not (Test-Path -LiteralPath $keyPath -PathType Leaf) -or
        (Get-Item -LiteralPath $keyPath -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
        return [pscustomobject]@{ Valid=$false; Reason='receipt_signing_key_unavailable'; Receipt=$receipt; Hash='' }
    }
    try {
        $key = [Convert]::FromBase64String(([IO.File]::ReadAllText($keyPath, [Text.Encoding]::UTF8)).Trim())
        $expected = Get-AgentOSHmacHex $key (Get-AgentOSEscalationReceiptCanonical $receipt)
    } catch {
        return [pscustomobject]@{ Valid=$false; Reason='receipt_signature_validation_failed'; Receipt=$receipt; Hash='' }
    }
    if (-not $receipt.signature -or -not [string]::Equals($expected, [string]$receipt.signature, [StringComparison]::OrdinalIgnoreCase)) {
        return [pscustomobject]@{ Valid=$false; Reason='receipt_signature_invalid'; Receipt=$receipt; Hash='' }
    }
    $hash = (Get-FileHash -LiteralPath $fullReceipt -Algorithm SHA256).Hash
    return [pscustomobject]@{ Valid=$true; Reason='verified'; Receipt=$receipt; Hash=$hash; Path=$fullReceipt }
}

function Test-AgentOSEscalationDecisionRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$AgentOSRoot,
        [Parameter(Mandatory = $true)][object]$DecisionRecord
    )
    if (-not $DecisionRecord.receipt -or -not $DecisionRecord.receipt.path) {
        return [pscustomobject]@{ Valid=$false; Reason='decision_receipt_missing' }
    }
    $result = Test-AgentOSEscalationReceipt -AgentOSRoot $AgentOSRoot `
        -TaskId ([string]$DecisionRecord.task_id) -Decision ([string]$DecisionRecord.decision) `
        -ActorId ([string]$DecisionRecord.decided_by) -AuthMethod ([string]$DecisionRecord.authentication_method) `
        -RequestId ([string]$DecisionRecord.request_id) -ReceiptPath ([string]$DecisionRecord.receipt.path) -AllowExpired
    if (-not $result.Valid) { return [pscustomobject]@{ Valid=$false; Reason=$result.Reason } }
    if ([string]$DecisionRecord.receipt.sha256 -cne [string]$result.Hash) {
        return [pscustomobject]@{ Valid=$false; Reason='decision_receipt_hash_mismatch' }
    }
    try {
        $issued = [DateTimeOffset]::Parse([string]$result.Receipt.issued_at)
        $expires = [DateTimeOffset]::Parse([string]$result.Receipt.expires_at)
        $decided = [DateTimeOffset]::Parse([string]$DecisionRecord.decided_at)
    } catch {
        return [pscustomobject]@{ Valid=$false; Reason='decision_timestamp_invalid' }
    }
    if ($decided -lt $issued -or $decided -gt $expires) {
        return [pscustomobject]@{ Valid=$false; Reason='decision_outside_receipt_window' }
    }
    return [pscustomobject]@{ Valid=$true; Reason='verified'; Receipt=$result.Receipt }
}

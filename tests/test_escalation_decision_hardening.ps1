[CmdletBinding()]
param([string]$AgentOSRoot = "E:\AgentOS")

$ErrorActionPreference = "Stop"
$Utf8NoBom = [Text.UTF8Encoding]::new($false)
$failures = [Collections.Generic.List[string]]::new()
$testRoot = Join-Path $AgentOSRoot ("data\test_runs\escalation-hardening-" + [guid]::NewGuid().ToString('N'))
$actualHistory = Join-Path $AgentOSRoot 'data\escalations\knowledge-workspace-phase1-readonly-20260720'
$historyBefore = @{}
if (Test-Path -LiteralPath $actualHistory) {
    foreach ($file in Get-ChildItem -LiteralPath $actualHistory -File) {
        $historyBefore[$file.FullName] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    }
}

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { $failures.Add($Message) }
}

function Write-Json([string]$Path, [object]$Value) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
    [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 10) + [Environment]::NewLine, $Utf8NoBom)
}

function New-Escalation([string]$TaskId, [DateTimeOffset]$CreatedAt) {
    $dir = Join-Path $testRoot "data\escalations\$TaskId"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Write-Json (Join-Path $dir 'EVENT.json') ([ordered]@{
        task_id=$TaskId; source='complex_fail'; reason='fixture'; created_at=$CreatedAt.ToString('o'); status='awaiting_josh'
    })
    $taskDir = Join-Path $testRoot "data\codex_tasks\$TaskId"
    New-Item -ItemType Directory -Force -Path (Join-Path $taskDir 'OUTPUTS') | Out-Null
    [IO.File]::WriteAllText((Join-Path $taskDir 'TASK.md'), "dispatch_id: $TaskId`ntype: ROOT`nroute_to: Hermes`ntask_status: blocked`ndispatch_status: escalation_required`n", $Utf8NoBom)
    return $dir
}

try {
    New-Item -ItemType Directory -Force -Path (Join-Path $testRoot 'scripts') | Out-Null
    foreach ($name in @('escalation_receipt_validation.ps1','decide_escalation.ps1','task_queue_runner.ps1')) {
        Copy-Item -LiteralPath (Join-Path $AgentOSRoot "scripts\$name") -Destination (Join-Path $testRoot "scripts\$name")
    }
    . (Join-Path $testRoot 'scripts\escalation_receipt_validation.ps1')
    $authDir = Join-Path $testRoot 'data\dashboard_auth'
    New-Item -ItemType Directory -Force -Path $authDir | Out-Null
    $signingKey = [byte[]]::new(32)
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($signingKey) } finally { $rng.Dispose() }
    [IO.File]::WriteAllText((Join-Path $authDir 'decision-receipt.key'), [Convert]::ToBase64String($signingKey) + "`n", $Utf8NoBom)

    function New-SignedReceipt(
        [string]$TaskId,
        [string]$Decision,
        [string]$Actor,
        [string]$Method,
        [string]$RequestId,
        [DateTimeOffset]$IssuedAt = [DateTimeOffset]::Now,
        [DateTimeOffset]$ExpiresAt = [DateTimeOffset]::Now.AddMinutes(2)
    ) {
        $dir = Join-Path $testRoot "data\escalations\$TaskId\receipts"
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $receipt = [ordered]@{
            schema_version='1'; receipt_type='dashboard_owner_session'; task_id=$TaskId
            decision=$Decision; actor_id=$Actor; authentication_method=$Method; request_id=$RequestId
            issued_at=$IssuedAt.ToString('o'); expires_at=$ExpiresAt.ToString('o')
            session_validated=$true; csrf_validated=$true; origin_validated=$true; local_client_validated=$true
            telegram_identity=''; confirmation_code_consumed=$false; source_api="/api/approvals/$TaskId/decision"
        }
        $receipt.signature = Get-AgentOSHmacHex $signingKey (Get-AgentOSEscalationReceiptCanonical ([pscustomobject]$receipt))
        $path = Join-Path $dir ("DASHBOARD-" + [guid]::NewGuid().ToString('N') + '.json')
        Write-Json $path $receipt
        return $path
    }

    $decider = Join-Path $testRoot 'scripts\decide_escalation.ps1'

    # No receipt / old chat instruction: rejected and audited, event untouched.
    $noReceiptId = 'test-no-receipt'
    $noReceiptDir = New-Escalation $noReceiptId ([DateTimeOffset]::Now.AddMinutes(-1))
    $eventHash = (Get-FileHash -LiteralPath (Join-Path $noReceiptDir 'EVENT.json') -Algorithm SHA256).Hash
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $decider `
        -TaskId $noReceiptId -Decision approve -ActorId Josh `
        -AuthMethod current_chat_explicit_instruction -RequestId old-chat -AgentOSRoot $testRoot 2>&1
    Assert-True ($LASTEXITCODE -eq 12) 'no-receipt decision did not fail closed'
    Assert-True (($output -join "`n") -match 'task_status=awaiting_josh') 'no-receipt rejection did not preserve awaiting_josh'
    Assert-True (-not (Get-ChildItem -LiteralPath $noReceiptDir -Filter 'DECISION-*.json')) 'rejected decision wrote a DECISION artifact'
    Assert-True ((Get-FileHash -LiteralPath (Join-Path $noReceiptDir 'EVENT.json') -Algorithm SHA256).Hash -eq $eventHash) 'rejected decision modified escalation event'
    $audit = Get-Content -LiteralPath (Join-Path $testRoot "data\escalation_audit\$noReceiptId\AUDIT.jsonl") -Encoding UTF8
    Assert-True (($audit -join "`n") -match 'decision_receipt_missing') 'no-receipt rejection audit missing'

    # A correctly signed payload still cannot make a forbidden auth method legal.
    $fakeId = 'test-fake-method'
    $null = New-Escalation $fakeId ([DateTimeOffset]::Now.AddMinutes(-1))
    $fakeReceipt = New-SignedReceipt $fakeId approve Josh prior_instruction fake-request
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $decider `
        -TaskId $fakeId -Decision approve -ActorId Josh -AuthMethod prior_instruction `
        -RequestId fake-request -ReceiptPath $fakeReceipt -AgentOSRoot $testRoot 2>&1
    Assert-True ($LASTEXITCODE -eq 12) 'forbidden authentication_method was accepted'
    Assert-True (($output -join "`n") -match 'authentication_method_not_verifiable') 'forbidden method failure reason was not precise'

    # Valid owner-session receipt succeeds and a fast decision is marked/audited.
    $legalId = 'test-legal-owner-session'
    $legalDir = New-Escalation $legalId ([DateTimeOffset]::Now.AddSeconds(-2))
    $legalReceipt = New-SignedReceipt $legalId modify 'host\josh' local_owner_token legal-request
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $decider `
        -TaskId $legalId -Decision modify -ActorId 'host\josh' -AuthMethod local_owner_token `
        -RequestId legal-request -ReceiptPath $legalReceipt -AgentOSRoot $testRoot 2>&1
    Assert-True ($LASTEXITCODE -eq 0) 'valid owner-session receipt was rejected'
    $decisionPath = (Get-ChildItem -LiteralPath $legalDir -Filter 'DECISION-*.json' -File | Select-Object -First 1).FullName
    $decision = Get-Content -Raw -LiteralPath $decisionPath -Encoding UTF8 | ConvertFrom-Json
    Assert-True ($decision.receipt.sha256 -eq (Get-FileHash -LiteralPath $legalReceipt -Algorithm SHA256).Hash) 'DECISION did not bind receipt hash'
    Assert-True ([bool]$decision.suspicious_fast_decision) 'fast decision was not marked suspicious'
    $legalAudit = Get-Content -LiteralPath (Join-Path $testRoot "data\escalation_audit\$legalId\AUDIT.jsonl") -Encoding UTF8
    Assert-True (($legalAudit -join "`n") -match '"suspicious_fast_decision":true') 'fast decision audit marker missing'
    $reuseOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $decider `
        -TaskId $legalId -Decision modify -ActorId 'host\josh' -AuthMethod local_owner_token `
        -RequestId legal-request -ReceiptPath $legalReceipt -AgentOSRoot $testRoot 2>&1
    Assert-True ($LASTEXITCODE -eq 12) 'consumed receipt was accepted a second time'
    Assert-True (($reuseOutput -join "`n") -match 'decision_receipt_already_consumed') 'receipt reuse failure reason was not precise'
    Assert-True (@(Get-ChildItem -LiteralPath $legalDir -Filter 'DECISION-*.json' -File).Count -eq 1) 'receipt reuse wrote a second DECISION'

    # Re-escalating the same task_id must bind a decision to the newest event.
    $multiId = 'test-multiple-escalation-generations'
    $oldCreatedAt = [DateTimeOffset]::Now.AddMinutes(-10)
    $newCreatedAt = [DateTimeOffset]::Now.AddMinutes(-1)
    $multiDir = New-Escalation $multiId $oldCreatedAt
    Write-Json (Join-Path $multiDir 'EVENT-new.json') ([ordered]@{
        task_id=$multiId; source='revision_limit'; reason='new generation'
        created_at=$newCreatedAt.ToString('o'); status='awaiting_josh'
    })
    $multiReceipt = New-SignedReceipt $multiId modify 'host\josh' local_owner_token multi-request
    $multiOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $decider `
        -TaskId $multiId -Decision modify -ActorId 'host\josh' -AuthMethod local_owner_token `
        -RequestId multi-request -ReceiptPath $multiReceipt -AgentOSRoot $testRoot 2>&1
    Assert-True ($LASTEXITCODE -eq 0) 'decision for multiple escalation generations was rejected'
    $multiDecisionPath = (Get-ChildItem -LiteralPath $multiDir -Filter 'DECISION-*.json' -File | Select-Object -First 1).FullName
    $multiDecision = Get-Content -Raw -LiteralPath $multiDecisionPath -Encoding UTF8 | ConvertFrom-Json
    Assert-True (
        [DateTimeOffset]::Parse([string]$multiDecision.escalation_created_at) -eq $newCreatedAt
    ) 'decision did not bind to newest escalation generation'

    # Queue must regard an unreceipted DECISION as awaiting_josh and not advance.
    $queueId = 'test-queue-invalid-decision'
    $queueDir = New-Escalation $queueId ([DateTimeOffset]::Now.AddMinutes(-1))
    Write-Json (Join-Path $queueDir 'DECISION-legacy.json') ([ordered]@{
        task_id=$queueId; decision='approve'; decided_by='Josh'
        authentication_method='current_chat_explicit_instruction'; request_id='legacy'; decided_at=(Get-Date -Format o)
    })
    $runner = Join-Path $testRoot 'scripts\task_queue_runner.ps1'
    $queueOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner `
        -AgentOSRoot $testRoot -RootDispatchId $queueId -ValidateOnly 2>&1
    Assert-True ($LASTEXITCODE -eq 22) 'queue validation did not block invalid DECISION'
    Assert-True (($queueOutput -join "`n") -match 'reason=escalation_decision_receipt_invalid:decision_receipt_missing') 'queue invalid DECISION reason was not precise'

    $validQueueOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner `
        -AgentOSRoot $testRoot -RootDispatchId $legalId -ValidateOnly 2>&1
    Assert-True ($LASTEXITCODE -eq 0 -and ($validQueueOutput -join "`n") -match 'queue_validation=passed') 'queue rejected verified owner decision'

    # Stored decisions remain verifiable after their short-lived receipt expires,
    # provided decided_at was inside the original receipt window.
    $expiredId = 'test-stored-expired-receipt'
    $expiredDir = New-Escalation $expiredId ([DateTimeOffset]::Now.AddMinutes(-10))
    $issued = [DateTimeOffset]::Now.AddMinutes(-5)
    $expires = $issued.AddMinutes(1)
    $expiredReceipt = New-SignedReceipt $expiredId approve 'host\josh' local_owner_token expired-request $issued $expires
    Write-Json (Join-Path $expiredDir 'DECISION-stored.json') ([ordered]@{
        schema_version='2'; task_id=$expiredId; decision='approve'; note='stored'
        decided_by='host\josh'; authentication_method='local_owner_token'; request_id='expired-request'
        decided_at=$issued.AddSeconds(30).ToString('o'); suspicious_fast_decision=$false
        receipt=[ordered]@{path=$expiredReceipt; sha256=(Get-FileHash -LiteralPath $expiredReceipt -Algorithm SHA256).Hash}
    })
    $expiredQueueOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner `
        -AgentOSRoot $testRoot -RootDispatchId $expiredId -ValidateOnly 2>&1
    Assert-True ($LASTEXITCODE -eq 0 -and ($expiredQueueOutput -join "`n") -match 'queue_validation=passed') 'stored decision became invalid after receipt expiry'

    foreach ($path in $historyBefore.Keys) {
        Assert-True ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -eq $historyBefore[$path]) "historical escalation changed: $path"
    }
} finally {
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}

if ($failures.Count) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Output 'escalation_decision_hardening=PASS'
Write-Output 'no_receipt_rejected=true'
Write-Output 'forged_method_rejected=true'
Write-Output 'verified_owner_receipt_accepted=true'
Write-Output 'receipt_reuse_rejected=true'
Write-Output 'queue_invalid_decision_awaiting_josh=true'
Write-Output 'stored_decision_survives_receipt_expiry=true'
Write-Output 'historical_escalation_hashes_unchanged=true'

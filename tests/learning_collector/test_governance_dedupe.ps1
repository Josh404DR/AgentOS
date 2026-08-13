[CmdletBinding()]
param([string]$AgentOSRoot = "E:\AgentOS")

$ErrorActionPreference = 'Stop'
$collector = Join-Path $AgentOSRoot 'scripts\collect_learning_candidates.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("agentos-learning-dedupe-" + [guid]::NewGuid().ToString('N'))
$utf8 = [Text.UTF8Encoding]::new($false)

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Write-Lines([string]$Path, [string[]]$Lines) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
    [IO.File]::WriteAllText($Path, ($Lines -join "`n") + "`n", $utf8)
}

function Invoke-TestCollector([string]$CaseRoot, [string]$MetricsPath, [switch]$DryRun) {
    $args = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $collector,
        '-AgentOSRoot', $AgentOSRoot,
        '-MetricsLogPath', $MetricsPath,
        '-EscalationIndexPath', (Join-Path $CaseRoot 'escalations\ESCALATION_INDEX.jsonl'),
        '-EscalationDir', (Join-Path $CaseRoot 'escalations'),
        '-CandidateDir', (Join-Path $CaseRoot 'candidates'),
        '-Threshold', '2'
    )
    if ($DryRun) { $args += '-DryRun' }
    $output = & powershell.exe @args 2>&1
    if ($LASTEXITCODE -ne 0) { throw ($output -join "`n") }
    return @($output | ForEach-Object { "$_" })
}

try {
    New-Item -ItemType Directory -Force -Path $testRoot | Out-Null

    # Case 1: a governance escalation persists dedupe_key in its canonical index.
    $case1 = Join-Path $testRoot 'persistent-index'
    $metrics1 = Join-Path $case1 'metrics.jsonl'
    $index1 = Join-Path $case1 'escalations\ESCALATION_INDEX.jsonl'
    Write-Lines $metrics1 @(
        '{"task_id":"gov-a","fail_reason":"routing_policy_regression","retry_count":0,"recorded_at":"2026-07-21T00:00:00+08:00"}',
        '{"task_id":"gov-b","fail_reason":"routing_policy_regression","retry_count":0,"recorded_at":"2026-07-21T00:01:00+08:00"}'
    )
    Write-Lines $index1 @()
    $first = Invoke-TestCollector $case1 $metrics1
    Assert-True (($first -join "`n") -match 'governance_escalation_created') 'first governance run did not create escalation'
    $eventFiles1 = @(Get-ChildItem (Join-Path $case1 'escalations') -Recurse -File -Filter '*.json')
    Assert-True ($eventFiles1.Count -eq 1) "first governance run created unexpected event count: $($eventFiles1.Count)"
    $indexEntries1 = @(Get-Content $index1 -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
    Assert-True ($indexEntries1.Count -eq 1) "first governance run created unexpected index count: $($indexEntries1.Count)"
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$indexEntries1[0].dedupe_key)) 'governance escalation index omitted dedupe_key'
    $eventHash1 = (Get-FileHash $eventFiles1[0].FullName -Algorithm SHA256).Hash
    $indexHash1 = (Get-FileHash $index1 -Algorithm SHA256).Hash

    $second = Invoke-TestCollector $case1 $metrics1
    Assert-True (($second -join "`n") -match 'skip_duplicate') 'second governance run did not report skip_duplicate'
    Assert-True (($second -join "`n") -match 'governance_escalations=0') 'second governance run created another escalation'
    Assert-True (@(Get-ChildItem (Join-Path $case1 'escalations') -Recurse -File -Filter '*.json').Count -eq 1) 'second governance run added event file'
    Assert-True ((Get-FileHash $eventFiles1[0].FullName -Algorithm SHA256).Hash -eq $eventHash1) 'second governance run changed existing event'
    Assert-True ((Get-FileHash $index1 -Algorithm SHA256).Hash -eq $indexHash1) 'second governance run changed escalation index'

    # Case 2: even with no dedupe_key/index hit, an existing task event blocks writes.
    $case2 = Join-Path $testRoot 'directory-guard'
    $metrics2 = Join-Path $case2 'metrics.jsonl'
    $index2 = Join-Path $case2 'escalations\ESCALATION_INDEX.jsonl'
    Write-Lines $metrics2 @(
        '{"task_id":"guard-a","fail_reason":"security_policy_fixture","retry_count":0,"recorded_at":"2026-07-21T00:00:00+08:00"}',
        '{"task_id":"guard-b","fail_reason":"security_policy_fixture","retry_count":0,"recorded_at":"2026-07-21T00:01:00+08:00"}'
    )
    Write-Lines $index2 @()
    $dry = Invoke-TestCollector $case2 $metrics2 -DryRun
    $candidateMatch = [regex]::Match(($dry -join "`n"), 'candidate_id=(LC-[A-Za-z0-9-]+)')
    Assert-True $candidateMatch.Success 'could not derive governance candidate id for directory guard fixture'
    $taskId2 = 'learning-candidate-' + $candidateMatch.Groups[1].Value
    $existingDir2 = Join-Path $case2 (Join-Path 'escalations' $taskId2)
    New-Item -ItemType Directory -Force -Path $existingDir2 | Out-Null
    $existingEvent2 = Join-Path $existingDir2 'EXISTING.json'
    [IO.File]::WriteAllText($existingEvent2, '{"status":"awaiting_josh"}', $utf8)
    $existingHash2 = (Get-FileHash $existingEvent2 -Algorithm SHA256).Hash
    $indexHash2 = (Get-FileHash $index2 -Algorithm SHA256).Hash
    $guarded = Invoke-TestCollector $case2 $metrics2
    Assert-True (($guarded -join "`n") -match 'reason=existing_escalation_task_or_event') 'directory guard did not report precise duplicate reason'
    Assert-True (@(Get-ChildItem $existingDir2 -File -Filter '*.json').Count -eq 1) 'directory guard added another event'
    Assert-True ((Get-FileHash $existingEvent2 -Algorithm SHA256).Hash -eq $existingHash2) 'directory guard changed existing event'
    Assert-True ((Get-FileHash $index2 -Algorithm SHA256).Hash -eq $indexHash2) 'directory guard changed escalation index'

    # Case 3: the established general candidate index dedupe remains intact.
    $case3 = Join-Path $testRoot 'general-candidate'
    $metrics3 = Join-Path $case3 'metrics.jsonl'
    $index3 = Join-Path $case3 'escalations\ESCALATION_INDEX.jsonl'
    Write-Lines $metrics3 @(
        '{"task_id":"impl-a","fail_reason":"verify_output_missing","retry_count":0,"recorded_at":"2026-07-21T00:00:00+08:00"}',
        '{"task_id":"impl-b","fail_reason":"verify_output_missing","retry_count":0,"recorded_at":"2026-07-21T00:01:00+08:00"}'
    )
    Write-Lines $index3 @()
    $null = Invoke-TestCollector $case3 $metrics3
    $candidateFiles3 = @(Get-ChildItem (Join-Path $case3 'candidates') -File -Filter 'LC-*.json')
    $candidateIndex3 = Join-Path $case3 'candidates\LEARNING_CANDIDATE_INDEX.jsonl'
    $candidateHash3 = (Get-FileHash $candidateFiles3[0].FullName -Algorithm SHA256).Hash
    $candidateIndexHash3 = (Get-FileHash $candidateIndex3 -Algorithm SHA256).Hash
    $generalSecond = Invoke-TestCollector $case3 $metrics3
    Assert-True (($generalSecond -join "`n") -match 'skip_duplicate') 'general candidate second run did not skip duplicate'
    Assert-True (@(Get-ChildItem (Join-Path $case3 'candidates') -File -Filter 'LC-*.json').Count -eq 1) 'general candidate second run added candidate'
    Assert-True ((Get-FileHash $candidateFiles3[0].FullName -Algorithm SHA256).Hash -eq $candidateHash3) 'general candidate second run changed candidate'
    Assert-True ((Get-FileHash $candidateIndex3 -Algorithm SHA256).Hash -eq $candidateIndexHash3) 'general candidate second run changed candidate index'

    Write-Output 'learning_governance_dedupe=PASS'
    Write-Output 'governance_second_run_skip_duplicate=true'
    Write-Output 'escalation_index_persists_dedupe_key=true'
    Write-Output 'existing_event_directory_guard=true'
    Write-Output 'general_candidate_dedupe_regression=true'
} finally {
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}

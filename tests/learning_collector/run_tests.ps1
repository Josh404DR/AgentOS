#Requires -Version 5.1
# run_tests.ps1 — Learning Collector Test Suite
# Tests all five acceptance criteria for collect_learning_candidates.ps1.
# No model calls. No external services. Runs entirely on fixture data.

[CmdletBinding()]
param(
    [string]$AgentOSRoot      = "E:\AgentOS",
    [string]$CollectorScript  = ""
)

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

$root = (Resolve-Path -LiteralPath $AgentOSRoot).Path
if (-not $CollectorScript) {
    $CollectorScript = Join-Path $root "scripts\collect_learning_candidates.ps1"
}
$fixtureDir = Join-Path $root "tests\learning_collector\fixtures"

# ── Test harness helpers ───────────────────────────────────────────────────
$testsPassed = 0
$testsFailed = 0

function Assert-True {
    param($Condition, [string]$Message)
    $boolCond = $false
    if ($Condition -is [bool]) {
        $boolCond = $Condition
    } elseif ($Condition -is [System.Array]) {
        $boolCond = ($Condition.Count -gt 0)
    } elseif ($Condition -is [string]) {
        $boolCond = (-not [string]::IsNullOrEmpty($Condition))
    } elseif ($null -ne $Condition) {
        $boolCond = $true
    }
    if ($boolCond) {
        Write-Output "  PASS: $Message"
        $script:testsPassed++
    } else {
        Write-Output "  FAIL: $Message"
        $script:testsFailed++
    }
}

function Assert-False {
    param($Condition, [string]$Message)
    $boolCond = $false
    if ($Condition -is [bool]) {
        $boolCond = $Condition
    } elseif ($Condition -is [System.Array]) {
        $boolCond = ($Condition.Count -gt 0)
    } elseif ($Condition -is [string]) {
        $boolCond = (-not [string]::IsNullOrEmpty($Condition))
    } elseif ($null -ne $Condition) {
        $boolCond = $true
    }
    Assert-True -Condition (-not $boolCond) -Message $Message
}

function New-TempDir {
    $path = Join-Path ([System.IO.Path]::GetTempPath()) ("lc_test_" + [System.Guid]::NewGuid().ToString("N"))
    $null = New-Item -ItemType Directory -Path $path -Force
    return $path
}

function Remove-TempDir {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-Collector {
    param(
        [string]$MetricsPath,
        [string]$EscalationIndexPath,
        [string]$EscalationDir,
        [string]$CandidateDir,
        [int]$Threshold = 2,
        [switch]$DryRun
    )
    $args = @(
        "-File", $CollectorScript,
        "-AgentOSRoot", $root,
        "-MetricsLogPath", $MetricsPath,
        "-EscalationIndexPath", $EscalationIndexPath,
        "-EscalationDir", $EscalationDir,
        "-CandidateDir", $CandidateDir,
        "-Threshold", $Threshold
    )
    if ($DryRun) { $args += "-DryRun" }
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass @args 2>&1
    return $output
}

function Get-CandidateFiles {
    param([string]$Dir)
    if (-not (Test-Path -LiteralPath $Dir)) { return @() }
    return @(Get-ChildItem -LiteralPath $Dir -Filter "LC-*.json" -File)
}

function Get-EscalationFiles {
    param([string]$Dir)
    if (-not (Test-Path -LiteralPath $Dir)) { return @() }
    return @(Get-ChildItem -LiteralPath $Dir -Filter "*.json" -File -Recurse |
        Where-Object { $_.DirectoryName -ne $Dir })
}

# Empty escalation index for tests that don't need escalation data
$emptyEscIndexPath = Join-Path ([System.IO.Path]::GetTempPath()) ("lc_empty_esc_" + [System.Guid]::NewGuid().ToString("N") + ".jsonl")
Set-Content -LiteralPath $emptyEscIndexPath -Value "" -Encoding UTF8

# Fixture paths
$fixtureEscDir        = Join-Path $fixtureDir "escalations"
$fixtureEscIndexPath  = Join-Path $fixtureEscDir "ESCALATION_INDEX.jsonl"
$singleFailMetrics    = Join-Path $fixtureDir "metrics_single_fail.jsonl"
$thresholdFailMetrics = Join-Path $fixtureDir "metrics_threshold_fail.jsonl"
$governanceMetrics    = Join-Path $fixtureDir "metrics_governance_fail.jsonl"

Write-Output "============================================================"
Write-Output "Learning Collector Test Suite"
Write-Output "collector: $CollectorScript"
Write-Output "fixtures:  $fixtureDir"
Write-Output "============================================================"

# ── TEST 1: Single failure does not create a candidate ────────────────────
Write-Output ""
Write-Output "TEST 1: Single failure does not create a candidate"
$tmp1 = New-TempDir
$escTmp1 = New-TempDir
try {
    $output1 = Invoke-Collector -MetricsPath $singleFailMetrics `
        -EscalationIndexPath $emptyEscIndexPath `
        -EscalationDir $escTmp1 `
        -CandidateDir $tmp1 `
        -Threshold 2
    $output1 | ForEach-Object { Write-Output "  $_" }
    $candidates1 = Get-CandidateFiles -Dir $tmp1
    Assert-True  -Condition ($candidates1.Count -eq 0)   -Message "No candidate created for single failure (got $($candidates1.Count))"
    Assert-True  -Condition ($output1 -match "skip_low_frequency") -Message "Output reports skip_low_frequency"
    Assert-False -Condition ($output1 -match "candidate_created:") -Message "No candidate_created line in output"
} finally {
    Remove-TempDir $tmp1; Remove-TempDir $escTmp1
}

# ── TEST 2: Repeated failures meeting threshold create a candidate ─────────
Write-Output ""
Write-Output "TEST 2: Repeated failures meeting threshold create a candidate"
$tmp2 = New-TempDir
$escTmp2 = New-TempDir
try {
    $output2 = Invoke-Collector -MetricsPath $thresholdFailMetrics `
        -EscalationIndexPath $emptyEscIndexPath `
        -EscalationDir $escTmp2 `
        -CandidateDir $tmp2 `
        -Threshold 2
    $output2 | ForEach-Object { Write-Output "  $_" }
    $candidates2 = Get-CandidateFiles -Dir $tmp2
    Assert-True -Condition ($candidates2.Count -ge 1) -Message "At least one candidate created (got $($candidates2.Count))"
    Assert-True -Condition ($output2 -match "candidate_created:") -Message "Output reports candidate_created"
    Assert-True -Condition ($output2 -match "candidates_created=\d+") -Message "Summary line present"
} finally {
    Remove-TempDir $tmp2; Remove-TempDir $escTmp2
}

# ── TEST 3: Candidate has all required fields ──────────────────────────────
Write-Output ""
Write-Output "TEST 3: Candidate contains all required schema fields"
$tmp3 = New-TempDir
$escTmp3 = New-TempDir
try {
    $null = Invoke-Collector -MetricsPath $thresholdFailMetrics `
        -EscalationIndexPath $emptyEscIndexPath `
        -EscalationDir $escTmp3 `
        -CandidateDir $tmp3 `
        -Threshold 2
    $candidateFiles3 = Get-CandidateFiles -Dir $tmp3
    Assert-True -Condition ($candidateFiles3.Count -ge 1) -Message "At least one candidate file exists"
    if ($candidateFiles3.Count -ge 1) {
        $c = Get-Content -Raw -LiteralPath $candidateFiles3[0].FullName -Encoding UTF8 | ConvertFrom-Json
        $requiredFields = @(
            "candidate_id","schema_version","created_at","collector_version",
            "governance_version","governance_hash","source_task_ids","source_evidence_paths",
            "failure_reason_key","failure_reason_examples","frequency","threshold",
            "retry_evidence","resolved_evidence","impact","recommendation",
            "change_class","josh_approval_status","dedupe_key","status"
        )
        foreach ($field in $requiredFields) {
            Assert-True -Condition ($null -ne $c.PSObject.Properties[$field]) -Message "Field present: $field"
        }
        Assert-True -Condition ($c.frequency -ge 2)                    -Message "frequency >= threshold (got $($c.frequency))"
        Assert-True -Condition ($c.threshold -eq 2)                    -Message "threshold recorded as 2"
        Assert-True -Condition ($c.source_task_ids.Count -ge 1)        -Message "source_task_ids not empty"
        Assert-True -Condition ($c.josh_approval_status -eq "pending") -Message "josh_approval_status is pending"
        Assert-True -Condition ($c.status -eq "open")                  -Message "status is open"
        Assert-True -Condition ($c.change_class -in @("implementation_change","governance_change")) -Message "change_class is valid"
        Assert-True -Condition (-not [string]::IsNullOrWhiteSpace($c.dedupe_key)) -Message "dedupe_key not empty"
        Assert-True -Condition (-not [string]::IsNullOrWhiteSpace($c.recommendation)) -Message "recommendation not empty"
    }
} finally {
    Remove-TempDir $tmp3; Remove-TempDir $escTmp3
}

# ── TEST 4: Already resolved evidence does not create duplicate candidates ─
Write-Output ""
Write-Output "TEST 4: Second run on same data does not create duplicate candidates"
$tmp4 = New-TempDir
$escTmp4 = New-TempDir
try {
    # First run
    $null = Invoke-Collector -MetricsPath $thresholdFailMetrics `
        -EscalationIndexPath $emptyEscIndexPath `
        -EscalationDir $escTmp4 `
        -CandidateDir $tmp4 `
        -Threshold 2
    $countAfterFirst = (Get-CandidateFiles -Dir $tmp4).Count

    # Second run (same input)
    $output4 = Invoke-Collector -MetricsPath $thresholdFailMetrics `
        -EscalationIndexPath $emptyEscIndexPath `
        -EscalationDir $escTmp4 `
        -CandidateDir $tmp4 `
        -Threshold 2
    $output4 | ForEach-Object { Write-Output "  $_" }
    $countAfterSecond = (Get-CandidateFiles -Dir $tmp4).Count

    Assert-True -Condition ($countAfterFirst -ge 1)                       -Message "First run created candidate(s)"
    Assert-True -Condition ($countAfterSecond -eq $countAfterFirst)       -Message "Second run did not add more candidates (first=$countAfterFirst second=$countAfterSecond)"
    Assert-True -Condition ($output4 -match "skip_duplicate")             -Message "Second run reports skip_duplicate"
    Assert-True -Condition ($output4 -match "skipped_duplicate=[1-9]")   -Message "Summary shows skipped_duplicate > 0"
} finally {
    Remove-TempDir $tmp4; Remove-TempDir $escTmp4
}

# ── TEST 4b: Resolved escalation evidence (RESOLUTION.json) is included ───
Write-Output ""
Write-Output "TEST 4b: Resolved escalation evidence loads and deduplicates"
$tmp4b = New-TempDir
try {
    # Use the escalation fixture that has 2 RESOLUTION.json files
    # Both have reason "codex_verify_needs_human_decision" -> should create 1 candidate
    $emptyMetrics = Join-Path ([System.IO.Path]::GetTempPath()) ("lc_empty_m_" + [System.Guid]::NewGuid().ToString("N") + ".jsonl")
    Set-Content -LiteralPath $emptyMetrics -Value "" -Encoding UTF8

    $output4b = Invoke-Collector -MetricsPath $emptyMetrics `
        -EscalationIndexPath $fixtureEscIndexPath `
        -EscalationDir $fixtureEscDir `
        -CandidateDir $tmp4b `
        -Threshold 2
    $output4b | ForEach-Object { Write-Output "  $_" }
    $candidates4b = Get-CandidateFiles -Dir $tmp4b
    Assert-True -Condition ($candidates4b.Count -ge 1)           -Message "Resolved escalation events produce candidate"
    Assert-True -Condition ($output4b -match "resolved_escalation_events_loaded=2") -Message "2 resolved escalation events loaded"

    if ($candidates4b.Count -ge 1) {
        $c4b = Get-Content -Raw -LiteralPath $candidates4b[0].FullName -Encoding UTF8 | ConvertFrom-Json
        Assert-True -Condition ($c4b.resolved_evidence.Count -ge 2) -Message "Candidate has 2 resolved_evidence entries"
    }

    # Second run: should deduplicate
    $output4b2 = Invoke-Collector -MetricsPath $emptyMetrics `
        -EscalationIndexPath $fixtureEscIndexPath `
        -EscalationDir $fixtureEscDir `
        -CandidateDir $tmp4b `
        -Threshold 2
    $countAfter2 = (Get-CandidateFiles -Dir $tmp4b).Count
    Assert-True -Condition ($countAfter2 -eq $candidates4b.Count) -Message "No new candidates on second run (dedup works for escalation evidence)"

    Remove-Item -LiteralPath $emptyMetrics -Force -ErrorAction SilentlyContinue
} finally {
    Remove-TempDir $tmp4b
}

# ── TEST 5: Governance-affecting reasons go to escalation, not candidate files
Write-Output ""
Write-Output "TEST 5: Governance-affecting failure reasons route to escalation"
$tmp5 = New-TempDir
$escTmp5 = New-TempDir
try {
    # Capture AGENTS.md hash before running collector
    $agentsMd = Join-Path $root "AGENTS.md"
    $agentsHashBefore = (Get-FileHash -LiteralPath $agentsMd -Algorithm SHA256).Hash
    $output5 = Invoke-Collector -MetricsPath $governanceMetrics `
        -EscalationIndexPath $emptyEscIndexPath `
        -EscalationDir $escTmp5 `
        -CandidateDir $tmp5 `
        -Threshold 2
    $output5 | ForEach-Object { Write-Output "  $_" }
    # Capture AGENTS.md hash after running collector
    $agentsHashAfter = (Get-FileHash -LiteralPath $agentsMd -Algorithm SHA256).Hash
    $candidates5 = Get-CandidateFiles -Dir $tmp5
    # No candidate files should exist for governance_change
    Assert-True  -Condition ($candidates5.Count -eq 0)                          -Message "No candidate files for governance_change (got $($candidates5.Count))"
    Assert-True  -Condition ($output5 -match "governance_escalation_created")   -Message "Output reports governance_escalation_created"
    Assert-True  -Condition ($output5 -match "governance_escalations=[1-9]")    -Message "Summary shows governance_escalations > 0"
    # Verify no governance files were modified (before/after comparison, no hardcoded hash)
    Assert-True -Condition ($agentsHashAfter -eq $agentsHashBefore) `
        -Message "AGENTS.md not modified by collector (before=$($agentsHashBefore.Substring(0,16))... after=$($agentsHashAfter.Substring(0,16))...)"
    # Verify escalation artifact was created
    $escFiles5 = Get-EscalationFiles -Dir $escTmp5
    Assert-True -Condition ($escFiles5.Count -ge 1) -Message "Escalation artifact file created in EscalationDir"
    if ($escFiles5.Count -ge 1) {
        $esc5 = Get-Content -Raw -LiteralPath $escFiles5[0].FullName -Encoding UTF8 | ConvertFrom-Json
        Assert-True -Condition ($esc5.status -eq "awaiting_josh")          -Message "Escalation status is awaiting_josh"
        Assert-True -Condition ($esc5.source -eq "learning_candidate_governance") -Message "Escalation source is learning_candidate_governance"
        Assert-True -Condition ($null -ne $esc5.candidate)                 -Message "Escalation artifact contains candidate object"
    }
} finally {
    Remove-TempDir $tmp5; Remove-TempDir $escTmp5
}

# ── TEST 6: SHA-256 regression — distinct failure reasons yield distinct dedupe_keys
Write-Output ""
Write-Output "TEST 6: SHA-256 regression — distinct failure reasons yield distinct dedupe_keys"
$tmp6 = New-TempDir
$esc6 = New-TempDir
$m6   = Join-Path ([System.IO.Path]::GetTempPath()) ("lc_m6_" + [System.Guid]::NewGuid().ToString("N") + ".jsonl")
try {
    # Two non-governance reasons, each with 2 occurrences -> 2 distinct candidate files
    @(
        '{"task_id":"r6-a1","fail_reason":"verify_output_missing","retry_count":0,"recorded_at":"2026-07-06T00:00:00+08:00"}',
        '{"task_id":"r6-a2","fail_reason":"verify_output_missing","retry_count":0,"recorded_at":"2026-07-06T00:01:00+08:00"}',
        '{"task_id":"r6-b1","fail_reason":"sandbox_blocks_file_io","retry_count":0,"recorded_at":"2026-07-06T00:02:00+08:00"}',
        '{"task_id":"r6-b2","fail_reason":"sandbox_blocks_file_io","retry_count":0,"recorded_at":"2026-07-06T00:03:00+08:00"}'
    ) | Set-Content -LiteralPath $m6 -Encoding UTF8

    $out6 = Invoke-Collector -MetricsPath $m6 `
        -EscalationIndexPath $emptyEscIndexPath `
        -EscalationDir $esc6 `
        -CandidateDir $tmp6 `
        -Threshold 2
    $out6 | ForEach-Object { Write-Output "  $_" }

    $f6 = Get-CandidateFiles -Dir $tmp6
    Assert-True -Condition ($f6.Count -eq 2) `
        -Message "Two distinct failure reasons produce two separate candidates (got $($f6.Count))"

    if ($f6.Count -eq 2) {
        $ca       = Get-Content -Raw -LiteralPath $f6[0].FullName -Encoding UTF8 | ConvertFrom-Json
        $cb       = Get-Content -Raw -LiteralPath $f6[1].FullName -Encoding UTF8 | ConvertFrom-Json
        $emptyHash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
        Assert-True  -Condition ($ca.dedupe_key -ne $cb.dedupe_key) `
            -Message "Different failure reasons produce distinct dedupe_keys (not collapsed by dollar-Input bug)"
        Assert-False -Condition ($ca.dedupe_key -eq $emptyHash) `
            -Message "First candidate dedupe_key is not the empty-string SHA-256 (e3b0c442)"
        Assert-False -Condition ($cb.dedupe_key -eq $emptyHash) `
            -Message "Second candidate dedupe_key is not the empty-string SHA-256 (e3b0c442)"
    }
} finally {
    Remove-TempDir $tmp6; Remove-TempDir $esc6
    Remove-Item -LiteralPath $m6 -Force -ErrorAction SilentlyContinue
}

# ── Cleanup empty file ─────────────────────────────────────────────────────
Remove-Item -LiteralPath $emptyEscIndexPath -Force -ErrorAction SilentlyContinue

# ── Results ────────────────────────────────────────────────────────────────
Write-Output ""
Write-Output "============================================================"
Write-Output "RESULTS: passed=$testsPassed  failed=$testsFailed  total=$($testsPassed + $testsFailed)"
Write-Output "============================================================"
if ($testsFailed -gt 0) {
    Write-Output "TEST_SUITE_RESULT=FAIL"
    exit 1
} else {
    Write-Output "TEST_SUITE_RESULT=PASS"
    exit 0
}

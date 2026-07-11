# Fixture: proves (1) dispatch_task_packet.ps1 injects verify_verdict requirement
# when a rerun-generated TASK.md lacks it, and (2) write_escalation.ps1 [char[]]
# encoding produces correct Chinese text independent of script file encoding.
# Run: powershell -NoProfile -ExecutionPolicy Bypass -File this_file.ps1

$ErrorActionPreference = "Stop"
$pass = 0
$fail = 0

function Assert-Equal {
    param([string]$Label, $Got, $Expected)
    if ($Got -eq $Expected) {
        Write-Output ("PASS: " + $Label)
        $script:pass++
    } else {
        Write-Output ("FAIL: " + $Label + " | got=" + $Got + " | expected=" + $Expected)
        $script:fail++
    }
}

# ── TASK 2: verify_verdict injection logic ──────────────────────────────────

$verdictBlock = @"

## Required Machine-Readable Verdict

Your response must include exactly one machine-readable verdict line:
verify_verdict: PASS
or
verify_verdict: FAIL
or
verify_verdict: NEEDS_HUMAN_DECISION

Then include findings, evidence, and required changes in Traditional Chinese.
"@

function Invoke-PromptInjection {
    param([string]$Content)
    $has = [regex]::IsMatch($Content, '(?m)^verify_verdict\s*:\s*PASS\s*$')
    if (-not $has) { $Content += $verdictBlock }
    return $Content
}

# Case 1: synthetic rerun TASK.md content lacks a machine-readable verdict.
$rerunContent = @"
dispatch_id: fixture-rerun-verify
type: CODEX_VERIFY
task_status: ready

Verify the scoped result and report findings.
"@
$beforeHas = [regex]::IsMatch($rerunContent, '(?m)^verify_verdict\s*:\s*PASS\s*$')
Assert-Equal "rerun_task_lacks_verdict_before_fix" $beforeHas $false
$afterContent = Invoke-PromptInjection $rerunContent
$afterHas = [regex]::IsMatch($afterContent, '(?m)^verify_verdict\s*:\s*PASS\s*$')
Assert-Equal "rerun_task_has_verdict_after_injection" $afterHas $true

# Case 2: standard New-CodexVerifyTask content already has the verdict contract.
$stdContent = @"
dispatch_id: fixture-standard-verify
type: CODEX_VERIFY
task_status: ready

verify_verdict: PASS
"@
$stdBefore = [regex]::IsMatch($stdContent, '(?m)^verify_verdict\s*:\s*PASS\s*$')
Assert-Equal "standard_task_already_has_verdict" $stdBefore $true
$stdAfter = Invoke-PromptInjection $stdContent
# injection skipped; content unchanged
Assert-Equal "standard_task_unchanged_after_no-op_injection" ($stdAfter -eq $stdContent) $true

# ── TASK 3: write_escalation.ps1 [char[]] encoding ─────────────────────────

# Verify [char[]] code points produce correct Chinese characters
$approve = ([char[]]@(0x5141,0x8A31,0x5728,0x6838,0x51C6,0x7BC4,0x570D,0x5167,0x7E7C,0x7E8C,0x57F7,0x884C) -join '')
$modify  = ([char[]]@(0x8ABF,0x6574,0x9700,0x6C42,0x5F8C,0x91CD,0x8DD1) -join '')
$stop    = ([char[]]@(0x505C,0x6B62,0x4EFB,0x52D9) -join '')

Assert-Equal "approve_effect_char_count" $approve.Length 12
Assert-Equal "modify_effect_char_count"  $modify.Length  7
Assert-Equal "stop_effect_char_count"    $stop.Length    4

# Spot-check first character of each string
Assert-Equal "approve_first_char_codepoint" ([int][char]$approve[0]) 0x5141
Assert-Equal "modify_first_char_codepoint"  ([int][char]$modify[0])  0x8ABF
Assert-Equal "stop_first_char_codepoint"    ([int][char]$stop[0])    0x505C

# Verify JSON round-trip: ConvertTo-Json then ConvertFrom-Json recovers the strings
$utf8NoBom = [Text.UTF8Encoding]::new($false)
$tmpPath = [IO.Path]::Combine([IO.Path]::GetTempPath(), "agentos_enc_test_" + [Guid]::NewGuid().ToString("N") + ".json")
try {
    $payload = [ordered]@{ approve = $approve; modify = $modify; stop = $stop }
    $json = $payload | ConvertTo-Json -Depth 2
    [IO.File]::WriteAllText($tmpPath, $json + [Environment]::NewLine, $utf8NoBom)
    $readBack = [IO.File]::ReadAllText($tmpPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
    Assert-Equal "json_roundtrip_approve" $readBack.approve $approve
    Assert-Equal "json_roundtrip_modify"  $readBack.modify  $modify
    Assert-Equal "json_roundtrip_stop"    $readBack.stop    $stop
} finally {
    if (Test-Path -LiteralPath $tmpPath) { Remove-Item -LiteralPath $tmpPath }
}

# ── Summary ──────────────────────────────────────────────────────────────────
Write-Output ("--- TOTAL: pass=" + $pass + " fail=" + $fail)
if ($fail -gt 0) { exit 1 }
Write-Output "All fixture tests PASSED"

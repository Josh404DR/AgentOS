# test_result_chain_upgrade.ps1
# Replay tests for the result-chain upgrade (phases 1a, 1b, 2, 3, 4).
# Read-only: no model calls, no workspace mutation, no external services.
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test_result_chain_upgrade.ps1
# Exit code 0 = all pass; 1 = at least one failure.

[CmdletBinding()]
param([string]$AgentOSRoot = "E:\AgentOS")

$ErrorActionPreference = "Stop"
$script:failures = 0
$script:passes = 0

function Assert-True([bool]$Condition, [string]$Name) {
    if ($Condition) { $script:passes++; Write-Output "PASS: $Name" }
    else { $script:failures++; Write-Output "FAIL: $Name" }
}

function Read-Utf8([string]$Path) {
    return [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
}

$tasksRoot = Join-Path $AgentOSRoot "data\codex_tasks"
$id1313 = "telegram-telegram-1449022024-1313-20260712-223356-135714"
$id1316 = "telegram-telegram-1449022024-1316-20260712-224256-818149"

# --- T1: Phase 1b relaxed change_required parsing on the 1316 fixture ---
$fixture1316 = Join-Path $tasksRoot "$id1316\OUTPUTS\RESULT.md"
$text1316 = Read-Utf8 $fixture1316
$oldRegex = '(?mi)^change_required\s*:\s*(true|false)\s*$'
$newRegex = '(?mi)^[\s>*_-]*change_required\s*[:\uFF1A]\s*\*{0,2}(true|false)\b'
$oldMatch = [regex]::Match($text1316, $oldRegex)
$newMatch = [regex]::Match($text1316, $newRegex)
Assert-True (-not $oldMatch.Success) "T1a old regex falls through on 1316 fixture (documents the bug)"
Assert-True ($newMatch.Success -and ($newMatch.Groups[1].Value -ieq "false")) "T1b new regex resolves change_required=false on 1316 fixture"

# --- T2: Phase 1b/2 evidence extraction accepts decorated and evidence lines ---
$evidenceRegex = '(?mi)^[\s>*_-]*\*{0,2}(test_command|test_result|verification|evidence)\*{0,2}\s*[:\uFF1A]\s*(.+)$'
$sample = "**test_result**: PASS smoke`r`n> evidence: https://example.com checked`r`nevidence: books.com.tw manual lookup"
$evMatches = [regex]::Matches($sample, $evidenceRegex)
Assert-True ($evMatches.Count -eq 3) "T2 evidence regex extracts decorated test_result and evidence lines (got $($evMatches.Count)/3)"

# --- T3: Phase 3 classifier replay ---
$classifier = Join-Path $AgentOSRoot "scripts\classify_task.ps1"

function Get-JoshRequest([string]$TaskPath) {
    $text = Read-Utf8 $TaskPath
    $match = [regex]::Match($text, '(?s)## Josh Request\s*(.+?)\s*##\s')
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return ""
}

foreach ($id in @($id1313, $id1316)) {
    $msg = Get-JoshRequest (Join-Path $tasksRoot "$id\TASK.md")
    Assert-True ($msg.Length -gt 0) "T3 fixture message extracted for $id"
    $result = (& $classifier -MessageText $msg -AsJson) | ConvertFrom-Json
    Assert-True ($result.task_type -eq "INFO_QUERY") "T3 $id classifies as INFO_QUERY (got $($result.task_type))"
}

# Historical workspace_change replay: none may flip to INFO_QUERY.
$historical = @(Get-ChildItem -LiteralPath $tasksRoot -Directory |
    ForEach-Object {
        $p = Join-Path $_.FullName "TASK.md"
        if (Test-Path -LiteralPath $p -PathType Leaf) {
            $t = Read-Utf8 $p
            if ($t -match '(?mi)^task_kind\s*:\s*workspace_change\b' -and
                $_.Name -notlike "*1313*" -and $_.Name -notlike "*1316*" -and
                $_.Name -notmatch '-(codex-verify|revision-\d+)$') {
                [pscustomobject]@{ Path = $p; Time = $_.LastWriteTime }
            }
        }
    } | Sort-Object Time -Descending | Select-Object -First 10)
$flipped = 0
foreach ($h in $historical) {
    $msg = Get-JoshRequest $h.Path
    if (-not $msg) { continue }
    $result = (& $classifier -MessageText $msg -AsJson) | ConvertFrom-Json
    if ($result.task_type -eq "INFO_QUERY") {
        $flipped++
        Write-Output "  misfire: $($h.Path)"
    }
}
Assert-True ($historical.Count -ge 1) "T3 historical replay set found ($($historical.Count) packets)"
Assert-True ($flipped -eq 0) "T3 zero historical workspace_change packets flip to INFO_QUERY (flipped=$flipped)"

# --- T4: Phase 4 failure-pattern extraction replay ---
$garbledRegex = '\u4E82\u78BC|\u7121\u6CD5[\u53EF\u9760]{0,2}\u8FA8\u8B58|garbled|mojibake'
$verify1313 = Read-Utf8 (Join-Path $tasksRoot "$id1313-codex-verify\OUTPUTS\RESULT.md")
$verify1316 = Read-Utf8 (Join-Path $tasksRoot "$id1316-codex-verify\OUTPUTS\RESULT.md")
Assert-True ($verify1313 -match $garbledRegex) "T4a 1313 verify result matches garbled pattern"
Assert-True ($verify1316 -match $garbledRegex) "T4b 1316 verify result matches garbled pattern (cluster size 2 reached)"

# Misroute signature on a synthetic (garble-free) fixture
$misrouteTask = "task_kind: workspace_change"
$misrouteWorker = "change_required: false`r`nWebSearch tool not authorized for this worker."
Assert-True (($misrouteTask -match '(?mi)^task_kind\s*:\s*workspace_change\b') -and
    ($misrouteWorker -match '(?mi)^[\s>*_-]*change_required\s*[:\uFF1A]\s*\*{0,2}false\b') -and
    ($misrouteWorker -match 'WebSearch|\u7DB2\u8DEF\u641C\u5C0B|\u67E5\u8A62|\u641C\u5C0B')) "T4c misroute signature detects query-on-workspace-worker delivery"

# --- T5: Phase 1a chcp 65001 present in both launchers ---
$dispatcherText = Read-Utf8 (Join-Path $AgentOSRoot "scripts\dispatch_task_packet.ps1")
$chcpCount = ([regex]::Matches($dispatcherText, 'chcp 65001 >nul')).Count
Assert-True ($chcpCount -ge 2) "T5 chcp 65001 present in Codex and Claude launchers (found $chcpCount)"

Write-Output "---"
Write-Output "passes=$script:passes"
Write-Output "failures=$script:failures"
Write-Output "models_invoked=false"
Write-Output "external_services_invoked=false"
if ($script:failures -gt 0) { exit 1 }
exit 0

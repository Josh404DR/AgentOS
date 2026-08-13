# Phase 0: Workflow Metrics Baseline (ADR-0010, deterministic only — no LLM calls)
# Sources: data\metrics\METRICS_LOG.jsonl, data\queue_runs\*.json,
#          data\codex_tasks\ (directory census), data\escalations\ESCALATION_INDEX.jsonl
# Output:  data\metrics\BASELINE_<yyyyMMdd-HHmmss>.json + .md
# Quality: every metric is tagged measured|estimate; unknown stays unknown (no fabrication).

param(
    [string]$AgentOSRoot = "E:\AgentOS",
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
if (-not $OutputDir) { $OutputDir = Join-Path $AgentOSRoot "data\metrics" }
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

function Get-RootId([string]$Name) {
    $root = $Name
    $root = $root -replace '-codex-verify$', ''
    $root = $root -replace '-revision-\d+$', ''
    $root = $root -replace '-codex-verify$', ''   # revision-N-codex-verify needs a second pass
    $root = $root -replace '^\d{4}-\d{2}-\d{2}-url-intake-', ''
    return $root
}

# ---------- 1. METRICS_LOG.jsonl ----------
$metricsLogPath = Join-Path $AgentOSRoot "data\metrics\METRICS_LOG.jsonl"
$entries = @()
if (Test-Path -LiteralPath $metricsLogPath) {
    foreach ($line in (Get-Content -LiteralPath $metricsLogPath -Encoding UTF8)) {
        if (-not $line.Trim()) { continue }
        try { $entries += ($line | ConvertFrom-Json) } catch { continue }
    }
}
$totalLogged = $entries.Count
$firstPass = @($entries | Where-Object { $_.verdict -eq "PASS" -and [int]$_.retry_count -eq 0 }).Count
$loopCounts = @($entries | ForEach-Object { [int]$_.retry_count + 1 })
$escalatedInLog = @($entries | Where-Object { $_.escalation_required -eq $true }).Count

# ---------- 2. queue_runs latency ----------
$queueDir = Join-Path $AgentOSRoot "data\queue_runs"
$latencies = @()
if (Test-Path -LiteralPath $queueDir) {
    Get-ChildItem -LiteralPath $queueDir -Filter *.json -File -ErrorAction SilentlyContinue | ForEach-Object {
        try { $run = Get-Content -Raw -LiteralPath $_.FullName -Encoding UTF8 | ConvertFrom-Json } catch { return }
        if ($run.started_at -and $run.finished_at) {
            try {
                $seconds = ([datetime]$run.finished_at - [datetime]$run.started_at).TotalSeconds
                if ($seconds -ge 0) { $latencies += [double]$seconds }
            } catch { }
        }
    }
}

# ---------- 3. codex_tasks node census ----------
$tasksDir = Join-Path $AgentOSRoot "data\codex_tasks"
$nodeCounts = @{}
if (Test-Path -LiteralPath $tasksDir) {
    Get-ChildItem -LiteralPath $tasksDir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $root = Get-RootId $_.Name
        if ($nodeCounts.ContainsKey($root)) { $nodeCounts[$root] = $nodeCounts[$root] + 1 }
        else { $nodeCounts[$root] = 1 }
    }
}
$rootCount = $nodeCounts.Keys.Count
$nodeValues = @($nodeCounts.Values | ForEach-Object { [int]$_ })

# ---------- 4. escalations ----------
$escIndexPath = Join-Path $AgentOSRoot "data\escalations\ESCALATION_INDEX.jsonl"
$escalatedRoots = New-Object System.Collections.Generic.HashSet[string]
if (Test-Path -LiteralPath $escIndexPath) {
    foreach ($line in (Get-Content -LiteralPath $escIndexPath -Encoding UTF8)) {
        if (-not $line.Trim()) { continue }
        try { $item = $line | ConvertFrom-Json } catch { continue }
        if ($item.task_id) { [void]$escalatedRoots.Add((Get-RootId ([string]$item.task_id))) }
    }
}

# ---------- 5. heuristic scans (ESTIMATE quality) ----------
# false-fail candidates: verify verdicts of FAIL/NEEDS_HUMAN whose findings match
# known contract/encoding failure signatures (Failure Taxonomy: ENCODING_ERROR / CONTRACT_PARSE_ERROR)
# NOTE: CJK built from code points so this ASCII-only script survives any console codepage.
$luanMaT = [string][char]0x4E82 + [char]0x78BC          # garbled-text (traditional)
$luanMaS = [string][char]0x4E71 + [char]0x7801          # garbled-text (simplified)
$notAuth = [string][char]0x672A + [char]0x6388 + [char]0x6B0A  # not-authorized
$notOpen = [string][char]0x672A + [char]0x958B + [char]0x653E  # not-enabled
$noNet   = [string][char]0x7121 + [char]0x7DB2 + [char]0x8DEF  # no-network
$falseFailPattern = "($luanMaT|$luanMaS|CP950|test_status:\s*missing|change_required.*unknown|diff_status:\s*missing)"
# misroute candidates: worker RESULT admits missing web/tool access or out-of-scope routing
$misroutePattern = "(OUT OF SCOPE|WebSearch.{0,12}($notAuth|$notOpen)|$noNet)"
$verifyTotal = 0; $verifyFail = 0; $falseFailCandidates = 0
$workerResultTotal = 0; $misrouteCandidates = 0
if (Test-Path -LiteralPath $tasksDir) {
    Get-ChildItem -LiteralPath $tasksDir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $resultPath = Join-Path $_.FullName "OUTPUTS\RESULT.md"
        if (-not (Test-Path -LiteralPath $resultPath)) { return }
        $text = Get-Content -Raw -LiteralPath $resultPath -Encoding UTF8
        if ($_.Name -match '-codex-verify$') {
            $verifyTotal += 1
            if ($text -match '(?i)verify_verdict:\s*(FAIL|NEEDS_HUMAN_DECISION)') {
                $verifyFail += 1
                if ($text -match $falseFailPattern) { $falseFailCandidates += 1 }
            }
        } else {
            $workerResultTotal += 1
            if ($text -match $misroutePattern) { $misrouteCandidates += 1 }
        }
    }
}

# ---------- 6. assemble ----------
function Get-Rate([int]$Numerator, [int]$Denominator) {
    if ($Denominator -le 0) { return "unknown" }
    return [math]::Round($Numerator / $Denominator, 4)
}
function Get-Avg($Values) {
    $list = @($Values)
    if ($list.Count -eq 0) { return "unknown" }
    return [math]::Round(($list | Measure-Object -Average).Average, 2)
}

$recordedDates = @($entries | ForEach-Object { [string]$_.recorded_at } | Sort-Object)
$windowFrom = if ($recordedDates.Count) { $recordedDates[0] } else { "unknown" }
$windowTo = if ($recordedDates.Count) { $recordedDates[-1] } else { "unknown" }

$report = [ordered]@{
    schema_version = "baseline_v1"
    generated_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz")
    window = [ordered]@{ from = $windowFrom; to = $windowTo }
    sample_sizes = [ordered]@{
        metrics_log_entries = $totalLogged
        queue_runs_with_latency = $latencies.Count
        codex_task_roots = $rootCount
        codex_task_nodes = ($nodeValues | Measure-Object -Sum).Sum
        verify_results_scanned = $verifyTotal
        worker_results_scanned = $workerResultTotal
    }
    metrics = [ordered]@{
        first_pass_rate = [ordered]@{ value = (Get-Rate $firstPass $totalLogged); quality = "measured"; basis = "METRICS_LOG: verdict=PASS and retry_count=0" }
        avg_loop_count = [ordered]@{ value = (Get-Avg $loopCounts); quality = "measured"; basis = "METRICS_LOG: retry_count+1" }
        false_fail_rate = [ordered]@{ value = (Get-Rate $falseFailCandidates $verifyTotal); quality = "estimate"; basis = "verify RESULT pattern: encoding/contract signatures; candidates=$falseFailCandidates of fail=$verifyFail" }
        misroute_rate = [ordered]@{ value = (Get-Rate $misrouteCandidates $workerResultTotal); quality = "estimate"; basis = "worker RESULT pattern: out-of-scope/no-web signatures" }
        avg_nodes_per_task = [ordered]@{ value = (Get-Avg $nodeValues); quality = "measured"; basis = "codex_tasks directory census grouped by root id" }
        avg_cost_per_task = [ordered]@{ value = (Get-Avg $nodeValues); unit = "nodes_proxy"; quality = "estimate"; basis = "token_actual historically unknown; node count used as cost proxy" }
        avg_latency_seconds = [ordered]@{ value = (Get-Avg $latencies); quality = "measured"; basis = "queue_runs finished_at - started_at (only runs with both stamps)" }
        human_escalation_rate = [ordered]@{ value = (Get-Rate $escalatedRoots.Count $rootCount); quality = "measured"; basis = "ESCALATION_INDEX distinct roots / codex_task roots (same universe); METRICS_LOG escalation_required count kept separately"; metrics_log_escalations = $escalatedInLog }
    }
    taxonomy_note = "false_fail/misroute are heuristic ESTIMATES until Failure Taxonomy normalization (Phase 1.5/4) lands."
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$jsonPath = Join-Path $OutputDir "BASELINE_$stamp.json"
[IO.File]::WriteAllText($jsonPath, ($report | ConvertTo-Json -Depth 6), $Utf8NoBom)

$md = @"
# Workflow Metrics Baseline ($stamp)

window: $windowFrom → $windowTo
samples: $totalLogged logged tasks / $rootCount task roots / $($latencies.Count) timed queue runs

| metric | value | quality |
|---|---|---|
| first_pass_rate | $($report.metrics.first_pass_rate.value) | measured |
| avg_loop_count | $($report.metrics.avg_loop_count.value) | measured |
| false_fail_rate | $($report.metrics.false_fail_rate.value) | estimate |
| misroute_rate | $($report.metrics.misroute_rate.value) | estimate |
| avg_nodes_per_task | $($report.metrics.avg_nodes_per_task.value) | measured |
| avg_cost_per_task (nodes proxy) | $($report.metrics.avg_cost_per_task.value) | estimate |
| avg_latency_seconds | $($report.metrics.avg_latency_seconds.value) | measured |
| human_escalation_rate | $($report.metrics.human_escalation_rate.value) | measured |

json: $jsonPath
"@
$mdPath = Join-Path $OutputDir "BASELINE_$stamp.md"
[IO.File]::WriteAllText($mdPath, $md, $Utf8NoBom)

Write-Output "baseline_status=created"
Write-Output "json_path=$jsonPath"
Write-Output "md_path=$mdPath"
Write-Output ("first_pass_rate=" + $report.metrics.first_pass_rate.value)
Write-Output ("avg_loop_count=" + $report.metrics.avg_loop_count.value)
Write-Output ("false_fail_rate_estimate=" + $report.metrics.false_fail_rate.value)
Write-Output ("misroute_rate_estimate=" + $report.metrics.misroute_rate.value)
Write-Output ("avg_nodes_per_task=" + $report.metrics.avg_nodes_per_task.value)
Write-Output ("avg_latency_seconds=" + $report.metrics.avg_latency_seconds.value)
Write-Output ("human_escalation_rate=" + $report.metrics.human_escalation_rate.value)

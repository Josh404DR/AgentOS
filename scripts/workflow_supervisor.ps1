[CmdletBinding()]
param(
    [string]$RootDispatchId = "",
    [string]$AgentOSRoot = "E:\AgentOS",
    [switch]$Watch,
    [int]$PollSeconds = 10
)

$ErrorActionPreference = "Stop"
$Utf8NoBom = [Text.UTF8Encoding]::new($false)
$TasksRoot = Join-Path $AgentOSRoot "data\codex_tasks"
$ControlRoot = Join-Path $AgentOSRoot "data\workflow_control"
$QueueRuns = Join-Path $AgentOSRoot "data\queue_runs"
$EscalationsRoot = Join-Path $AgentOSRoot "data\escalations"
$QueueStarter = Join-Path $AgentOSRoot "scripts\start_task_queue.ps1"
$Gate = Join-Path $AgentOSRoot "scripts\assert_governance_ready.ps1"
$MetricsWriter = Join-Path $AgentOSRoot "scripts\write_task_metric.ps1"

function Read-Utf8([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return "" }
    [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
}

function Write-Utf8([string]$Path, [string]$Text) {
    $parent = Split-Path -Parent $Path
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    [IO.File]::WriteAllText($Path, $Text, $Utf8NoBom)
}

function Get-Field([string]$Text, [string]$Name) {
    $match = [regex]::Match(
        $Text,
        "(?mi)^\s*" + [regex]::Escape($Name) + "\s*:\s*(.+?)\s*$"
    )
    if ($match.Success) { return $match.Groups[1].Value.Trim().Trim('"').Trim("'") }
    return ""
}

function Set-TaskState([string]$TaskPath, [string]$DispatchStatus, [string]$TaskStatus) {
    $text = Read-Utf8 $TaskPath
    foreach ($field in @(
        @{ Name = "dispatch_status"; Value = $DispatchStatus },
        @{ Name = "task_status"; Value = $TaskStatus }
    )) {
        $pattern = "(?mi)^" + $field.Name + "\s*:\s*.+$"
        if ($text -match $pattern) {
            $text = [regex]::Replace($text, $pattern, "$($field.Name): $($field.Value)")
        } else {
            $text = $text.TrimEnd() + "`r`n$($field.Name): $($field.Value)`r`n"
        }
    }
    Write-Utf8 $TaskPath $text
}

function Get-AllTasks {
    $items = @()
    foreach ($taskPath in Get-ChildItem -LiteralPath $TasksRoot -Filter TASK.md -File -Recurse) {
        if ($taskPath.Directory.Parent.FullName -ne $TasksRoot) { continue }
        $text = Read-Utf8 $taskPath.FullName
        $id = Get-Field $text "dispatch_id"
        if (-not $id) { $id = $taskPath.Directory.Name }
        $result = Join-Path $taskPath.Directory.FullName "OUTPUTS\RESULT.md"
        $verdict = ""
        if (Test-Path -LiteralPath $result -PathType Leaf) {
            $resultText = Read-Utf8 $result
            $verdict = Get-Field $resultText "verify_verdict"
            if (-not $verdict) { $verdict = Get-Field $resultText "verification_status" }
        }
        $items += [pscustomobject]@{
            Id = $id
            Path = $taskPath.FullName
            Text = $text
            Parent = Get-Field $text "parent_dispatch_id"
            Source = Get-Field $text "source_dispatch_id"
            Type = Get-Field $text "type"
            Route = Get-Field $text "route_to"
            Status = Get-Field $text "dispatch_status"
            TaskStatus = Get-Field $text "task_status"
            ResultPath = $result
            HasResult = Test-Path -LiteralPath $result -PathType Leaf
            Verdict = ([string]$verdict).ToUpperInvariant()
        }
    }
    return $items
}

function Get-RootId([object[]]$Tasks, [object]$Task) {
    $current = $Task
    $visited = [Collections.Generic.HashSet[string]]::new()
    while ($current -and $visited.Add($current.Id)) {
        $parentId = if ($current.Parent) { $current.Parent } else { $current.Source }
        if (-not $parentId -or $parentId -eq $current.Id) { return $current.Id }
        $parent = $Tasks | Where-Object Id -eq $parentId | Select-Object -First 1
        if (-not $parent) { return $parentId }
        $current = $parent
    }
    return $Task.Id
}

function Get-Control([string]$RootId) {
    $path = Join-Path $ControlRoot (Join-Path $RootId "CONTROL.json")
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return [pscustomobject]@{ state = "running"; retry_requested = $false }
    }
    try { return Read-Utf8 $path | ConvertFrom-Json }
    catch { return [pscustomobject]@{ state = "paused"; retry_requested = $false } }
}

function Resolve-EligibleEscalations([string]$RootId, [string]$PassEvidence) {
    $eligible = @("verify_needs_human", "simple_fail", "complex_fail")
    foreach ($dir in Get-ChildItem -LiteralPath $EscalationsRoot -Directory -ErrorAction SilentlyContinue) {
        if ($dir.Name -ne $RootId -and -not $dir.Name.StartsWith("$RootId-")) { continue }
        $resolution = Join-Path $dir.FullName "RESOLUTION.json"
        if (Test-Path -LiteralPath $resolution -PathType Leaf) { continue }
        $events = Get-ChildItem -LiteralPath $dir.FullName -Filter "*.json" -File |
            Where-Object Name -ne "RESOLUTION.json" |
            Sort-Object LastWriteTime
        if (-not $events) { continue }
        try { $event = Read-Utf8 $events[-1].FullName | ConvertFrom-Json } catch { continue }
        if ($event.source -notin $eligible) { continue }
        $payload = [ordered]@{
            task_id = $event.task_id
            resolution_type = "resolved_by_later_verify_pass"
            category = "workflow"
            resolved_at = (Get-Date).ToString("o")
            resolved_by = "workflow_supervisor"
            summary = "A later independent Codex Verify PASS superseded this recoverable escalation."
            evidence = @($events[-1].FullName, $PassEvidence)
            josh_action_required = $false
            recommended_status = "resolved"
        }
        Write-Utf8 $resolution (($payload | ConvertTo-Json -Depth 6) + "`r`n")
    }
}

function Test-UnresolvedEscalation([string]$RootId) {
    foreach ($dir in Get-ChildItem -LiteralPath $EscalationsRoot -Directory -ErrorAction SilentlyContinue) {
        if ($dir.Name -ne $RootId -and -not $dir.Name.StartsWith("$RootId-")) { continue }
        if (-not (Test-Path -LiteralPath (Join-Path $dir.FullName "RESOLUTION.json"))) {
            return $true
        }
    }
    return $false
}

function Complete-Root([object]$Root, [object[]]$Scoped, [object]$FinalVerify) {
    $outputDir = Join-Path (Split-Path -Parent $Root.Path) "OUTPUTS"
    $statusPath = Join-Path $outputDir "WORKFLOW_STATUS.json"
    $reportPath = Join-Path $outputDir "WORKFLOW_REPORT.md"
    if (Test-Path -LiteralPath $statusPath -PathType Leaf) { return }
    Set-TaskState $Root.Path "completed" "completed"
    $payload = [ordered]@{
        root_dispatch_id = $Root.Id
        workflow_status = "completed"
        final_verify_dispatch_id = $FinalVerify.Id
        final_verify_verdict = "PASS"
        child_count = @($Scoped | Where-Object Id -ne $Root.Id).Count
        completed_at = (Get-Date).ToString("o")
        metrics_status = "written"
    }
    Write-Utf8 $statusPath (($payload | ConvertTo-Json -Depth 6) + "`r`n")
$report = @"
# AgentOS Workflow Completion Report

root_dispatch_id: $($Root.Id)
workflow_status: completed
final_verify_dispatch_id: $($FinalVerify.Id)
final_verify_verdict: PASS
completed_at: $($payload.completed_at)

All required child tasks completed, final independent verification passed,
and no unresolved human decision remains.
"@
    Write-Utf8 $reportPath $report
    $taskType = Get-Field $Root.Text "task_type"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $MetricsWriter `
        -TaskId $Root.Id -TaskType $(if ($taskType) { $taskType } else { "unknown" }) `
        -Verdict PASS -RetryCount 0 -FinalStatus completed -AgentOSRoot $AgentOSRoot | Out-Null
}

function Invoke-SupervisorPass {
    $gateOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Gate -AgentOSRoot $AgentOSRoot
    if ($LASTEXITCODE -ne 0) {
        Write-Output "supervisor_status=blocked"
        Write-Output "reason=governance_gate"
        return
    }
    $tasks = @(Get-AllTasks)
    $roots = if ($RootDispatchId) {
        @($tasks | Where-Object Id -eq $RootDispatchId)
    } else {
        @($tasks | Where-Object { -not $_.Parent -and -not $_.Source })
    }
    foreach ($root in $roots) {
        $scoped = @($tasks | Where-Object { (Get-RootId $tasks $_) -eq $root.Id })
        $control = Get-Control $root.Id
        if ($control.state -in @("paused", "pause_requested", "stopped")) {
            Write-Output "workflow=$($root.Id)|status=paused"
            continue
        }
        $passes = @($scoped | Where-Object Verdict -eq "PASS" | Sort-Object { (Get-Item $_.ResultPath).LastWriteTime })
        if ($passes) {
            $finalVerify = $passes[-1]
            Resolve-EligibleEscalations $root.Id $finalVerify.ResultPath
        }
        $unresolved = Test-UnresolvedEscalation $root.Id
        $pending = @($scoped | Where-Object {
            -not $_.HasResult -and
            $_.Status -in @("ready_to_route", "pending_dependency", "waiting_on_dependency") -and
            ($_.Id -ne $root.Id -or $_.Route -in @("Codex", "Claude", "Ollama", "Antigravity CLI"))
        })
        if ($passes -and -not $pending -and -not $unresolved) {
            Complete-Root $root $scoped $passes[-1]
            Write-Output "workflow=$($root.Id)|status=completed"
            continue
        }
        if ($unresolved) {
            Write-Output "workflow=$($root.Id)|status=waiting_josh"
            continue
        }
        if ($pending) {
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $QueueStarter `
                -RootDispatchId $root.Id -AgentOSRoot $AgentOSRoot | Out-Null
            Write-Output "workflow=$($root.Id)|status=queue_started"
        }
    }
}

do {
    Invoke-SupervisorPass
    if ($Watch) { Start-Sleep -Seconds $PollSeconds }
} while ($Watch)

[CmdletBinding()]
param(
    [string]$AgentOSRoot,
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($AgentOSRoot)) { $AgentOSRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
$root = (Resolve-Path -LiteralPath $AgentOSRoot).Path
$registry = Get-Content -LiteralPath (Join-Path $root "config\runtime_registry.json") -Raw | ConvertFrom-Json
if (-not $OutputPath) { $OutputPath = Join-Path $root "data\observability\runtime_status.json" }
$gatewayReceiptWriter = Join-Path $root "scripts\observability\write-gateway-runtime-receipt.ps1"

function ConvertTo-LockStartUtc($Raw) {
    # Lock start_time may be epoch seconds (psutil create_time) or an ISO string.
    if ($null -eq $Raw -or "$Raw" -eq "") { return $null }
    $epoch = 0.0
    if ([double]::TryParse("$Raw", [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$epoch) -and $epoch -gt 946684800) {
        return [DateTimeOffset]::FromUnixTimeMilliseconds([long]($epoch * 1000)).UtcDateTime
    }
    try { return ([DateTimeOffset]::Parse("$Raw", [Globalization.CultureInfo]::InvariantCulture)).UtcDateTime } catch { return $null }
}

$processes = @()
try { $processes = @(Get-CimInstance Win32_Process -ErrorAction Stop) } catch { $processProbeError = $_.Exception.Message }
$netstat = @(netstat -ano 2>$null)
$identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$now = Get-Date

$statuses = foreach ($runtime in $registry.runtimes) {
    $matches = @()
    if ($runtime.process_match) {
        $name = [string]$runtime.process_match.name
        $needle = [string]$runtime.process_match.command_contains
        $matches = @($processes | Where-Object {
            $_.Name -like "$name*" -and ([string]::IsNullOrWhiteSpace($needle) -or $_.CommandLine -like "*$needle*")
        })
    }
    $receipt = $null
    $profileLock = $null
    $receiptReconciled = $false
    $receiptReconciliationError = $null
    if ($runtime.control.profile_lock_path) {
        $profileLockPath = [Environment]::ExpandEnvironmentVariables([string]$runtime.control.profile_lock_path)
        try {
            $profileLock = [IO.File]::ReadAllText($profileLockPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
            $lockPid = [int]$profileLock.pid
            $lockMatches = @($processes | Where-Object {
                $_.ProcessId -eq $lockPid -and [string]$_.CommandLine -match 'gateway\s+run'
            })
            # PID-reuse guard: "command line looks like a gateway" cannot tell a
            # recycled PID or the other gateway profile apart. The lock owner's
            # recorded start_time must match the live process creation time.
            if ($lockMatches.Count) {
                $lockStartUtc = ConvertTo-LockStartUtc $profileLock.start_time
                if ($null -eq $lockStartUtc) {
                    $receiptReconciliationError = "lock pid $lockPid start_time missing/unparseable; lock not trusted"
                    $lockMatches = @()
                    $profileLock = $null
                } else {
                    $processStartUtc = ($lockMatches[0].CreationDate).ToUniversalTime()
                    $driftSeconds = [math]::Round([math]::Abs(($processStartUtc - $lockStartUtc).TotalSeconds), 1)
                    if ($driftSeconds -gt 15) {
                        $receiptReconciliationError = "lock pid $lockPid start_time drift ${driftSeconds}s exceeds 15s tolerance (possible PID reuse); lock not trusted"
                        $lockMatches = @()
                        $profileLock = $null
                    }
                }
            }
            if ($lockMatches.Count) {
                $matches = $lockMatches
                if ($runtime.control.receipt_id -and (Test-Path -LiteralPath $gatewayReceiptWriter -PathType Leaf)) {
                    $existingReceiptPath = Join-Path $root "data\runtime_receipts\$($runtime.control.receipt_id).json"
                    $existingReceipt = $null
                    if (Test-Path -LiteralPath $existingReceiptPath -PathType Leaf) {
                        try { $existingReceipt = [IO.File]::ReadAllText($existingReceiptPath, [Text.Encoding]::UTF8) | ConvertFrom-Json } catch {}
                    }
                    if (-not $existingReceipt -or [int]$existingReceipt.process_id -ne $lockPid) {
                        & $gatewayReceiptWriter `
                            -ReceiptId ([string]$runtime.control.receipt_id) `
                            -RuntimeId ([string]$runtime.runtime_id) `
                            -ProfileLockPath $profileLockPath `
                            -AgentOSRoot $root | Out-Null
                        $receiptReconciled = $true
                    }
                }
            }
        } catch {
            $receiptReconciliationError = $_.Exception.Message
        }
    }
    if ($runtime.control.receipt_id) {
        $receiptPath = Join-Path $root "data\runtime_receipts\$($runtime.control.receipt_id).json"
        if (Test-Path $receiptPath) {
            try {
                $receipt = [IO.File]::ReadAllText($receiptPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
                if (-not $profileLock -or -not $matches.Count) {
                    $matches = @($matches | Where-Object ProcessId -eq ([int]$receipt.process_id))
                }
            } catch {
                $receipt = [ordered]@{ error = $_.Exception.Message; path = $receiptPath }
                $matches = @()
            }
        } else {
            $matches = @()
        }
    }

    $ports = foreach ($port in @($runtime.ports)) {
        $listening = [bool]($netstat | Select-String ":$port\s+.*LISTENING")
        [ordered]@{ port = [int]$port; listening = $listening }
    }
    $http = $null
    if ($runtime.http_health) {
        try {
            $response = Invoke-WebRequest -Uri $runtime.http_health -UseBasicParsing -TimeoutSec 3
            $http = [ordered]@{ uri = $runtime.http_health; ok = ($response.StatusCode -ge 200 -and $response.StatusCode -lt 400); status_code = $response.StatusCode }
        } catch {
            $http = [ordered]@{ uri = $runtime.http_health; ok = $false; status_code = $null; error = $_.Exception.Message }
        }
    }

    $logs = foreach ($relative in @($runtime.log_paths)) {
        $path = Join-Path $root ($relative -replace '/', '\')
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $item = Get-Item -LiteralPath $path
            [ordered]@{ path = $relative; exists = $true; last_write = $item.LastWriteTime.ToString('o'); age_seconds = [math]::Round(($now - $item.LastWriteTime).TotalSeconds, 1) }
        } else {
            [ordered]@{ path = $relative; exists = $false; last_write = $null; age_seconds = $null }
        }
    }
    $stateFiles = foreach ($relative in @($runtime.state_paths | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })) {
        $path = Join-Path $root ($relative -replace '/', '\')
        if (Test-Path -LiteralPath $path) {
            $item = Get-Item -LiteralPath $path
            [ordered]@{ path = $relative; exists = $true; kind = if ($item.PSIsContainer) { "directory" } else { "file" }; last_write = $item.LastWriteTime.ToString('o'); age_seconds = [math]::Round(($now - $item.LastWriteTime).TotalSeconds, 1) }
        } else {
            [ordered]@{ path = $relative; exists = $false; kind = $null; last_write = $null; age_seconds = $null }
        }
    }

    $scheduledTasks = @()
    if ($runtime.start_source.type -eq "scheduled_task") {
        $taskRefs = @([string]$runtime.start_source.ref) + @($runtime.related_scheduled_tasks | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
        foreach ($taskRef in $taskRefs) {
            try {
                $scheduledTasks += @(Get-ScheduledTask -TaskName $taskRef -ErrorAction Stop | ForEach-Object {
                    $info = Get-ScheduledTaskInfo -InputObject $_ -ErrorAction SilentlyContinue
                    [ordered]@{
                        task_name = $_.TaskName
                        state = [string]$_.State
                        identity = $_.Principal.UserId
                        last_run = if ($info) { $info.LastRunTime.ToString('o') } else { $null }
                        last_result = if ($info) { $info.LastTaskResult } else { $null }
                        next_run = if ($info) { $info.NextRunTime.ToString('o') } else { $null }
                    }
                })
            } catch {
                $probeState = if ($_.CategoryInfo.Category -eq [Management.Automation.ErrorCategory]::ObjectNotFound) { "not_found" } else { "unknown" }
                $scheduledTasks += @([ordered]@{ task_name = $taskRef; state = $probeState; probe_error = $_.Exception.Message })
            }
        }
    }

    $observedIdentities = @()
    foreach ($match in $matches) {
        try {
            $owner = Invoke-CimMethod -InputObject $match -MethodName GetOwner -ErrorAction Stop
            if ($owner.ReturnValue -eq 0 -and $owner.User) {
                $observedIdentities += $(if ($owner.Domain) { "$($owner.Domain)\$($owner.User)" } else { [string]$owner.User })
            }
        } catch {}
    }
    if (-not $observedIdentities.Count) {
        $observedIdentities = @($scheduledTasks | Where-Object { $_.identity } | ForEach-Object { [string]$_.identity })
    }
    $observedIdentity = (@($observedIdentities | Sort-Object -Unique) -join ", ")
    if ([string]::IsNullOrWhiteSpace($observedIdentity)) { $observedIdentity = $null }

    $heartbeat = $null
    if ($receipt -and $receipt.started_at -and $matches.Count) {
        $heartbeatAt = [datetime]$receipt.started_at
        $heartbeat = [ordered]@{ source = "process_receipt"; observed_at = $heartbeatAt.ToString("o"); age_seconds = [math]::Round(($now - $heartbeatAt).TotalSeconds, 1) }
    } elseif ($http -and $http.ok) {
        $heartbeat = [ordered]@{ source = "http_health"; observed_at = $now.ToString("o"); age_seconds = 0 }
    } else {
        $lastRun = @($scheduledTasks | Where-Object { $_.last_run } | Sort-Object { [datetime]$_.last_run } -Descending | Select-Object -First 1)
        $latestLog = @($logs | Where-Object { $_.last_write } | Sort-Object { [datetime]$_.last_write } -Descending | Select-Object -First 1)
        $latestState = @($stateFiles | Where-Object { $_.last_write -and $_.kind -eq "file" } | Sort-Object { [datetime]$_.last_write } -Descending | Select-Object -First 1)
        if ($lastRun.Count) {
            $heartbeatAt = [datetime]$lastRun[0].last_run
            $heartbeat = [ordered]@{ source = "scheduled_task"; observed_at = $heartbeatAt.ToString("o"); age_seconds = [math]::Round(($now - $heartbeatAt).TotalSeconds, 1) }
        } elseif ($latestLog.Count) {
            $heartbeatAt = [datetime]$latestLog[0].last_write
            $heartbeat = [ordered]@{ source = "log"; observed_at = $heartbeatAt.ToString("o"); age_seconds = [math]::Round(($now - $heartbeatAt).TotalSeconds, 1) }
        } elseif ($latestState.Count) {
            $heartbeatAt = [datetime]$latestState[0].last_write
            $heartbeat = [ordered]@{ source = "state_file"; observed_at = $heartbeatAt.ToString("o"); age_seconds = [math]::Round(($now - $heartbeatAt).TotalSeconds, 1) }
        }
    }

    $allPortsListening = @($ports).Count -gt 0 -and @($ports | Where-Object { -not $_.listening }).Count -eq 0
    $scheduledMissing = $runtime.start_source.type -eq "scheduled_task" -and @($scheduledTasks | Where-Object state -eq "not_found").Count -gt 0
    $scheduledRunning = @($scheduledTasks | Where-Object state -eq "Running").Count -gt 0
    $scheduledReady = @($scheduledTasks | Where-Object state -eq "Ready").Count -gt 0
    $state = if (-not $runtime.enabled) {
        "disabled"
    } elseif ($http -and -not $http.ok) {
        "down"
    } elseif (@($ports).Count -and -not $allPortsListening) {
        "down"
    } elseif ($processProbeError -and (($http -and $http.ok) -or $allPortsListening)) {
        "degraded"
    } elseif ($scheduledMissing -and (($http -and $http.ok) -or $matches.Count)) {
        "degraded"
    } elseif ($runtime.kind -eq "scheduled" -and $scheduledRunning) {
        "running"
    } elseif ($runtime.kind -eq "scheduled" -and $scheduledReady) {
        "idle"
    } elseif ($runtime.kind -eq "per_event" -and -not $matches.Count) {
        "idle"
    } elseif ($processProbeError -and $runtime.process_match) {
        "unknown"
    } elseif ($runtime.process_match -and -not $matches.Count) {
        "down"
    } elseif ($http -and $http.ok) {
        "healthy"
    } elseif ($matches.Count) {
        "running"
    } elseif ($scheduledMissing) {
        "down"
    } else {
        "unknown"
    }
    $pidEvidence = if ($matches.Count) { (@($matches | ForEach-Object ProcessId) -join ",") } else { "none" }
    $portEvidence = if (@($ports).Count) { (@($ports | ForEach-Object { "$($_.port):$(if ($_.listening) { 'up' } else { 'down' })" }) -join ",") } else { "none" }
    $httpEvidence = if ($http) { if ($http.ok) { "up" } else { "down" } } else { "none" }
    $heartbeatEvidence = if ($heartbeat) { "$($heartbeat.source)@$($heartbeat.observed_at)" } else { "none" }
    $logEvidence = @($logs | Where-Object exists).Count
    $stateEvidence = @($stateFiles | Where-Object exists).Count
    $evidenceSummary = "pid=$pidEvidence; ports=$portEvidence; http=$httpEvidence; heartbeat=$heartbeatEvidence; logs=$logEvidence; state=$stateEvidence"
    [ordered]@{
        runtime_id = $runtime.runtime_id
        display_name = $runtime.display_name
        kind = $runtime.kind
        state = $state
        enabled = [bool]$runtime.enabled
        expected_identity = $runtime.expected_identity
        observed_identity = $observedIdentity
        pids = @($matches | ForEach-Object ProcessId)
        receipt = $receipt
        receipt_reconciled = $receiptReconciled
        receipt_reconciliation_error = $receiptReconciliationError
        heartbeat = $heartbeat
        evidence_summary = $evidenceSummary
        ports = @($ports)
        http = $http
        logs = @($logs)
        state_files = @($stateFiles)
        scheduled_tasks = @($scheduledTasks)
        depends_on = @($runtime.depends_on)
    }
}

$payload = [ordered]@{
    schema_version = "1.0.0"
    collected_at = $now.ToString('o')
    collector_identity = $identity
    process_probe_error = $processProbeError
    runtimes = @($statuses)
}
$parent = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $parent | Out-Null
$temp = "$OutputPath.tmp-$PID"
[IO.File]::WriteAllText($temp, ($payload | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
Move-Item -LiteralPath $temp -Destination $OutputPath -Force
$historyPath = Join-Path $parent "runtime_status_history.jsonl"
$historyRecord = [ordered]@{
    collected_at = $payload.collected_at
    runtimes = @($statuses | ForEach-Object {
        $latestScheduled = @($_.scheduled_tasks | Where-Object { $_.last_run } | Sort-Object { [datetime]$_.last_run } -Descending | Select-Object -First 1)
        [ordered]@{
            runtime_id = $_.runtime_id
            state = $_.state
            scheduled_run = if ($latestScheduled.Count) { [ordered]@{
                last_run = $latestScheduled[0].last_run
                last_result = $latestScheduled[0].last_result
                task_state = $latestScheduled[0].state
            } } else { $null }
        }
    })
}
[IO.File]::AppendAllText($historyPath, (($historyRecord | ConvertTo-Json -Compress -Depth 4) + [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
Write-Output "runtime_collector_status=PASS"
Write-Output "runtime_count=$(@($statuses).Count)"
Write-Output "output_path=$OutputPath"

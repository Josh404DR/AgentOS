# OUT-OF-SCOPE — 2026-07-08 (W27)
# 此腳本為裝置維護工具，與接案業務無關。
# 依據稽核報告 W27，凍結；之後應移出 AgentOS repo。
# 目前保留原地，不執行任何修改。

param(
    [int]$ThresholdPercent = 85,
    [int]$Top = 20,
    [string[]]$CandidateNames = @(
        "chrome",
        "msedge",
        "firefox",
        "steamwebhelper",
        "Code",
        "Cursor",
        "powershell"
    ),
    [string[]]$ProtectedNames = @(
        "hermes",
        "codex",
        "Codex",
        "claude",
        "Claude",
        "python",
        "Telegram",
        "explorer",
        "dwm",
        "endpointprotection",
        "Taskmgr"
    ),
    [switch]$KillCandidates
)

$ErrorActionPreference = "SilentlyContinue"

function Get-MemoryInfo {
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $totalBytes = [double]$os.TotalVisibleMemorySize * 1KB
        $freeBytes = [double]$os.FreePhysicalMemory * 1KB
        return [pscustomobject]@{
            Source = "Win32_OperatingSystem"
            TotalBytes = $totalBytes
            FreeBytes = $freeBytes
        }
    } catch {
        try {
            Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction Stop
            $info = New-Object Microsoft.VisualBasic.Devices.ComputerInfo
            return [pscustomobject]@{
                Source = "Microsoft.VisualBasic.Devices.ComputerInfo"
                TotalBytes = [double]$info.TotalPhysicalMemory
                FreeBytes = [double]$info.AvailablePhysicalMemory
            }
        } catch {
            return $null
        }
    }
}

function Format-MB([double]$bytes) {
    return [math]::Round($bytes / 1MB, 1)
}

function Is-ProtectedProcess($processName) {
    foreach ($name in $ProtectedNames) {
        if ($processName -ieq $name) {
            return $true
        }
    }
    return $false
}

function Is-CandidateProcess($processName) {
    foreach ($name in $CandidateNames) {
        if ($processName -ieq $name) {
            return $true
        }
    }
    return $false
}

$memory = Get-MemoryInfo
$processes = Get-Process |
    Sort-Object WorkingSet64 -Descending |
    Select-Object -First $Top Id,ProcessName,
        @{Name="MemoryMB";Expression={Format-MB $_.WorkingSet64}},
        @{Name="Candidate";Expression={Is-CandidateProcess $_.ProcessName}},
        @{Name="Protected";Expression={Is-ProtectedProcess $_.ProcessName}},
        Path

if ($memory -ne $null) {
    $usedBytes = $memory.TotalBytes - $memory.FreeBytes
    $usedPercent = [math]::Round(($usedBytes / $memory.TotalBytes) * 100, 1)
    $status = if ($usedPercent -ge $ThresholdPercent) { "HIGH" } else { "OK" }

    Write-Output "MEMORY_STATUS=$status"
    Write-Output "MEMORY_SOURCE=$($memory.Source)"
    Write-Output "MEMORY_USED_PERCENT=$usedPercent"
    Write-Output "MEMORY_TOTAL_MB=$(Format-MB $memory.TotalBytes)"
    Write-Output "MEMORY_FREE_MB=$(Format-MB $memory.FreeBytes)"
    Write-Output "THRESHOLD_PERCENT=$ThresholdPercent"
} else {
    Write-Output "MEMORY_STATUS=UNKNOWN"
    Write-Output "MEMORY_SOURCE=unavailable"
    Write-Output "THRESHOLD_PERCENT=$ThresholdPercent"
}

Write-Output ""
Write-Output "TOP_PROCESSES:"
$processes | Format-Table -AutoSize

$candidates = $processes | Where-Object {
    $_.Candidate -eq $true -and $_.Protected -ne $true
}

Write-Output ""
Write-Output "CLOSE_CANDIDATES:"
if ($candidates.Count -eq 0) {
    Write-Output "None"
} else {
    $candidates | Format-Table -AutoSize
}

if ($KillCandidates) {
    Write-Output ""
    Write-Output "KILL_MODE=enabled"
    foreach ($candidate in $candidates) {
        try {
            Stop-Process -Id $candidate.Id -Force -ErrorAction Stop
            Write-Output "KILLED=$($candidate.ProcessName) PID=$($candidate.Id)"
        } catch {
            Write-Output "KILL_FAILED=$($candidate.ProcessName) PID=$($candidate.Id) ERROR=$($_.Exceptio
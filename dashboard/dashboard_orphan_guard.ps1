function Get-DashboardProcessDiagnostic {
    param([Parameter(Mandatory = $true)][int]$ProcessId)
    $native = Get-CimInstance Win32_Process -Filter "ProcessId=$ProcessId" -ErrorAction SilentlyContinue
    $managed = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    [pscustomobject]@{
        ProcessId = $ProcessId
        Name = if ($managed) { $managed.ProcessName } else { "unknown" }
        StartTime = if ($managed) { $managed.StartTime.ToString("o") } else { "unknown" }
        ExecutablePath = if ($native) { [string]$native.ExecutablePath } else { "" }
        CommandLine = if ($native) { [string]$native.CommandLine } else { "" }
    }
}

function Test-DashboardWorkspaceProcess {
    param(
        [Parameter(Mandatory = $true)][object]$ProcessInfo,
        [Parameter(Mandatory = $true)][ValidateSet("backend", "frontend")][string]$Kind,
        [Parameter(Mandatory = $true)][string]$BackendPython,
        [Parameter(Mandatory = $true)][string]$FrontendDir
    )
    try {
        $executable = [IO.Path]::GetFullPath([string]$ProcessInfo.ExecutablePath)
    } catch { return $false }
    $command = [string]$ProcessInfo.CommandLine
    if ($Kind -eq "backend") {
        try { $expected = [IO.Path]::GetFullPath($BackendPython) } catch { return $false }
        return $executable.Equals($expected, [StringComparison]::OrdinalIgnoreCase) -and
            $command -match '(?i)(^|\s)-m\s+uvicorn\s+main:app(\s|$)'
    }
    $frontendFull = [IO.Path]::GetFullPath($FrontendDir).TrimEnd('\')
    return $command.IndexOf($frontendFull, [StringComparison]::OrdinalIgnoreCase) -ge 0 -and
        $command -match '(?i)(next(\.cmd|\\dist\\bin\\next)?)(\s|"|$)' 
}

function Test-DashboardTrustedReceipt {
    param(
        [Parameter(Mandatory = $true)][string]$ReceiptPath,
        [Parameter(Mandatory = $true)][int[]]$PortOwners,
        [Parameter(Mandatory = $true)][object[]]$AllProcesses
    )
    if (-not (Test-Path -LiteralPath $ReceiptPath -PathType Leaf)) { return $false }
    try {
        $receipt = [IO.File]::ReadAllText($ReceiptPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
        if ([string]$receipt.status -ne 'running') { return $false }
        $receiptPid = [int]$receipt.process_id
        $native = Get-CimInstance Win32_Process -Filter "ProcessId=$receiptPid" -ErrorAction SilentlyContinue
        $managed = Get-Process -Id $receiptPid -ErrorAction SilentlyContinue
        if (-not $native -or -not $managed) { return $false }
        if ([IO.Path]::GetFullPath([string]$native.ExecutablePath) -ne [IO.Path]::GetFullPath([string]$receipt.executable_path)) { return $false }
        if ([string]$native.CommandLine -notlike "*$($receipt.command_match)*") { return $false }
        if ([math]::Abs(($managed.StartTime - [datetime]$receipt.started_at).TotalSeconds) -gt 5) { return $false }
        return @($PortOwners | Where-Object {
            Test-ProcessDescendsFrom $_ $receiptPid $AllProcesses
        }).Count -gt 0
    } catch { return $false }
}

function Resolve-DashboardOrphanPort {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][ValidateSet("backend", "frontend")][string]$Kind,
        [Parameter(Mandatory = $true)][int]$Port,
        [Parameter(Mandatory = $true)][string]$ReceiptPath,
        [Parameter(Mandatory = $true)][string]$BackendPython,
        [Parameter(Mandatory = $true)][string]$FrontendDir,
        [switch]$Reclaim
    )
    $owners = @(Get-PortOwnerIds $Port)
    if (-not $owners.Count) { return }
    $allProcesses = @(Get-CimInstance Win32_Process -ErrorAction Stop)
    if (Test-DashboardTrustedReceipt -ReceiptPath $ReceiptPath -PortOwners $owners -AllProcesses $allProcesses) {
        return
    }
    $diagnostics = @($owners | ForEach-Object { Get-DashboardProcessDiagnostic $_ })
    foreach ($item in $diagnostics) {
        Write-Host "[$Name] Untrusted port owner: PID=$($item.ProcessId) process=$($item.Name) started_at=$($item.StartTime)" -ForegroundColor Yellow
        Write-Host "[$Name] command_line=$($item.CommandLine)" -ForegroundColor DarkGray
    }
    $manual = "Get-CimInstance Win32_Process -Filter 'ProcessId=<PID>' | Select-Object ProcessId,Name,ExecutablePath,CommandLine"
    Write-Host "[$Name] Inspect manually: $manual" -ForegroundColor Yellow
    Write-Host "[$Name] After verification: Stop-Process -Id <PID> -Force; .\start.ps1" -ForegroundColor Yellow
    $validated = @($diagnostics | Where-Object {
        Test-DashboardWorkspaceProcess -ProcessInfo $_ -Kind $Kind -BackendPython $BackendPython -FrontendDir $FrontendDir
    })
    if (-not $Reclaim) {
        throw "Port $Port is active without a trusted $Name receipt. Re-run with -ReclaimOrphans only for a verified workspace process."
    }
    if ($validated.Count -ne $diagnostics.Count) {
        throw "Port $Port owner command line is not a verified $Name process from this workspace; refusing reclaim."
    }
    foreach ($item in $validated) {
        & taskkill.exe /PID ([int]$item.ProcessId) /T /F | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Failed to reclaim $Name process tree PID $($item.ProcessId)." }
    }
    $deadline = (Get-Date).AddSeconds(10)
    while ((Get-Date) -lt $deadline -and @(Get-PortOwnerIds $Port).Count) { Start-Sleep -Milliseconds 250 }
    if (@(Get-PortOwnerIds $Port).Count) { throw "$Name orphan did not release port $Port." }
    Write-Host "[$Name] Reclaimed verified workspace orphan process." -ForegroundColor Green
}

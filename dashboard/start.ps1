#!/usr/bin/env pwsh
# AgentOS Dashboard — One-shot startup
# Usage:
#   .\start.ps1            起動所有服務 + 開瀏覽器
#   .\start.ps1 -Install   第一次安裝依賴
#   .\start.ps1 -Stop      關閉所有 dashboard 服務

param(
    [switch]$Install,
    [switch]$Stop,
    [switch]$NoBrowser,
    [switch]$BackendOnly,
    [switch]$FrontendOnly,
    [switch]$Dev
)

$ErrorActionPreference = "Stop"
$DashboardRoot = $PSScriptRoot
$BackendDir    = Join-Path $DashboardRoot "backend"
$FrontendDir   = Join-Path $DashboardRoot "frontend"
$BackendPython = Join-Path $BackendDir ".venv\Scripts\python.exe"
$AgentOSRoot   = Split-Path $DashboardRoot
$LogDir        = Join-Path $AgentOSRoot "logs"
$ReceiptDir    = Join-Path $AgentOSRoot "data\runtime_receipts"

function Get-PortOwnerIds([int]$Port) {
    return @(netstat -ano | Select-String ":$Port\s+.*LISTENING" | ForEach-Object {
        $candidate = ($_ -split "\s+")[-1]
        if ($candidate -match "^\d+$" -and $candidate -ne "0") { [int]$candidate }
    } | Sort-Object -Unique)
}

function Test-ProcessDescendsFrom([int]$ProcessId, [int]$AncestorId, [object[]]$Processes) {
    $seen = @{}
    $current = $ProcessId
    while ($current -gt 0 -and -not $seen.ContainsKey($current)) {
        if ($current -eq $AncestorId) { return $true }
        $seen[$current] = $true
        $match = @($Processes | Where-Object ProcessId -eq $current | Select-Object -First 1)
        if (-not $match.Count) { return $false }
        $current = [int]$match[0].ParentProcessId
    }
    return $false
}

function Write-DashboardReceipt([string]$Name, [Diagnostics.Process]$Process, [string]$CommandMatch, [int]$Port) {
    New-Item -ItemType Directory -Force -Path $ReceiptDir | Out-Null
    $receipt = [ordered]@{
        runtime_id = $Name
        status = "running"
        process_id = $Process.Id
        executable_path = $Process.Path
        command_match = $CommandMatch
        port = $Port
        started_at = $Process.StartTime.ToString("o")
        identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    }
    [IO.File]::WriteAllText((Join-Path $ReceiptDir "$Name.json"), ($receipt | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
}

function Stop-RegisteredDashboardProcess([string]$Name, [int]$Port) {
    $receiptPath = Join-Path $ReceiptDir "$Name.json"
    $portOwners = @(Get-PortOwnerIds $Port)
    if (-not (Test-Path -LiteralPath $receiptPath -PathType Leaf)) {
        if ($portOwners.Count) { throw "Port $Port is active without a trusted $Name receipt; refusing to stop it." }
        Write-Host "  [$Name] Already stopped; no receipt or listener." -ForegroundColor DarkGray
        return
    }
    $receipt = [IO.File]::ReadAllText($receiptPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
    if ($receipt.status -eq "stopped" -and -not $portOwners.Count) {
        Write-Host "  [$Name] Already stopped according to preserved receipt." -ForegroundColor DarkGray
        return
    }
    $pidValue = [int]$receipt.process_id
    $native = Get-CimInstance Win32_Process -Filter "ProcessId=$pidValue" -ErrorAction Stop
    $managed = Get-Process -Id $pidValue -ErrorAction Stop
    if ([IO.Path]::GetFullPath([string]$native.ExecutablePath) -ne [IO.Path]::GetFullPath([string]$receipt.executable_path)) { throw "$Name executable path mismatch; refusing stop." }
    if ([string]$native.CommandLine -notlike "*$($receipt.command_match)*") { throw "$Name command line mismatch; refusing stop." }
    if ([math]::Abs(($managed.StartTime - [datetime]$receipt.started_at).TotalSeconds) -gt 5) { throw "$Name start time mismatch; refusing stop." }
    $allProcesses = @(Get-CimInstance Win32_Process -ErrorAction Stop)
    if (-not $portOwners.Count -or -not @($portOwners | Where-Object { Test-ProcessDescendsFrom $_ $pidValue $allProcesses }).Count) {
        throw "$Name receipt does not own the listener on port $Port; refusing stop."
    }
    & taskkill.exe /PID $pidValue /T /F | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Failed to stop registered $Name process tree PID $pidValue." }
    $deadline = (Get-Date).AddSeconds(10)
    while ((Get-Date) -lt $deadline -and @(Get-PortOwnerIds $Port).Count) { Start-Sleep -Milliseconds 250 }
    if (@(Get-PortOwnerIds $Port).Count) { throw "$Name stopped process did not release port $Port." }
    $receipt | Add-Member -NotePropertyName status -NotePropertyValue "stopped" -Force
    $receipt | Add-Member -NotePropertyName stopped_at -NotePropertyValue (Get-Date).ToString("o") -Force
    [IO.File]::WriteAllText($receiptPath, ($receipt | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
    Write-Host "  [$Name] Stopped registered process tree PID $pidValue." -ForegroundColor Green
}

# Ensure log directory exists
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }

# ─────────────────────────────────────────
# STOP
# ─────────────────────────────────────────
if ($Stop) {
    Write-Host "[Stop] Validating dashboard lifecycle receipts..." -ForegroundColor Yellow
    if (-not $FrontendOnly) { Stop-RegisteredDashboardProcess -Name "dashboard-backend" -Port 8000 }
    if (-not $BackendOnly) { Stop-RegisteredDashboardProcess -Name "dashboard-frontend" -Port 3000 }
    Write-Host "[Stop] Done." -ForegroundColor Green
    return
}

# ─────────────────────────────────────────
# INSTALL
# ─────────────────────────────────────────
if ($Install) {
    Write-Host "=== First-time Setup ===" -ForegroundColor Cyan

    Write-Host "[1/3] Creating Python backend environment..." -ForegroundColor Yellow
    if (-not (Test-Path -LiteralPath $BackendPython -PathType Leaf)) {
        $pyLauncher = Get-Command py.exe -ErrorAction SilentlyContinue
        $python = Get-Command python.exe -ErrorAction SilentlyContinue
        if ($pyLauncher) {
            & $pyLauncher.Source -3 -m venv (Join-Path $BackendDir ".venv")
        } elseif ($python) {
            & $python.Source -m venv (Join-Path $BackendDir ".venv")
        } else {
            throw "Python 3 is required to create dashboard/backend/.venv."
        }
        if ($LASTEXITCODE -ne 0) { throw "Python virtual environment creation failed." }
    }
    & $BackendPython -m pip install -r (Join-Path $BackendDir "requirements.txt")
    if ($LASTEXITCODE -ne 0) { throw "Backend dependency installation failed." }

    Write-Host "[2/3] Installing Node.js frontend dependencies..." -ForegroundColor Yellow
    Push-Location $FrontendDir
    if (Test-Path (Join-Path $FrontendDir "package-lock.json")) { npm ci } else { npm install }
    if ($LASTEXITCODE -ne 0) { throw "Frontend dependency installation failed." }
    Write-Host "[3/3] Building the production frontend..." -ForegroundColor Yellow
    npm run build
    if ($LASTEXITCODE -ne 0) { throw "Frontend production build failed." }
    Pop-Location

    Write-Host "Setup complete. Run .\start.ps1 to launch." -ForegroundColor Green
    return
}

# ─────────────────────────────────────────
# Helper: check if port is in use
# ─────────────────────────────────────────
function Test-Port($port) {
    $result = netstat -ano | Select-String ":$port\s.*LISTENING"
    return $null -ne $result
}

function Test-HttpEndpoint([string]$Uri) {
    try {
        $response = Invoke-WebRequest -Uri $Uri -UseBasicParsing -TimeoutSec 3
        return $response.StatusCode -ge 200 -and $response.StatusCode -lt 400
    } catch {
        return $false
    }
}

function Wait-HttpReady {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][System.Diagnostics.Process]$Process,
        [int]$TimeoutSeconds = 60
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if ($Process.HasExited) { return $false }
        try {
            $response = Invoke-WebRequest -Uri $Uri -UseBasicParsing -TimeoutSec 3
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 400) { return $true }
        } catch {
            # The service may still be starting.
        }
        Start-Sleep -Seconds 1
    }
    return $false
}

# Start-Process builds a case-insensitive environment dictionary. Some launch
# contexts expose both Path and PATH, which makes Start-Process throw before it
# can launch the dashboard. Rebuild one canonical process-level Path value.
function Repair-ProcessPathEnvironment {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $cleanPath = (@($machinePath, $userPath) | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_)
    }) -join ";"

    [Environment]::SetEnvironmentVariable("PATH", $null, "Process")
    [Environment]::SetEnvironmentVariable("Path", $cleanPath, "Process")
}

Repair-ProcessPathEnvironment

# ─────────────────────────────────────────
# START BACKEND
# ─────────────────────────────────────────
if (-not $FrontendOnly) {
    if (Test-Port 8000) {
        if (-not (Test-HttpEndpoint "http://localhost:8000/api/health")) {
            throw "Port 8000 is occupied, but the dashboard backend health check failed."
        }
        Write-Host "[Backend] Already running and healthy on port 8000." -ForegroundColor Green
    } else {
        Write-Host "[Backend] Starting FastAPI on http://localhost:8000..." -ForegroundColor DarkGray
        $outLog = Join-Path $LogDir "dashboard-backend.stdout.log"
        $errLog = Join-Path $LogDir "dashboard-backend.stderr.log"

                if (-not (Test-Path -LiteralPath $BackendPython -PathType Leaf)) {
                    throw "Dashboard backend runtime missing: $BackendPython. Run .\start.ps1 -Install first."
                }
                $backendArguments = @("-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000")
                if ($Dev) { $backendArguments += "--reload" }
                $proc = Start-Process -FilePath $BackendPython `
                    -ArgumentList $backendArguments `
            -WorkingDirectory $BackendDir `
            -WindowStyle Hidden `
            -RedirectStandardOutput $outLog `
            -RedirectStandardError  $errLog `
            -PassThru

        if (Wait-HttpReady -Uri "http://localhost:8000/api/health" -Process $proc -TimeoutSeconds 60) {
            Write-DashboardReceipt -Name "dashboard-backend" -Process $proc -CommandMatch "uvicorn main:app" -Port 8000
            Write-Host "[Backend] Running PID=$($proc.Id)" -ForegroundColor Green
        } else {
            if (Test-Path $errLog) { Get-Content $errLog -Tail 20 }
            throw "Dashboard backend failed health check. Log: $errLog"
        }
    }
}

# ─────────────────────────────────────────
# START FRONTEND
# ─────────────────────────────────────────
if (-not $BackendOnly) {
    if (Test-Port 3000) {
        if (-not (Test-HttpEndpoint "http://localhost:3000")) {
            throw "Port 3000 is occupied, but the dashboard frontend health check failed."
        }
        Write-Host "[Frontend] Already running and healthy on port 3000." -ForegroundColor Green
    } else {
        Write-Host "[Frontend] Starting Next.js on http://localhost:3000..." -ForegroundColor DarkGray

        $feOut = Join-Path $LogDir "dashboard-frontend.stdout.log"
        $feErr = Join-Path $LogDir "dashboard-frontend.stderr.log"

        if (-not $Dev -and -not (Test-Path (Join-Path $FrontendDir ".next\BUILD_ID"))) {
            throw "Dashboard frontend production build missing. Run 'npm run build' in $FrontendDir first, or use -Dev."
        }
        $frontendCommand = if ($Dev) { "npm run dev" } else { "npm run start" }

        # Use cmd.exe to run npm so PATH is resolved correctly in hidden mode
        $proc = Start-Process -FilePath "cmd.exe" `
            -ArgumentList @("/c", $frontendCommand) `
            -WorkingDirectory $FrontendDir `
            -WindowStyle Hidden `
            -RedirectStandardOutput $feOut `
            -RedirectStandardError  $feErr `
            -PassThru

        # Wait for Next.js to be ready (up to 60s — first compile can be slow)
        $waited = 0
        while (-not (Test-Port 3000) -and $waited -lt 60) {
            Start-Sleep -Seconds 2
            $waited += 2
            Write-Host "  [Frontend] Compiling... ($waited s)" -ForegroundColor DarkGray
            # Show last log line if available
            if (Test-Path $feOut) {
                $last = Get-Content $feOut -Tail 1 -ErrorAction SilentlyContinue
                if ($last) { Write-Host "    $last" -ForegroundColor DarkGray }
            }
        }

        if (Wait-HttpReady -Uri "http://localhost:3000" -Process $proc -TimeoutSeconds 60) {
            Write-DashboardReceipt -Name "dashboard-frontend" -Process $proc -CommandMatch $frontendCommand -Port 3000
            Write-Host "[Frontend] Running PID=$($proc.Id)" -ForegroundColor Green
        } else {
            if (Test-Path $feErr) { Get-Content $feErr -Tail 20 }
            if (Test-Path $feOut) { Get-Content $feOut -Tail 20 }
            throw "Dashboard frontend failed health check. Logs: $feOut, $feErr"
        }
    }
}

# ─────────────────────────────────────────
# OPEN BROWSER
# ─────────────────────────────────────────
if (-not $NoBrowser -and -not $BackendOnly) {
    Start-Sleep -Seconds 1
    Write-Host "[Browser] Opening http://localhost:3000..." -ForegroundColor Cyan
    Start-Process "http://localhost:3000"
}

Write-Host ""
Write-Host "=== AgentOS Dashboard Ready ===" -ForegroundColor Cyan
Write-Host "  UI  → http://localhost:3000" -ForegroundColor White
Write-Host "  API → http://localhost:8000/docs" -ForegroundColor White
Write-Host "  To stop: .\start.ps1 -Stop" -ForegroundColor DarkGray

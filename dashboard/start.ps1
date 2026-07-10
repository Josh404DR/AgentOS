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

# Ensure log directory exists
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }

# ─────────────────────────────────────────
# STOP
# ─────────────────────────────────────────
if ($Stop) {
    Write-Host "[Stop] Killing dashboard processes on ports 8000 / 3000..." -ForegroundColor Yellow
    foreach ($port in @(8000, 3000)) {
        $pids = (netstat -ano | Select-String ":$port\s") |
            ForEach-Object { ($_ -split "\s+")[-1] } |
            Where-Object { $_ -match "^\d+$" -and $_ -ne "0" } |
            Sort-Object -Unique
        foreach ($processId in $pids) {
            $previousErrorActionPreference = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            $taskKillOutput = & taskkill.exe /PID $processId /T /F 2>&1
            $taskKillExitCode = $LASTEXITCODE
            $ErrorActionPreference = $previousErrorActionPreference
            if ($taskKillExitCode -eq 0) {
                Write-Host "  Killed process tree PID $processId (port $port)"
            } else {
                Write-Host "  Could not stop PID $processId (port $port): $($taskKillOutput -join ' ')" -ForegroundColor DarkYellow
            }
        }
    }
    $deadline = (Get-Date).AddSeconds(10)
    while ((Get-Date) -lt $deadline) {
        $stillListening = netstat -ano | Select-String ":(?:8000|3000)\s.*LISTENING"
        if (-not $stillListening) { break }
        Start-Sleep -Milliseconds 250
    }
    Write-Host "[Stop] Done." -ForegroundColor Green
    return
}

# ─────────────────────────────────────────
# INSTALL
# ─────────────────────────────────────────
if ($Install) {
    Write-Host "=== First-time Setup ===" -ForegroundColor Cyan

    Write-Host "[1/3] Installing Python backend dependencies..." -ForegroundColor Yellow
    Push-Location $BackendDir
    pip install -r requirements.txt
    Pop-Location

    Write-Host "[2/3] Installing Node.js frontend dependencies..." -ForegroundColor Yellow
    Push-Location $FrontendDir
    npm install
    Write-Host "[3/3] Building the production frontend..." -ForegroundColor Yellow
    npm run build
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

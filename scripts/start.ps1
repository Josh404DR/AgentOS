# AgentOS startup script - Machine 1
# Starts Hermes gateway and Hermes proxy where credentials are available.

param(
    [string]$ProxyProvider = "nous",
    [int]$ProxyPort = 8080,
    [switch]$SkipGateway,
    [switch]$SkipProxy,
    [switch]$StartWatchdog
)

$ErrorActionPreference = "Stop"

$HermesRoot = "E:\AI_Projects_Hub\External_AI_Agents\hermes-agent"
$HermesExe = Join-Path $HermesRoot ".venv\Scripts\hermes.exe"
$AgentOSRoot = "E:\AgentOS"
$LogDir = Join-Path $AgentOSRoot "logs"

if (-not (Test-Path -LiteralPath $HermesExe)) {
    throw "Hermes executable not found: $HermesExe"
}

if (-not (Test-Path -LiteralPath $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}

Write-Host "=== AgentOS startup ===" -ForegroundColor Cyan
Write-Host "Hermes: $HermesExe" -ForegroundColor DarkGray
Write-Host "AgentOS: $AgentOSRoot" -ForegroundColor DarkGray

& $HermesExe --version

function Start-AgentOSProcess {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string[]]$ArgumentList
    )

    $stdout = Join-Path $LogDir "$Name.stdout.log"
    $stderr = Join-Path $LogDir "$Name.stderr.log"

    $process = Start-Process -FilePath $HermesExe `
        -ArgumentList $ArgumentList `
        -WorkingDirectory $HermesRoot `
        -WindowStyle Hidden `
        -RedirectStandardOutput $stdout `
        -RedirectStandardError $stderr `
        -PassThru

    Start-Sleep -Seconds 3

    if ($process.HasExited) {
        Write-Host "[$Name] exited during startup." -ForegroundColor Yellow
        if (Test-Path -LiteralPath $stderr) {
            Get-Content -LiteralPath $stderr -TotalCount 80
        }
        if (Test-Path -LiteralPath $stdout) {
            Get-Content -LiteralPath $stdout -TotalCount 80
        }
    } else {
        Write-Host "[$Name] running. PID=$($process.Id)" -ForegroundColor Green
        Write-Host "[$Name] logs: $stdout / $stderr" -ForegroundColor DarkGray
    }
}

if (-not $SkipGateway) {
    Start-AgentOSProcess -Name "hermes-gateway" -ArgumentList @("gateway", "run", "--accept-hooks")
}

if (-not $SkipProxy) {
    Start-AgentOSProcess -Name "hermes-proxy" -ArgumentList @("proxy", "start", "--provider", $ProxyProvider, "--host", "127.0.0.1", "--port", [string]$ProxyPort)
    $env:OPENAI_BASE_URL = "http://localhost:$ProxyPort/v1"
    Write-Host "[Codex] OPENAI_BASE_URL set for this PowerShell session: $env:OPENAI_BASE_URL" -ForegroundColor Green
    Write-Host "[Proxy] If startup says not logged in, run: hermes login $ProxyProvider" -ForegroundColor Yellow
}


if ($StartWatchdog) {
    $watchdog = Join-Path $AgentOSRoot "scripts\watchdog.ps1"
    if (Test-Path -LiteralPath $watchdog) {
        $stdout = Join-Path $LogDir "watchdog.stdout.log"
        $stderr = Join-Path $LogDir "watchdog.stderr.log"
        $p = Start-Process -FilePath "powershell.exe" `
            -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $watchdog, "-StartProxy") `
            -WorkingDirectory $AgentOSRoot `
            -WindowStyle Hidden `
            -RedirectStandardOutput $stdout `
            -RedirectStandardError $stderr `
            -PassThru
        Write-Host "[Watchdog] running. PID=$($p.Id)" -ForegroundColor Green
    } else {
        Write-Host "[Watchdog] script not found: $watchdog" -ForegroundColor Yellow
    }
}
Write-Host "=== AgentOS startup complete ===" -ForegroundColor Cyan





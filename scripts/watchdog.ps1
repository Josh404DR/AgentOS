# AgentOS Hermes watchdog
# Keeps Hermes gateway running and records basic health state.

param(
    [int]$CheckIntervalSeconds = 60,
    [switch]$Once,
    [switch]$StartProxy,
    [string]$ProxyProvider = "nous",
    [int]$ProxyPort = 8080
)

$ErrorActionPreference = "Continue"

$HermesRoot = "E:\AI_Projects_Hub\External_AI_Agents\hermes-agent"
$HermesExe = Join-Path $HermesRoot ".venv\Scripts\hermes.exe"
$AgentOSRoot = "E:\AgentOS"
$LogDir = Join-Path $AgentOSRoot "logs"
$StateFile = Join-Path $LogDir "watchdog_state.json"

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Write-State {
    param([hashtable]$State)
    $State.updated = (Get-Date).ToString("s")
    $State | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $StateFile -Encoding UTF8
}

function Start-HermesProcess {
    param([string]$Name, [string[]]$ProcArgs)
    $stdout = Join-Path $LogDir "$Name.stdout.log"
    $stderr = Join-Path $LogDir "$Name.stderr.log"
    return Start-Process -FilePath $HermesExe -ArgumentList $ProcArgs -WorkingDirectory $HermesRoot -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
}

function Get-HermesGatewayProcesses {
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object {
            ($_.CommandLine -match 'cli\.py\s+--gateway') -or
            (($_.CommandLine -match 'hermes(\.exe)?') -and ($_.CommandLine -match 'gateway\s+run'))
        }
}

function Ensure-Gateway {
    $running = @(Get-HermesGatewayProcesses)
    if ($running.Count -gt 0) {
        $mode = if (($running | Where-Object { $_.CommandLine -match 'cli\.py\s+--gateway' }).Count -gt 0) { "legacy-cli-py-gateway" } else { "hermes-gateway-run" }
        return @{ running = $true; restarted = $false; mode = $mode; pids = @($running | ForEach-Object { $_.ProcessId }) }
    }

    $p = Start-HermesProcess -Name "hermes-gateway" -ProcArgs @("gateway", "run", "--accept-hooks")
    Start-Sleep -Seconds 5
    $after = @(Get-HermesGatewayProcesses)
    if ($after.Count -gt 0) {
        return @{ running = $true; restarted = $true; mode = "hermes-gateway-run"; pids = @($after | ForEach-Object { $_.ProcessId }) }
    }
    return @{ running = $false; restarted = $true; mode = "failed"; pids = @(); exitCode = $p.ExitCode }
}

function Check-Proxy {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$ProxyPort/v1/models" -UseBasicParsing -TimeoutSec 5 -Headers @{ Authorization = "Bearer watchdog" }
        return @{ reachable = $true; status = [int]$response.StatusCode }
    } catch {
        return @{ reachable = $false; error = $_.Exception.Message }
    }
}

function Ensure-Proxy {
    if (-not $StartProxy) { return @{ requested = $false } }
    $check = Check-Proxy
    if ($check.reachable) { return @{ requested = $true; running = $true; restarted = $false } }

    $p = Start-HermesProcess -Name "hermes-proxy" -ProcArgs @("proxy", "start", "--provider", $ProxyProvider, "--host", "127.0.0.1", "--port", [string]$ProxyPort)
    Start-Sleep -Seconds 5
    $after = Check-Proxy
    return @{ requested = $true; running = $after.reachable; restarted = $true; pid = $p.Id; lastError = $after.error }
}

while ($true) {
    $gateway = Ensure-Gateway
    $proxy = Ensure-Proxy
    $cron = & $HermesExe cron list 2>&1 | Out-String

    Write-State @{
        gateway = $gateway
        proxy = $proxy
        cronSummary = ($cron -split "`r?`n" | Select-String -Pattern "daily-|Gateway is not running" | ForEach-Object { $_.Line })
    }

    if ($Once) { break }
    Start-Sleep -Seconds $CheckIntervalSeconds
}




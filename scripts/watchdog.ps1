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

function Set-HermesApiServerEnvironment {
    $settings = @{}
    foreach ($name in @(
        "API_SERVER_ENABLED",
        "API_SERVER_HOST",
        "API_SERVER_PORT",
        "API_SERVER_KEY"
    )) {
        $value = [Environment]::GetEnvironmentVariable($name, "User")
        if ([string]::IsNullOrWhiteSpace($value)) {
            throw "Required user environment variable is missing: $name"
        }
        $settings[$name] = $value
    }

    if ($settings.API_SERVER_ENABLED -ne "true") {
        throw "API_SERVER_ENABLED must be true"
    }
    if ($settings.API_SERVER_HOST -ne "127.0.0.1") {
        throw "API_SERVER_HOST must be 127.0.0.1"
    }
    $port = 0
    if (
        -not [int]::TryParse($settings.API_SERVER_PORT, [ref]$port) -or
        $port -lt 1 -or
        $port -gt 65535
    ) {
        throw "API_SERVER_PORT must be a valid TCP port"
    }
    if ($settings.API_SERVER_KEY.Length -lt 32) {
        throw "API_SERVER_KEY must contain at least 32 characters"
    }

    foreach ($name in $settings.Keys) {
        [Environment]::SetEnvironmentVariable(
            $name,
            $settings[$name],
            "Process"
        )
    }
}

function Get-HermesGatewayProcesses {
    $lockPath = Join-Path $env:LOCALAPPDATA "hermes\gateway.lock"
    if (-not (Test-Path -LiteralPath $lockPath -PathType Leaf)) {
        return @()
    }
    try {
        $lock = Get-Content -Raw -LiteralPath $lockPath -Encoding UTF8 |
            ConvertFrom-Json -ErrorAction Stop
        $processId = [int]$lock.pid
        $process = Get-CimInstance Win32_Process `
            -Filter "ProcessId=$processId" `
            -ErrorAction Stop
        if (
            $process.CommandLine -match 'cli\.py\s+--gateway' -or
            (
                $process.CommandLine -match 'hermes(\.exe)?' -and
                $process.CommandLine -match 'gateway\s+run'
            )
        ) {
            return @($process)
        }
    } catch {
        return @()
    }
    return @()
}

function Ensure-Gateway {
    $running = @(Get-HermesGatewayProcesses)
    if ($running.Count -gt 0) {
        $mode = if (($running | Where-Object { $_.CommandLine -match 'cli\.py\s+--gateway' }).Count -gt 0) { "legacy-cli-py-gateway" } else { "hermes-gateway-run" }
        return @{ running = $true; restarted = $false; mode = $mode; pids = @($running | ForEach-Object { $_.ProcessId }) }
    }

    Set-HermesApiServerEnvironment
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




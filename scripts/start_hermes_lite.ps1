[CmdletBinding()]
param(
    [string]$AgentOSRoot = "E:\AgentOS",
    [string]$HermesRoot,
    [string]$ProfileHome = "$env:LOCALAPPDATA\hermes-lite",
    [string]$TelegramAllowedUsers = "1449022024",
    [switch]$ValidateOnly
)

$ErrorActionPreference = "Stop"
$utf8 = [Text.UTF8Encoding]::new($false)
$runtimeLoader = Join-Path $AgentOSRoot "scripts\lib\runtime_config.ps1"
. $runtimeLoader
$runtimeConfig = Get-AgentOSRuntimeConfig -AgentOSRoot $AgentOSRoot
if ([string]::IsNullOrWhiteSpace($HermesRoot)) {
    $HermesRoot = [string]$runtimeConfig.hermes.root
    $hermesExe = [string]$runtimeConfig.hermes.executable
} else {
    $hermesExe = Join-Path $HermesRoot ".venv\Scripts\hermes.exe"
}
$envPath = Join-Path $ProfileHome ".env"
$configPath = Join-Path $ProfileHome "config.yaml"
$pluginSource = Join-Path $AgentOSRoot "integrations\hermes_plugins\agentos-typed-dispatch"
$pluginTarget = Join-Path $ProfileHome "plugins\agentos-typed-dispatch"
$logDir = Join-Path $AgentOSRoot "logs"
$stdoutPath = Join-Path $logDir "hermes-lite-gateway.stdout.log"
$stderrPath = Join-Path $logDir "hermes-lite-gateway.stderr.log"
$receiptWriter = Join-Path $AgentOSRoot "scripts\observability\write-gateway-runtime-receipt.ps1"

foreach ($required in @($hermesExe, $envPath, (Join-Path $pluginSource "__init__.py"))) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required Hermes Lite file missing: $required"
    }
}

$envNames = @{}
foreach ($line in Get-Content -LiteralPath $envPath -Encoding UTF8) {
    if ($line -match '^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+)$') {
        $envNames[$matches[1]] = $true
    }
}
foreach ($requiredName in @("TELEGRAM_BOT_TOKEN", "GROQ_API_KEY")) {
    if (-not $envNames.ContainsKey($requiredName)) {
        throw "Hermes Lite environment variable missing: $requiredName"
    }
}

if ($ValidateOnly) {
    Write-Output "hermes_lite_validation=passed"
    Write-Output "profile_home=$ProfileHome"
    Write-Output "secrets_printed=false"
    exit 0
}

New-Item -ItemType Directory -Force -Path $ProfileHome, $pluginTarget, $logDir | Out-Null

if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    $config = @"
model:
  default: llama-3.1-8b-instant
  provider: agentos-groq
  base_url: https://api.groq.com/openai/v1
providers:
  agentos-groq:
    name: Hermes Lite Groq
    base_url: https://api.groq.com/openai/v1
    key_env: GROQ_API_KEY
    default_model: llama-3.1-8b-instant
    api_mode: openai_chat
fallback_providers: []
toolsets: []
agent:
  max_turns: 8
  gateway_timeout: 120
telegram:
  reactions: false
  channel_prompts: {}
  allowed_chats: ''
plugins:
  enabled:
    - agentos-typed-dispatch
  disabled: []
"@
    [IO.File]::WriteAllText($configPath, $config, $utf8)
}

$configText = [IO.File]::ReadAllText($configPath, [Text.Encoding]::UTF8)
if ($configText -notmatch '(?m)^plugins:\s*$') {
    $pluginConfig = @"

plugins:
  enabled:
    - agentos-typed-dispatch
  disabled: []
"@
    [IO.File]::AppendAllText($configPath, $pluginConfig, $utf8)
}

Copy-Item -LiteralPath (Join-Path $pluginSource "__init__.py") `
    -Destination (Join-Path $pluginTarget "__init__.py") -Force
Copy-Item -LiteralPath (Join-Path $pluginSource "plugin.yaml") `
    -Destination (Join-Path $pluginTarget "plugin.yaml") -Force

$previousHome = $env:HERMES_HOME
$previousMode = $env:AGENTOS_PLUGIN_MODE
$previousAllowedUsers = $env:TELEGRAM_ALLOWED_USERS
try {
    $env:HERMES_HOME = $ProfileHome
    $env:AGENTOS_PLUGIN_MODE = "chat_only"
    $env:TELEGRAM_ALLOWED_USERS = $TelegramAllowedUsers
    $process = Start-Process -FilePath $hermesExe `
        -ArgumentList @("gateway", "run", "--replace") `
        -WorkingDirectory $HermesRoot `
        -WindowStyle Hidden `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -PassThru
} finally {
    $env:HERMES_HOME = $previousHome
    $env:AGENTOS_PLUGIN_MODE = $previousMode
    $env:TELEGRAM_ALLOWED_USERS = $previousAllowedUsers
}

Start-Sleep -Seconds 8
if ($process.HasExited) {
    Write-Output "hermes_lite_status=failed"
    Write-Output "exit_code=$($process.ExitCode)"
    Write-Output "stderr_path=$stderrPath"
    exit 1
}

try {
    & $receiptWriter `
        -ReceiptId "hermes-lite-gateway" `
        -RuntimeId "hermes-lite-gateway" `
        -ProfileLockPath (Join-Path $ProfileHome "gateway.lock") `
        -AgentOSRoot $AgentOSRoot | Out-Null
} catch {
    Write-Warning "Hermes Lite is running but receipt reconciliation failed: $($_.Exception.Message)"
}

Write-Output "hermes_lite_status=running"
Write-Output "process_id=$($process.Id)"
Write-Output "profile_home=$ProfileHome"
Write-Output "plugin_mode=chat_only"
Write-Output "telegram_access=restricted_allowlist"
Write-Output "secrets_printed=false"
Write-Output "stdout_path=$stdoutPath"
Write-Output "stderr_path=$stderrPath"

# AgentOS free-model window guard
# This script is a safety wrapper for future cheap/free cloud chat windows.
# It does not call any provider unless -Invoke is supplied.

param(
    [ValidateSet("groq", "openrouter")]
    [string]$Provider = "groq",
    [string]$Message,
    [string]$AgentOSRoot = "E:\AgentOS",
    [switch]$Invoke
)

$ErrorActionPreference = "Stop"

function Read-JsonFile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Required config not found: $Path"
    }
    return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
}

function Save-JsonFile([string]$Path, $Data) {
    $json = $Data | ConvertTo-Json -Depth 12
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, $utf8NoBom)
}

function Get-EnvValue([string]$Name) {
    if (-not $Name) { return "" }
    $value = [Environment]::GetEnvironmentVariable($Name, "Process")
    if ($value) { return $value }
    $value = [Environment]::GetEnvironmentVariable($Name, "User")
    if ($value) { return $value }
    $value = [Environment]::GetEnvironmentVariable($Name, "Machine")
    if ($value) { return $value }
    return ""
}

$configPath = Join-Path $AgentOSRoot "config\free_model_providers.json"
$config = Read-JsonFile $configPath
$providerConfig = $config.providers.$Provider
if (-not $providerConfig) {
    throw "Provider not configured: $Provider"
}

$today = Get-Date -Format "yyyy-MM-dd"
$usageDir = Join-Path $AgentOSRoot "data\routing"
New-Item -ItemType Directory -Force -Path $usageDir | Out-Null
$usagePath = Join-Path $usageDir ("free_model_usage_" + $today + ".json")

if (Test-Path -LiteralPath $usagePath) {
    $usage = Read-JsonFile $usagePath
} else {
    $usage = [ordered]@{
        date = $today
        providers = [ordered]@{}
    }
}

if (-not $usage.providers.$Provider) {
    $usage.providers | Add-Member -NotePropertyName $Provider -NotePropertyValue ([ordered]@{
        attempted_requests = 0
        completed_requests = 0
        blocked_requests = 0
    })
}

$providerUsage = $usage.providers.$Provider
$cap = [int]$providerConfig.daily_request_cap
$apiKeyName = [string]$providerConfig.api_key_env
$apiKey = Get-EnvValue $apiKeyName

$status = "ready"
$reason = "within_cap"

if (-not $apiKey) {
    $status = "blocked_missing_api_key"
    $reason = "Set $apiKeyName before invoking provider calls."
}
if ([int]$providerUsage.attempted_requests -ge $cap) {
    $status = "blocked_daily_cap"
    $reason = "Daily cap reached for $Provider ($cap attempted requests)."
}
if (-not $Invoke) {
    $status = "dry_run"
    $reason = "No provider call executed because -Invoke was not supplied."
}

Write-Output "provider=$Provider"
Write-Output "model=$($providerConfig.default_model)"
Write-Output "base_url=$($providerConfig.base_url)"
Write-Output "daily_request_cap=$cap"
Write-Output "attempted_requests_today=$($providerUsage.attempted_requests)"
Write-Output "status=$status"
Write-Output "reason=$reason"
Write-Output "paid_models_allowed=false"
Write-Output "paid_tools_allowed=false"
Write-Output "fallback_to_gemini=false"

if ($status -ne "ready") {
    if ($status -like "blocked_*") {
        $providerUsage.blocked_requests = [int]$providerUsage.blocked_requests + 1
        Save-JsonFile $usagePath $usage
    }
    exit 0
}

if (-not $Message) {
    throw "Provide -Message when using -Invoke."
}

# Count before network call so failed attempts are still visible.
$providerUsage.attempted_requests = [int]$providerUsage.attempted_requests + 1
Save-JsonFile $usagePath $usage

throw "Provider invocation is intentionally not implemented yet. This guard is installed before live provider wiring."

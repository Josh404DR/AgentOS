# AgentOS free-model window guard
# This script is a safety wrapper for future cheap/free cloud chat windows.
# It does not call any provider unless -Invoke is supplied.

param(
    [ValidateSet("groq", "openrouter")]
    [string]$Provider = "groq",
    [string]$Message,
    [string]$AgentOSRoot = "E:\AgentOS",
    [int]$MaxTokens = 120,
    [int]$MaxMessageChars = 6000,
    [switch]$Invoke
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$governanceGate = Join-Path $AgentOSRoot "scripts\assert_governance_ready.ps1"
$governanceOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $governanceGate -AgentOSRoot $AgentOSRoot
if ($LASTEXITCODE -ne 0) { throw "Governance gate blocked free-model window.`n$($governanceOutput -join "`n")" }

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

function New-UsageState([string]$Date) {
    return [pscustomobject]@{
        date = $Date
        providers = [pscustomobject]@{}
    }
}

function Ensure-UsageShape($Usage, [string]$Date) {
    if (-not $Usage) {
        return New-UsageState $Date
    }
    if (-not $Usage.PSObject.Properties["date"]) {
        $Usage | Add-Member -NotePropertyName "date" -NotePropertyValue $Date
    }
    if (-not $Usage.PSObject.Properties["providers"] -or -not $Usage.providers) {
        $Usage | Add-Member -NotePropertyName "providers" -NotePropertyValue ([pscustomobject]@{}) -Force
    }
    return $Usage
}

function Get-ProviderUsage($Usage, [string]$ProviderName) {
    if (-not $Usage.providers.PSObject.Properties[$ProviderName]) {
        $Usage.providers | Add-Member -NotePropertyName $ProviderName -NotePropertyValue ([pscustomobject]@{
            attempted_requests = 0
            completed_requests = 0
            blocked_requests = 0
        })
    }
    return $Usage.providers.$ProviderName
}

function Invoke-FreeChatCompletion($ProviderConfig, [string]$ProviderName, [string]$ApiKey, [string]$Message, [int]$MaxTokens) {
    $model = [string]$ProviderConfig.default_model
    if ($ProviderName -eq "openrouter") {
        $allowed = $false
        if ($model -eq "openrouter/free") { $allowed = $true }
        if ($model.EndsWith(":free")) { $allowed = $true }
        if (-not $allowed) {
            throw "OpenRouter guard blocked non-free model: $model"
        }
    }

    $uri = ([string]$ProviderConfig.base_url).TrimEnd("/") + "/chat/completions"
    $headers = @{
        Authorization = "Bearer $ApiKey"
        "Content-Type" = "application/json"
    }
    if ($ProviderName -eq "openrouter") {
        $headers["HTTP-Referer"] = "https://agentos.local"
        $headers["X-Title"] = "AgentOS Free Window Guard"
    }

    $liteSystem = @"
You are Hermes Lite, the low-cost Telegram intake voice for AgentOS.
Answer briefly in the same language Josh uses.
You have no tools in this mode. Do not claim file, routing, fetch, model, or
external actions unless the current message contains explicit artifact output.
Ordinary conversation is context, not permission to execute.
For real work, ask Josh to use a URL or an explicit [TYPE: ...] dispatch.
"@

    $body = @{
        model = $model
        messages = @(
            @{
                role = "system"
                content = $liteSystem
            },
            @{
                role = "user"
                content = $Message
            }
        )
        max_tokens = $MaxTokens
        temperature = 0.2
    } | ConvertTo-Json -Depth 8

    $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    $raw = Invoke-WebRequest -UseBasicParsing -Method Post -Uri $uri -Headers $headers -Body $bodyBytes -ContentType "application/json; charset=utf-8" -TimeoutSec 45
    $stream = $raw.RawContentStream
    if ($stream.CanSeek) {
        $stream.Position = 0
    }
    $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8, $true)
    $responseText = $reader.ReadToEnd()
    return $responseText | ConvertFrom-Json
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
    $usage = New-UsageState $today
}

$usage = Ensure-UsageShape $usage $today
$providerUsage = Get-ProviderUsage $usage $Provider
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
if ($Message.Length -gt $MaxMessageChars) {
    Write-Output "provider_call_status=blocked"
    Write-Output "reason=message_exceeds_lite_limit"
    Write-Output "message_chars=$($Message.Length)"
    Write-Output "max_message_chars=$MaxMessageChars"
    Write-Output "models_invoked=false"
    Write-Output "external_services_invoked=false"
    exit 0
}

# Count before network call so failed attempts are still visible.
$providerUsage.attempted_requests = [int]$providerUsage.attempted_requests + 1
Save-JsonFile $usagePath $usage

try {
    $response = Invoke-FreeChatCompletion $providerConfig $Provider $apiKey $Message $MaxTokens
    $providerUsage.completed_requests = [int]$providerUsage.completed_requests + 1
    Save-JsonFile $usagePath $usage
    $content = ""
    try {
        $content = [string]$response.choices[0].message.content
    } catch {
        $content = ""
    }
    Write-Output "provider_call_status=completed"
    Write-Output "attempted_requests_today=$($providerUsage.attempted_requests)"
    Write-Output "completed_requests_today=$($providerUsage.completed_requests)"
    Write-Output "models_invoked=true"
    Write-Output "external_services_invoked=true"
    $contentBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($content))
    Write-Output "response_base64_begin"
    Write-Output $contentBase64
    Write-Output "response_base64_end"
    Write-Output "response_begin"
    Write-Output $content
    Write-Output "response_end"
} catch {
    $providerUsage.blocked_requests = [int]$providerUsage.blocked_requests + 1
    Save-JsonFile $usagePath $usage
    Write-Output "provider_call_status=failed"
    Write-Output "attempted_requests_today=$($providerUsage.attempted_requests)"
    Write-Output "blocked_requests_today=$($providerUsage.blocked_requests)"
    Write-Output "models_invoked=attempted"
    Write-Output "external_services_invoked=attempted"
    Write-Output ("error=" + $_.Exception.Message)
    exit 1
}

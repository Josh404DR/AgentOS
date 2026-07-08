# AgentOS Hermes model fallback
# Runs a lightweight Hermes test and switches to backup Gemini models on quota/rate/auth failures.

param(
    [string[]]$FallbackModels = @("gemini-3.1-flash-lite-preview", "gemini-2.5-flash"),
    [string]$PrimaryModel = "gemini-3-flash-preview"
)

$ErrorActionPreference = "Continue"

$HermesRoot = "E:\AI_Projects_Hub\External_AI_Agents\hermes-agent"
$HermesExe = Join-Path $HermesRoot ".venv\Scripts\hermes.exe"
$AgentOSRoot = "E:\AgentOS"
$LogDir = Join-Path $AgentOSRoot "logs"
$StateFile = Join-Path $LogDir "model_fallback_state.json"

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Save-State {
    param([hashtable]$State)
    $State.updated = (Get-Date).ToString("s")
    $State | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $StateFile -Encoding UTF8
}

function Test-HermesModel {
    $output = & $HermesExe -z "healthcheck: reply with OK only" 2>&1
    $exit = $LASTEXITCODE
    return @{ exitCode = $exit; output = ($output | Out-String) }
}

function Is-QuotaLikeFailure {
    param([string]$Text)
    return $Text -match '(quota|rate.limit|rate limit|429|exhaust|insufficient|auth|unauthorized|forbidden|invalid api key|overload|temporarily unavailable)'
}

$initial = Test-HermesModel
if ($initial.exitCode -eq 0 -and $initial.output -match 'OK') {
    Save-State @{ status = "ok"; action = "none"; activeModel = "current"; test = "passed" }
    Write-Host "Hermes model health OK." -ForegroundColor Green
    exit 0
}

if (-not (Is-QuotaLikeFailure $initial.output)) {
    Save-State @{ status = "failed"; action = "none"; reason = "non-quota failure"; output = $initial.output }
    Write-Host "Hermes failed, but error did not look quota/provider related. No model switch performed." -ForegroundColor Yellow
    exit 1
}

foreach ($model in $FallbackModels) {
    & $HermesExe config set model.provider gemini | Out-Null
    & $HermesExe config set model.default $model | Out-Null
    & $HermesExe config set model.base_url "https://generativelanguage.googleapis.com/v1beta/openai" | Out-Null

    $test = Test-HermesModel
    if ($test.exitCode -eq 0 -and $test.output -match 'OK') {
        Save-State @{ status = "switched"; action = "model.default"; activeModel = $model; previousPrimary = $PrimaryModel; test = "passed" }
        Write-Host "Switched Hermes to fallback model: $model" -ForegroundColor Green
        exit 0
    }
}

Save-State @{ status = "exhausted"; action = "none"; tried = $FallbackModels; initialOutput = $initial.output }
Write-Host "All fallback models failed. Manual intervention required." -ForegroundColor Red
exit 2

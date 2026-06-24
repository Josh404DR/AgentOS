# AgentOS Telegram typed-dispatch entrypoint
# Safe local wrapper intended for future Hermes Telegram hook integration.
# It does not talk to Telegram, Gemini, Codex, Claude, Ollama, or external
# services. It only calls scripts\typed_dispatch.ps1 and records the result.

param(
    [string]$MessageText,
    [string]$MessageFile,
    [string]$AgentOSRoot = "E:\AgentOS",
    [string]$DispatchId = ("telegram-" + (Get-Date -Format "yyyy-MM-dd-HHmmss")),
    [switch]$NoWrite
)

$ErrorActionPreference = "Stop"

$TypedDispatch = Join-Path $AgentOSRoot "scripts\typed_dispatch.ps1"
if (-not (Test-Path -LiteralPath $TypedDispatch)) {
    throw "typed dispatch runner not found: $TypedDispatch"
}

if (-not $MessageText -and -not $MessageFile) {
    throw "Provide -MessageText or -MessageFile."
}

$argsList = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $TypedDispatch,
    "-AgentOSRoot", $AgentOSRoot,
    "-DispatchId", $DispatchId
)

if ($MessageFile) {
    $argsList += @("-InputFile", $MessageFile)
} else {
    $argsList += @("-InputText", $MessageText)
}

if ($NoWrite) {
    $argsList += "-NoWrite"
}

$output = & powershell @argsList
$exit = $LASTEXITCODE

if ($exit -ne 0) {
    throw "typed dispatch failed with exit code $exit"
}

$output | ForEach-Object { Write-Output $_ }
Write-Output "telegram_hook_invoked=false"
Write-Output "external_services_invoked=false"

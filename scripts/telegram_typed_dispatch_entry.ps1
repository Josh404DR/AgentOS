# AgentOS Telegram typed-dispatch entrypoint
# Safe local wrapper intended for future Hermes Telegram hook integration.
# It does not talk to Telegram, Gemini, Codex, Claude, Ollama, or external
# services. It only calls scripts\typed_dispatch.ps1 and records the result.

param(
    [string]$MessageText,
    [string]$MessageFile,
    [string]$AgentOSRoot = "E:\AgentOS",
    [string]$DispatchId = ("telegram-" + (Get-Date -Format "yyyy-MM-dd-HHmmss")),
    [switch]$TelegramHookInvoked,
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

$cleanupTempFile = $false
$tempMsgFile = ""
if ($MessageFile) {
    $argsList += @("-InputFile", $MessageFile)
} else {
    # Write to a UTF-8 NoBOM temp file to avoid CJK character mangling when
    # PowerShell 5.1 serialises the command-line across the process boundary
    # on CP950 (Traditional Chinese) Windows systems.
    $tempMsgFile = [IO.Path]::GetTempFileName()
    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($tempMsgFile, $MessageText, $Utf8NoBom)
    $argsList += @("-InputFile", $tempMsgFile)
    $cleanupTempFile = $true
}

if ($NoWrite) {
    $argsList += "-NoWrite"
}

$output = & powershell @argsList
$exit = $LASTEXITCODE

if ($cleanupTempFile -and $tempMsgFile) {
    Remove-Item -LiteralPath $tempMsgFile -Force -ErrorAction SilentlyContinue
}

if ($exit -ne 0) {
    throw "typed dispatch failed with exit code $exit"
}

$output | ForEach-Object { Write-Output $_ }
Write-Output ("telegram_hook_invoked={0}" -f $TelegramHookInvoked.IsPresent.ToString().ToLowerInvariant())
Write-Output "external_services_invoked=false"

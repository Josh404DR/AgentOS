# AgentOS Hermes <-> Codex live bridge
# Runs one real CLI handoff:
# Hermes generates a message -> Codex answers -> Hermes summarizes Codex result.

param(
    [string]$BridgeId = (Get-Date -Format "yyyy-MM-dd-HHmmss"),
    [string]$AgentOSRoot = "E:\AgentOS",
    [string]$HermesRoot = "E:\AI_Projects_Hub\External_AI_Agents\hermes-agent",
    [string]$CodexPrompt = "Codex, this is a live bridge test from Hermes. Reply in ASCII only with three lines: RECEIVED=YES, NEXT_ACTION=<one safe AgentOS action>, BOUNDARY=<one safety boundary>."
)

$ErrorActionPreference = "Stop"

$HermesExe = Join-Path $HermesRoot ".venv\Scripts\hermes.exe"
$RunDir = Join-Path $AgentOSRoot "data\live_bridge\$BridgeId"
$HermesToCodexPath = Join-Path $RunDir "01_HERMES_TO_CODEX.md"
$CodexReplyPath = Join-Path $RunDir "02_CODEX_REPLY.md"
$HermesSummaryPath = Join-Path $RunDir "03_HERMES_SUMMARY.md"
$TranscriptPath = Join-Path $RunDir "TRANSCRIPT.md"

if (-not (Test-Path -LiteralPath $HermesExe)) {
    throw "Hermes executable not found: $HermesExe"
}

New-Item -ItemType Directory -Force -Path $RunDir | Out-Null

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm zzz"

$hermesPrompt = @"
You are Hermes, the AgentOS coordinator.

Create a concise message addressed to Codex for a live bridge test.
Ask Codex to confirm it received the message, state the next safe AgentOS action, and name one boundary.

Important:
- Do not contact clients.
- Do not claim this is Telegram automation.
- Keep it under 120 words.
- Ask Codex to reply in ASCII-only key=value lines so Windows CLI transcripts remain readable.

Codex task seed:
$CodexPrompt
"@

$hermesMessage = & $HermesExe -z $hermesPrompt
$hermesExit = $LASTEXITCODE
if ($hermesExit -ne 0) {
    throw "Hermes failed with exit code $hermesExit"
}

Set-Content -LiteralPath $HermesToCodexPath -Encoding UTF8 -Value @"
# Hermes To Codex

Created: $timestamp
Bridge id: $BridgeId

$hermesMessage
"@

$codexInput = @"
You are Codex receiving a live message from Hermes through AgentOS' CLI bridge.

Hermes message:
---
$hermesMessage
---

Please answer Hermes directly. Keep the answer concise. Use ASCII only. Do not modify files. Do not contact clients.
"@

$oldOpenAiApiKey = [Environment]::GetEnvironmentVariable("OPENAI_API_KEY", "Process")
$oldCodexApiKey = [Environment]::GetEnvironmentVariable("CODEX_API_KEY", "Process")

try {
    Remove-Item Env:\OPENAI_API_KEY -ErrorAction SilentlyContinue
    Remove-Item Env:\CODEX_API_KEY -ErrorAction SilentlyContinue

    $oldErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $codexConsole = & codex -a never exec -C $AgentOSRoot --sandbox read-only --output-last-message $CodexReplyPath $codexInput 2>&1
    $codexExit = $LASTEXITCODE
} finally {
    if ($null -ne $oldErrorActionPreference) { $ErrorActionPreference = $oldErrorActionPreference }
    if ($null -ne $oldOpenAiApiKey) { [Environment]::SetEnvironmentVariable("OPENAI_API_KEY", $oldOpenAiApiKey, "Process") }
    if ($null -ne $oldCodexApiKey) { [Environment]::SetEnvironmentVariable("CODEX_API_KEY", $oldCodexApiKey, "Process") }
}

if ($codexExit -ne 0) {
    $codexConsole | Out-String | Set-Content -LiteralPath (Join-Path $RunDir "CODEX_ERROR.log") -Encoding UTF8
    throw "Codex failed with exit code $codexExit. See CODEX_ERROR.log"
}

$codexReply = Get-Content -Raw -LiteralPath $CodexReplyPath

$summaryPrompt = @"
You are Hermes. Codex replied to your live bridge test.

Summarize the result for Josh in Traditional Chinese.
Say clearly whether Hermes and Codex communicated through the CLI bridge.
Also mention that this is not yet Telegram automation or a long-running daemon.

Codex reply:
---
$codexReply
---
"@

$hermesSummary = & $HermesExe -z $summaryPrompt
$summaryExit = $LASTEXITCODE
if ($summaryExit -ne 0) {
    throw "Hermes summary failed with exit code $summaryExit"
}

Set-Content -LiteralPath $HermesSummaryPath -Encoding UTF8 -Value @"
# Hermes Summary

Created: $(Get-Date -Format "yyyy-MM-dd HH:mm zzz")
Bridge id: $BridgeId

$hermesSummary
"@

Set-Content -LiteralPath $TranscriptPath -Encoding UTF8 -Value @"
# Hermes Codex Live Bridge Transcript

Created: $timestamp
Bridge id: $BridgeId
Status: success

## Files

- Hermes to Codex: $HermesToCodexPath
- Codex reply: $CodexReplyPath
- Hermes summary: $HermesSummaryPath

## Hermes To Codex

$hermesMessage

## Codex Reply

$codexReply

## Hermes Summary

$hermesSummary
"@

Write-Host "Hermes-Codex live bridge succeeded." -ForegroundColor Green
Write-Host $TranscriptPath

# DEPRECATED — 2026-07-08 (W20)
# 此腳本為 live bridge/test pipeline，不是通用的 TASK.md 讀取器。
# 正式任務路由請使用：scripts\dispatch_task_packet.ps1 -DispatchId <id>
# 保留作為參考；非必要請勿直接呼叫。
#
# AgentOS Hermes <-> Claude CLI live bridge
# Runs one real CLI handoff:
# Hermes generates a message -> Claude CLI answers -> Hermes summarizes Claude result.

param(
    [string]$BridgeId = (Get-Date -Format "yyyy-MM-dd-HHmmss"),
    [string]$AgentOSRoot = "E:\AgentOS",
    [string]$HermesRoot,
    [string]$ClaudePrompt = "Claude, this is a live bridge test from Hermes. Reply concisely with your status and confirm you can read AgentOS files in read-only mode."
)

$ErrorActionPreference = "Stop"
$runtimeLoader = Join-Path $AgentOSRoot "scripts\lib\runtime_config.ps1"
. $runtimeLoader
$runtimeConfig = Get-AgentOSRuntimeConfig -AgentOSRoot $AgentOSRoot
if ([string]::IsNullOrWhiteSpace($HermesRoot)) {
    $HermesRoot = [string]$runtimeConfig.hermes.root
    $HermesExe = [string]$runtimeConfig.hermes.executable
} else {
    $HermesExe = Join-Path $HermesRoot ".venv\Scripts\hermes.exe"
}
$governanceGate = Join-Path $AgentOSRoot "scripts\assert_governance_ready.ps1"
$governanceOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $governanceGate -AgentOSRoot $AgentOSRoot
if ($LASTEXITCODE -ne 0) { throw "Governance gate blocked Hermes-Claude bridge.`n$($governanceOutput -join "`n")" }

$RunDir = Join-Path $AgentOSRoot "data\live_bridge\claude_$BridgeId"
$HermesToClaudePath = Join-Path $RunDir "01_HERMES_TO_CLAUDE.md"
$ClaudeReplyPath = Join-Path $RunDir "02_CLAUDE_REPLY.md"
$HermesSummaryPath = Join-Path $RunDir "03_HERMES_SUMMARY.md"
$TranscriptPath = Join-Path $RunDir "TRANSCRIPT.md"

if (-not (Test-Path -LiteralPath $HermesExe)) {
    throw "Hermes executable not found: $HermesExe"
}

New-Item -ItemType Directory -Force -Path $RunDir | Out-Null

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm zzz"

$hermesPrompt = @"
You are Hermes, the AgentOS coordinator.

Create a concise message addressed to Claude Code CLI for a live bridge test.
Ask Claude to confirm it can see the AgentOS directory and state one capability it provides to AgentOS (e.g., Code Review, Debugging).

Important:
- Do not contact clients.
- Keep it under 100 words.
- Ask Claude to provide its findings in a structured way (e.g., STATUS=READY).

Claude task seed:
$ClaudePrompt
"@

$hermesMessage = & $HermesExe -z $hermesPrompt
$hermesExit = $LASTEXITCODE
if ($hermesExit -ne 0) {
    throw "Hermes failed with exit code $hermesExit"
}

Set-Content -LiteralPath $HermesToClaudePath -Encoding UTF8 -Value @"
# Hermes To Claude

Created: $timestamp
Bridge id: $BridgeId

$hermesMessage
"@

$claudeInput = @"
You are Claude receiving a live message from Hermes through AgentOS' CLI bridge.

Hermes message:
---
$hermesMessage
---

Please answer Hermes directly. Keep the answer concise.
You are running in the AgentOS root: $AgentOSRoot.
"@

# Execute Claude CLI in non-interactive mode (-p)
# Using --bare to avoid overhead/discovery issues if needed
$claudeConsole = & claude -p $claudeInput
$claudeExit = $LASTEXITCODE

if ($claudeExit -ne 0) {
    $claudeConsole | Out-String | Set-Content -LiteralPath (Join-Path $RunDir "CLAUDE_ERROR.log") -Encoding UTF8
    throw "Claude failed with exit code $claudeExit. See CLAUDE_ERROR.log"
}

$claudeReply = $claudeConsole | Out-String
Set-Content -LiteralPath $ClaudeReplyPath -Encoding UTF8 -Value $claudeReply

$summaryPrompt = @"
You are Hermes. Claude CLI replied to your live bridge test.

Summarize the result for Josh in Traditional Chinese.
Confirm whether the Hermes -> Claude bridge is operational.
Mention that Claude is now an available verified resource for review and reasoning tasks.

Claude reply:
---
$claudeReply
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
# Hermes Claude Live Bridge Transcript

Created: $timestamp
Bridge id: $BridgeId
Status: success

## Files

- Hermes to Claude: $HermesToClaudePath
- Claude reply: $ClaudeReplyPath
- Hermes summary: $HermesSummaryPath

## Hermes To Claude

$hermesMessage

## Claude Reply

$claudeReply

## Hermes Summary

$hermesSummary
"@

Write-Host "Hermes-Claude live bridge succeeded." -ForegroundColor Green
Write-Host $TranscriptPath

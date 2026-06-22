# AgentOS Hermes <-> Codex <-> Claude Tripartite Bridge
# Pipeline: Hermes (Dispatch) -> Codex (Execution) -> Claude (Review) -> Hermes (Summary)
# Version: 1.13 (ZH-TW Mojibake Fallback)

param(
    [string]$BridgeId = (Get-Date -Format "yyyy-MM-dd-HHmmss"),
    [string]$AgentOSRoot = "E:\AgentOS",
    [string]$HermesRoot = "E:\AI_Projects_Hub\External_AI_Agents\hermes-agent",
    [string]$TaskSeed = "Verify the consistency of the 'Three-Agent Protocol' section across agents/roles/hermes.md, agents/roles/codex.md, and agents/roles/claude.md."
)

$ErrorActionPreference = "Stop"
$Utf8NoBom = New-Object System.Text.Utf8Encoding($false)

$HermesExe = Join-Path $HermesRoot ".venv\Scripts\hermes.exe"
$RunDir = Join-Path $AgentOSRoot "data\live_bridge\tripartite_$BridgeId"
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null

function Write-Checkpoint($msg) {
    $time = Get-Date -Format "HH:mm:ss"
    Write-Host "[$time] $msg" -ForegroundColor Cyan
}

Write-Checkpoint "Phase 1: Hermes Dispatch"
$hermesDispatchPrompt = "You are Hermes, the AgentOS coordinator. Create a technical task packet for Codex. Task: $TaskSeed. Instruct Codex to output its findings in ASCII-only key=value lines. Use neutral placeholders for values like <VALUE>."
$hermesDispatch = & $HermesExe -z $hermesDispatchPrompt | Out-String
if ($null -eq $hermesDispatch -or $hermesDispatch.Trim() -eq "") { throw "Hermes Dispatch failed" }
[System.IO.File]::WriteAllLines((Join-Path $RunDir "01_HERMES_DISPATCH.md"), $hermesDispatch, $Utf8NoBom)

Write-Checkpoint "Phase 2: Codex Execution"
$codexInput = "You are Codex. Execute the technical task from Hermes. Task Packet: $hermesDispatch. Output rules: 1. ASCII only. 2. key=value format. 3. Concise."
$codexInputPath = Join-Path $RunDir "CODEX_INPUT_TEMP.txt"
[System.IO.File]::WriteAllLines($codexInputPath, $codexInput, $Utf8NoBom)

$oldOpenAiApiKey = [Environment]::GetEnvironmentVariable("OPENAI_API_KEY", "Process")
$oldCodexApiKey = [Environment]::GetEnvironmentVariable("CODEX_API_KEY", "Process")
try {
    Remove-Item Env:\OPENAI_API_KEY -ErrorAction SilentlyContinue
    Remove-Item Env:\\CODEX_API_KEY -ErrorAction SilentlyContinue
    $codexOutputPath = Join-Path $RunDir "02_CODEX_OUTPUT.md"
    
    # Temporarily allow stderr without stopping
    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    # Use Get-Content to pipe input to avoid shell input redirection errors on Windows
    $codexConsole = Get-Content -LiteralPath $codexInputPath | & codex -a never exec -C $AgentOSRoot --sandbox read-only --output-last-message $codexOutputPath 2>&1
    $codexExit = $LASTEXITCODE
    
    $ErrorActionPreference = $oldEAP
} finally {
    if ($null -ne $oldOpenAiApiKey) { [Environment]::SetEnvironmentVariable("OPENAI_API_KEY", $oldOpenAiApiKey, "Process") }
    if ($null -ne $oldCodexApiKey) { [Environment]::SetEnvironmentVariable("CODEX_API_KEY", $oldCodexApiKey, "Process") }
}
if ($codexExit -ne 0) { throw "Codex failed with exit code $codexExit" }
$codexResult = Get-Content -Raw -LiteralPath $codexOutputPath

Write-Checkpoint "Phase 3: Claude Review"
$claudeInput = "You are Claude, Inspector. Review Codex output: $codexResult. Task context: $hermesDispatch. Verify protocol, identify errors, rate [VERIFIED|PARTIAL|FAILED]. Output ASCII-safe."
$claudeInputPath = Join-Path $RunDir "CLAUDE_INPUT_TEMP.txt"
[System.IO.File]::WriteAllLines($claudeInputPath, $claudeInput, $Utf8NoBom)

$maxRetries = 1
$retryCount = 0
$claudeSuccess = $false
$claudeReviewStr = ""

while ($retryCount -le $maxRetries -and -not $claudeSuccess) {
    Write-Checkpoint "Invoking Claude CLI (Attempt $($retryCount + 1))..."
    $claudeConsole = Get-Content -LiteralPath $claudeInputPath | & claude -p 2>&1
    $claudeExit = $LASTEXITCODE
    $claudeReviewStr = $claudeConsole | Out-String

    if ($claudeExit -eq 0) {
        $claudeSuccess = $true
    } elseif ($claudeReviewStr -match "529") {
        Write-Host "Claude Overloaded (529). Waiting 10s..." -ForegroundColor Yellow
        $retryCount++
        if ($retryCount -le $maxRetries) { Start-Sleep -Seconds 10 }
    } else {
        break
    }
}

if (-not $claudeSuccess) {
    Write-Host "Claude Review Unavailable." -ForegroundColor Red
    $claudeReviewStr = "ERROR: Claude Review Unavailable (blocked_provider_overload)"
    $pipelineStatus = "partial_failure"
} else {
    $pipelineStatus = "success"
}
[System.IO.File]::WriteAllLines((Join-Path $RunDir "03_CLAUDE_REVIEW.md"), $claudeReviewStr, $Utf8NoBom)

Write-Checkpoint "Phase 4: Hermes Final Summary"

# Generate ASCII Summary (Canonical)
$summaryPromptAscii = "Summarize the Tripartite Test for Josh in English (ASCII-safe). Codex: $codexResult. Claude: $claudeReviewStr. Mention pipeline status: $pipelineStatus."
$finalSummaryAscii = & $HermesExe -z $summaryPromptAscii | Out-String
if ($null -eq $finalSummaryAscii -or $finalSummaryAscii.Trim() -eq "") { $finalSummaryAscii = "SUMMARY_FAILED" }
[System.IO.File]::WriteAllLines((Join-Path $RunDir "04_HERMES_FINAL_SUMMARY.ascii.md"), $finalSummaryAscii, $Utf8NoBom)

# Generate ZH-TW Summary (Optional)
$summaryPromptZh = "You are Hermes. Pipeline status: $pipelineStatus. Summarize this Tripartite Test for Josh in Traditional Chinese. Codex: $codexResult. Claude: $claudeReviewStr."
$finalSummaryZh = & $HermesExe -z $summaryPromptZh | Out-String
$zhTwSummaryFailed = "false"

if ($null -eq $finalSummaryZh -or $finalSummaryZh.Trim() -eq "" -or $finalSummaryZh -match "[?]\s*[\ue711]") {
    $zhTwSummaryFailed = "true"
    Write-Host "ZH-TW Summary failed or contains mojibake. Falling back to ASCII canonical." -ForegroundColor Yellow
}
[System.IO.File]::WriteAllLines((Join-Path $RunDir "04_HERMES_FINAL_SUMMARY.zh-TW.md"), $finalSummaryZh, $Utf8NoBom)

Write-Checkpoint "Finalizing Transcript"
$transcript = @"
# AgentOS Tripartite Coordination Transcript
Bridge ID: $BridgeId
Status: $pipelineStatus
ascii_summary_canonical=true
zh_tw_summary_failed=$zhTwSummaryFailed

## 1. Hermes Dispatch
$hermesDispatch

## 2. Codex Output
$codexResult

## 3. Claude Review
$claudeReviewStr

## 4. Hermes Summary (ASCII - Canonical)
$finalSummaryAscii

## 5. Hermes Summary (ZH-TW - Optional/Fallible)
$finalSummaryZh
"@
[System.IO.File]::WriteAllLines((Join-Path $RunDir "TRANSCRIPT.md"), $transcript, $Utf8NoBom)

Write-Host "Success. Transcript: $(Join-Path $RunDir 'TRANSCRIPT.md')" -ForegroundColor Green

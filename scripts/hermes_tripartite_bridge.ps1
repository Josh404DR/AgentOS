# AgentOS Hermes <-> Codex <-> Claude Tripartite Bridge
# Pipeline: Hermes (Dispatch) -> Codex (Execution) -> Claude (Review) -> Hermes (Summary)

param(
    [string]$BridgeId = (Get-Date -Format "yyyy-MM-dd-HHmmss"),
    [string]$AgentOSRoot = "E:\AgentOS",
    [string]$HermesRoot = "E:\AI_Projects_Hub\External_AI_Agents\hermes-agent",
    [string]$TaskSeed = "Check the consistency between agents/roles/hermes.md and agents/roles/codex.md. Ensure the 'Three-Agent Protocol' is documented correctly in both."
)

$ErrorActionPreference = "Stop"
$Utf8NoBom = New-Object System.Text.Utf8Encoding($false)

$HermesExe = Join-Path $HermesRoot ".venv\Scripts\hermes.exe"
$RunDir = Join-Path $AgentOSRoot "data\live_bridge\tripartite_$BridgeId"
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null

# Define Paths
$DispatchPromptPath = Join-Path $RunDir "01_DISPATCH_PROMPT.txt"
$DispatchPath = Join-Path $RunDir "01_HERMES_DISPATCH.md"
$CodexInputPath = Join-Path $RunDir "02_CODEX_INPUT.txt"
$CodexOutputPath = Join-Path $RunDir "02_CODEX_OUTPUT.md"
$ClaudeInputPath = Join-Path $RunDir "03_CLAUDE_INPUT.txt"
$ClaudeReviewPath = Join-Path $RunDir "03_CLAUDE_REVIEW.md"
$SummaryPromptPath = Join-Path $RunDir "04_SUMMARY_PROMPT.txt"
$FinalSummaryPath = Join-Path $RunDir "04_HERMES_FINAL_SUMMARY.md"
$TranscriptPath = Join-Path $RunDir "TRANSCRIPT.md"

function Write-Checkpoint($msg) {
    $time = Get-Date -Format "HH:mm:ss"
    Write-Host "[$time] $msg" -ForegroundColor Cyan
}

Write-Checkpoint "Phase 1: Hermes Dispatch"
$hermesDispatchPrompt = @"
You are Hermes, the AgentOS coordinator.
Create a technical task packet for Codex.
Task: $TaskSeed
Instruct Codex to output its findings in ASCII-only key=value lines.
"@
[System.IO.File]::WriteAllLines($DispatchPromptPath, $hermesDispatchPrompt, $Utf8NoBom)
$dispatchPrompt = Get-Content -Raw -Path $DispatchPromptPath
$hermesDispatch = & $HermesExe -z "$dispatchPrompt"
if ($null -eq $hermesDispatch) { throw "Hermes Dispatch failed" }
[System.IO.File]::WriteAllLines($DispatchPath, $hermesDispatch, $Utf8NoBom)

Write-Checkpoint "Phase 2: Codex Execution"
$codexInput = @"
You are Codex. Execute the following task from Hermes in AgentOS ($AgentOSRoot).
Task Packet:
$hermesDispatch

Output rules:
1. ASCII only.
2. key=value format for core findings.
3. Keep it technical and concise.
"@
[System.IO.File]::WriteAllLines($CodexInputPath, $codexInput, $Utf8NoBom)

$oldOpenAiApiKey = [Environment]::GetEnvironmentVariable("OPENAI_API_KEY", "Process")
$oldCodexApiKey = [Environment]::GetEnvironmentVariable("CODEX_API_KEY", "Process")
try {
    Remove-Item Env:\OPENAI_API_KEY -ErrorAction SilentlyContinue
    Remove-Item Env:\CODEX_API_KEY -ErrorAction SilentlyContinue
    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $codexConsole = Get-Content -LiteralPath $CodexInputPath | & codex -a never exec -C $AgentOSRoot --sandbox read-only --output-last-message $CodexOutputPath 2>&1
    $codexExit = $LASTEXITCODE
    $ErrorActionPreference = $oldEAP
} finally {
    if ($null -ne $oldOpenAiApiKey) { [Environment]::SetEnvironmentVariable("OPENAI_API_KEY", $oldOpenAiApiKey, "Process") }
    if ($null -ne $oldCodexApiKey) { [Environment]::SetEnvironmentVariable("CODEX_API_KEY", $oldCodexApiKey, "Process") }
}

if ($codexExit -ne 0) {
    $codexConsole | Out-String | Set-Content -Path (Join-Path $RunDir "CODEX_ERROR.log")
    throw "Codex failed with exit code $codexExit. Check CODEX_ERROR.log" 
}
$codexResult = Get-Content -Raw -LiteralPath $CodexOutputPath

Write-Checkpoint "Phase 3: Claude Review"
$claudeInput = @"
You are Claude, the AgentOS Senior Reviewer.
Review the following technical output from Codex.
Task Context: $hermesDispatch
Codex Output:
$codexResult

Goal:
1. Verify if Codex followed the 'Three-Agent Protocol'.
2. Identify any inconsistencies or technical errors.
3. Provide a safety/readiness rating: [VERIFIED | PARTIAL | FAILED].
4. Output in ASCII-safe format.
"@
[System.IO.File]::WriteAllLines($ClaudeInputPath, $claudeInput, $Utf8NoBom)

Write-Checkpoint "Invoking Claude CLI..."
$claudeConsole = Get-Content -LiteralPath $ClaudeInputPath | & claude -p
$claudeExit = $LASTEXITCODE
if ($claudeExit -ne 0) {
    $claudeConsole | Out-String | Set-Content -Path (Join-Path $RunDir "CLAUDE_ERROR.log")
    throw "Claude failed with exit code $claudeExit. Check CLAUDE_ERROR.log"
}
$claudeReview = $claudeConsole | Out-String
[System.IO.File]::WriteAllLines($ClaudeReviewPath, $claudeReview, $Utf8NoBom)

Write-Checkpoint "Phase 4: Hermes Final Summary"
$summaryPromptText = @"
You are Hermes. You have received the results of the Tripartite Coordination Test.
Codex performed the task, and Claude reviewed it.

Summary Goal:
1. Report to Josh in Traditional Chinese.
2. Confirm if the 'Three-Agent Protocol' (Hermes-Codex-Claude) worked end-to-end.
3. State whether the documentation consistency is verified or needs fix.

Codex Result:
$codexResult

Claude Review:
$claudeReview
"@
[System.IO.File]::WriteAllLines($SummaryPromptPath, $summaryPromptText, $Utf8NoBom)
$summaryPrompt = Get-Content -Raw -Path $SummaryPromptPath
$finalSummary = & $HermesExe -z "$summaryPrompt"
if ($null -eq $finalSummary) { throw "Hermes Final Summary failed" }
[System.IO.File]::WriteAllLines($FinalSummaryPath, $finalSummary, $Utf8NoBom)

Write-Checkpoint "Finalizing Transcript"
$transcript = @"
# AgentOS Tripartite Coordination Transcript
Bridge ID: $BridgeId
Status: success

## 1. Hermes Dispatch
$hermesDispatch

## 2. Codex Output
$codexResult

## 3. Claude Review
$claudeReview

## 4. Hermes Final Summary
$finalSummary
"@
[System.IO.File]::WriteAllLines($TranscriptPath, $transcript, $Utf8NoBom)

Write-Host "Tripartite bridge test completed successfully." -ForegroundColor Green
Write-Host "Transcript: $TranscriptPath"

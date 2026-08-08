# AgentOS typed dispatch runner
# Deterministic router for Josh [TYPE: ...] requests.
# This script assembles routing decisions and prompt packets without calling
# Gemini, Codex, Claude, or external services.

param(
    [string]$InputText,
    [string]$InputFile,
    [string]$AgentOSRoot = "E:\AgentOS",
    [string]$DispatchId = (Get-Date -Format "yyyy-MM-dd-HHmmss"),
    [switch]$NoWrite
)

$ErrorActionPreference = "Stop"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$governanceGate = Join-Path $AgentOSRoot "scripts\assert_governance_ready.ps1"
$governanceOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $governanceGate -AgentOSRoot $AgentOSRoot
if ($LASTEXITCODE -ne 0) { throw "Governance gate blocked typed dispatch.`n$($governanceOutput -join "`n")" }
$governanceText = $governanceOutput -join "`n"
$governanceVersion = ([regex]::Match($governanceText, '(?m)^governance_version=(.+)$')).Groups[1].Value.Trim()
$governanceHash = ([regex]::Match($governanceText, '(?m)^governance_hash=(.+)$')).Groups[1].Value.Trim()

function Read-TextInput {
    if ($InputFile) {
        if (-not (Test-Path -LiteralPath $InputFile)) {
            throw "Input file not found: $InputFile"
        }
        return [IO.File]::ReadAllText($InputFile, [Text.Encoding]::UTF8)
    }
    if ($InputText) { return $InputText }
    throw "Provide -InputText or -InputFile."
}

function Parse-TypedFields([string]$Text) {
    $fields = [ordered]@{}
    $matches = [regex]::Matches($Text, '(?m)^\[(TYPE|GOAL|TARGET|SCOPE|FILES|CONSTRAINTS|OUTPUT|APPROVAL):\s*(.*?)\]\s*$')
    foreach ($m in $matches) {
        $key = $m.Groups[1].Value.ToUpperInvariant()
        $value = $m.Groups[2].Value.Trim()
        $fields[$key] = $value
    }
    return $fields
}

function Get-RouteSpec([string]$Type) {
    $map = @{
        "CODEX_BUILD"   = @{ route_to = "Codex"; template = "prompts\task_templates\codex_build.md"; role_header = "prompts\role_headers\codex_builder.md"; context_pack = "repo_task"; gemini_allowed = $false; approval_required = $false }
        "CODEX_PLAN"    = @{ route_to = "Codex"; template = "prompts\task_templates\codex_plan.md"; role_header = "prompts\role_headers\codex_verifier.md"; context_pack = "minimal"; gemini_allowed = $false; approval_required = $false }
        "CODEX_VERIFY"  = @{ route_to = "Codex"; template = "prompts\task_templates\codex_verify.md"; role_header = "prompts\role_headers\codex_verifier.md"; context_pack = "evidence_verification"; gemini_allowed = $false; approval_required = $false }
        "CLAUDE_REVIEW" = @{ route_to = "Claude"; template = "prompts\task_templates\claude_review.md"; role_header = "prompts\role_headers\claude_inspector.md"; context_pack = "evidence_verification"; gemini_allowed = $false; approval_required = $false }
        "CLAUDE_WORKER" = @{ route_to = "Claude"; template = "prompts\task_templates\claude_worker.md"; role_header = "prompts\role_headers\claude_worker.md"; context_pack = "minimal"; gemini_allowed = $false; approval_required = $false }
        "URL_INTAKE" = @{ route_to = "Codex"; template = "prompts\task_templates\codex_verify.md"; role_header = "prompts\role_headers\codex_verifier.md"; context_pack = "minimal"; gemini_allowed = $false; approval_required = $false }
        "OLLAMA_TRIAGE" = @{ route_to = "Ollama"; template = "prompts\task_templates\ollama_triage.md"; role_header = ""; context_pack = "minimal"; gemini_allowed = $false; approval_required = $false }
        "JOSH_APPROVAL" = @{ route_to = "Hermes"; template = ""; role_header = ""; context_pack = "approval_target_only"; gemini_allowed = $false; approval_required = $false }
        "GEMINI_PREMIUM" = @{ route_to = "Gemini"; template = ""; role_header = ""; context_pack = "minimal_targeted"; gemini_allowed = $true; approval_required = $true }
        "STOP" = @{ route_to = "Hermes"; template = ""; role_header = ""; context_pack = "none"; gemini_allowed = $false; approval_required = $false }
    }
    if ($map.ContainsKey($Type)) { return $map[$Type] }
    return @{ route_to = "Hermes"; template = ""; role_header = ""; context_pack = "none"; gemini_allowed = $false; approval_required = $false; unknown_type = $true }
}

function Read-OptionalRepoFile([string]$RelativePath) {
    if (-not $RelativePath) { return "" }
    $path = Join-Path $AgentOSRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required prompt pack file missing: $RelativePath"
    }
    return Get-Content -Raw -LiteralPath $path
}

function To-JsonLine([hashtable]$Data) {
    return ($Data | ConvertTo-Json -Compress -Depth 8)
}

$rawText = Read-TextInput
$fields = Parse-TypedFields $rawText
$type = "UNKNOWN"
if ($fields.Contains("TYPE")) {
    $type = $fields["TYPE"].ToUpperInvariant()
}

$route = Get-RouteSpec $type
$isUnknown = $false
if ($route.ContainsKey("unknown_type")) { $isUnknown = [bool]$route.unknown_type }

$roleHeader = Read-OptionalRepoFile $route.role_header
$template = Read-OptionalRepoFile $route.template
$contextPackPath = ""
if ($route.context_pack -eq "minimal") { $contextPackPath = "prompts\context_packs\minimal.md" }
elseif ($route.context_pack -eq "repo_task") { $contextPackPath = "prompts\context_packs\repo_task.md" }
elseif ($route.context_pack -eq "evidence_verification") { $contextPackPath = "prompts\context_packs\evidence_verification.md" }
elseif ($route.context_pack -eq "cleanup_approval") { $contextPackPath = "prompts\context_packs\cleanup_approval.md" }
$contextPack = Read-OptionalRepoFile $contextPackPath

$goal = if ($fields.Contains("GOAL")) { $fields["GOAL"] } else { "" }
$target = if ($fields.Contains("TARGET")) { $fields["TARGET"] } else { "" }
$scope = if ($fields.Contains("SCOPE")) { $fields["SCOPE"] } else { "" }
$files = if ($fields.Contains("FILES")) { $fields["FILES"] } else { "" }
$constraints = if ($fields.Contains("CONSTRAINTS")) { $fields["CONSTRAINTS"] } else { "" }
$output = if ($fields.Contains("OUTPUT")) { $fields["OUTPUT"] } else { "" }
$approval = if ($fields.Contains("APPROVAL")) { $fields["APPROVAL"] } else { "" }

$requiresJoshApproval = [bool]$route.approval_required
$constraintLower = $constraints.ToLowerInvariant()
$highRiskConstraint = $false
if ($constraintLower -match '\b(delete|archive|install|credential|token|oauth|client|send|live)\b') {
    $highRiskConstraint = $true
}
if ($constraintLower -match '\bcleanup\b' -and $constraintLower -notmatch '\b(no|without|禁止|不得)\s+cleanup\b') {
    $highRiskConstraint = $true
}
if ($constraintLower -match '\bexternal\b' -and $constraintLower -notmatch '\b(no|without|禁止|不得)\s+external\b') {
    $highRiskConstraint = $true
}
if ($highRiskConstraint) {
    $requiresJoshApproval = $true
}
if ($type -eq "JOSH_APPROVAL") { $requiresJoshApproval = $false }
if ($type -eq "STOP") { $requiresJoshApproval = $false }

$dispatchStatus = "ready_to_route"
if ($isUnknown) { $dispatchStatus = "unknown_type_context_only" }
elseif ($requiresJoshApproval -and -not $approval) { $dispatchStatus = "approval_required" }
elseif ($type -eq "STOP") { $dispatchStatus = "stop_requested" }

$assembledPrompt = @"
# AgentOS Typed Dispatch Prompt

dispatch_id: $DispatchId
type: $type
route_to: $($route.route_to)
dispatch_status: $dispatchStatus
governance_version: $governanceVersion
governance_hash: $governanceHash
gemini_allowed: $($route.gemini_allowed)
requires_josh_approval: $requiresJoshApproval

## Role Header

$roleHeader

## Task Template

$template

## Context Pack

$contextPack

## Josh Request Fields

goal: $goal
target: $target
scope: $scope
files: $files
constraints: $constraints
output: $output
approval: $approval

## Raw Request

$rawText
"@

$routingDecision = @"
# AgentOS Typed Dispatch Decision

dispatch_id: $DispatchId
created_at: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz")

type: $type
route_to: $($route.route_to)
template: $($route.template)
role_header: $($route.role_header)
context_pack: $($route.context_pack)
gemini_allowed: $($route.gemini_allowed)
requires_josh_approval: $requiresJoshApproval
dispatch_status: $dispatchStatus
governance_version: $governanceVersion
governance_hash: $governanceHash
cleanup_executed: false
live_external_action_executed: false
models_invoked: false

## Parsed Fields

goal: $goal
target: $target
scope: $scope
files: $files
constraints: $constraints
output: $output
approval: $approval

## Notes

- This runner performs deterministic routing only.
- It does not call Gemini, Codex, Claude, Ollama, or external services.
- Unknown types are context-only until Josh clarifies.
- Gemini premium routing requires explicit type and approval handling.
"@

if (-not $NoWrite) {
    $outDir = Join-Path $AgentOSRoot "data\routing_decisions\$DispatchId"
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    [System.IO.File]::WriteAllLines((Join-Path $outDir "ROUTING_DECISION.md"), $routingDecision, $Utf8NoBom)
    [System.IO.File]::WriteAllLines((Join-Path $outDir "ASSEMBLED_PROMPT.md"), $assembledPrompt, $Utf8NoBom)

    $cachePath = Join-Path $AgentOSRoot "data\routing\routing_cache.jsonl"
    $cacheLine = To-JsonLine @{
        timestamp = (Get-Date -Format "o")
        dispatch_id = $DispatchId
        type = $type
        route_to = $route.route_to
        template = $route.template
        context_pack = $route.context_pack
        reason = $goal
        gemini_used = $false
        dispatch_status = $dispatchStatus
    }
    Add-Content -LiteralPath $cachePath -Value $cacheLine -Encoding UTF8
}

Write-Output "dispatch_id=$DispatchId"
Write-Output "type=$type"
Write-Output "route_to=$($route.route_to)"
Write-Output "dispatch_status=$dispatchStatus"
Write-Output "governance_version=$governanceVersion"
Write-Output "governance_hash=$governanceHash"
Write-Output "gemini_allowed=$($route.gemini_allowed)"
Write-Output "requires_josh_approval=$requiresJoshApproval"
Write-Output "models_invoked=false"

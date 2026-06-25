# AgentOS URL intake task packet creator
# Converts a deterministic URL_INTAKE routing artifact into a Codex TASK.md.
# This script does not fetch URLs, invoke models, run Codex, or call external services.

param(
    [Parameter(Mandatory = $true)]
    [string]$DispatchId,

    [string]$AgentOSRoot = "E:\AgentOS",

    [string]$RoutingDecisionPath,

    [string]$RawMessage = "",

    [string]$Urls = ""
)

$ErrorActionPreference = "Stop"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Get-SafeSlug([string]$Text, [int]$MaxLength = 80) {
    $slug = [regex]::Replace($Text, '[^A-Za-z0-9_.-]+', '-').Trim('-')
    if (-not $slug) { $slug = "url-intake" }
    if ($slug.Length -gt $MaxLength) {
        return $slug.Substring($slug.Length - $MaxLength)
    }
    return $slug
}

function Get-RoutingField([string]$Content, [string]$FieldName) {
    $pattern = "(?m)^" + [regex]::Escape($FieldName) + ":\s*(.*)$"
    $match = [regex]::Match($Content, $pattern)
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return ""
}

if (-not $RoutingDecisionPath) {
    $RoutingDecisionPath = Join-Path $AgentOSRoot ("data\routing_decisions\{0}\ROUTING_DECISION.md" -f $DispatchId)
}

if (-not (Test-Path -LiteralPath $RoutingDecisionPath)) {
    throw "Routing decision not found: $RoutingDecisionPath"
}

$routingContent = Get-Content -Raw -LiteralPath $RoutingDecisionPath
$type = Get-RoutingField $routingContent "type"
$routeTo = Get-RoutingField $routingContent "route_to"
$target = Get-RoutingField $routingContent "target"
$dispatchStatus = Get-RoutingField $routingContent "dispatch_status"

if ($type -ne "URL_INTAKE") {
    throw "Routing decision is not URL_INTAKE: $type"
}

if ($routeTo -ne "Codex") {
    throw "URL_INTAKE route is not Codex: $routeTo"
}

if ($dispatchStatus -ne "ready_to_route") {
    throw "URL_INTAKE is not ready_to_route: $dispatchStatus"
}

if (-not $Urls) { $Urls = $target }

$date = Get-Date -Format "yyyy-MM-dd"
$slug = Get-SafeSlug $DispatchId
$taskDir = Join-Path $AgentOSRoot ("data\codex_tasks\{0}-url-intake-{1}" -f $date, $slug)
$outputsDir = Join-Path $taskDir "OUTPUTS"
New-Item -ItemType Directory -Force -Path $outputsDir | Out-Null

$taskPath = Join-Path $taskDir "TASK.md"
$resultPath = Join-Path $outputsDir "RESULT.md"
$createdAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"

$task = @"
# URL Intake Follow-Up Task

dispatch_id: $DispatchId
created_at: $createdAt
route_to: Codex
task_status: task_packet_created
source_status: source_not_verified
models_invoked: false
external_services_invoked: false
live_external_action_executed: false

## Goal

Prepare a safe follow-up analysis plan for the URL(s) captured by Hermes Lite.

## URL(s)

$Urls

## Raw Telegram Message

$RawMessage

## Required Codex Behavior

- Read the routing artifact before doing any work:
  $RoutingDecisionPath
- Do not claim the URL content has been read unless an explicit later task authorizes external access and the access succeeds.
- Do not fetch, scrape, browse, summarize, contact, submit, or authenticate against the target URL in this task.
- Classify the URL by apparent domain and task type using only the URL string and Josh's raw message.
- Produce a recommended next task packet:
  - whether external access is needed
  - what approval is required from Josh
  - whether Claude review is needed
  - whether the task is safe, risky, or blocked
- Keep the output evidence-based.

## Acceptance Criteria

- OUTPUTS\RESULT.md exists.
- Result includes source_not_verified=true.
- Result includes external_access_required=true|false.
- Result includes recommended_next_action.
- Result does not claim the URL was read.
- Result does not include fetched webpage content.

## Evidence Contract

task_status: task_packet_created
claimed_by: Hermes Lite URL intake
artifact_status: artifact_created
locally_verified: true
verified_by_codex: false
reviewed_by_claude: not_applicable
approved_by_josh: auto_url_intake_artifact_only
cleanup_executed: false
live_external_action_executed: false
models_invoked: false
production_ready: false
"@

$result = @"
# URL Intake Packet Result

dispatch_id: $DispatchId
created_at: $createdAt
task_status: task_packet_created
source_not_verified: true
models_invoked: false
external_services_invoked: false
live_external_action_executed: false

## Created Artifacts

- TASK: $taskPath
- ROUTING_DECISION: $RoutingDecisionPath

## Next Action

Codex can now execute this TASK.md locally to classify the URL intake and prepare the next approval-gated step. External URL access still requires explicit Josh approval.
"@

[System.IO.File]::WriteAllLines($taskPath, $task, $Utf8NoBom)
[System.IO.File]::WriteAllLines($resultPath, $result, $Utf8NoBom)

Write-Output "task_packet_status=created"
Write-Output "dispatch_id=$DispatchId"
Write-Output "task_path=$taskPath"
Write-Output "result_path=$resultPath"
Write-Output "models_invoked=false"
Write-Output "external_services_invoked=false"
Write-Output "live_external_action_executed=false"

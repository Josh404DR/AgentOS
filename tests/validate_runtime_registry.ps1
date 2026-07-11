[CmdletBinding()]
param([string]$AgentOSRoot)
$ErrorActionPreference = "Stop"
if (-not $AgentOSRoot) { $AgentOSRoot = Split-Path -Parent $PSScriptRoot }
$root = (Resolve-Path $AgentOSRoot).Path
$registry = [IO.File]::ReadAllText((Join-Path $root "config\runtime_registry.json"), [Text.Encoding]::UTF8) | ConvertFrom-Json
$items = @($registry.runtimes)
$duplicates = @($items | Group-Object runtime_id | Where-Object Count -ne 1)
if ($duplicates) { throw "Duplicate runtime IDs: $($duplicates.Name -join ',')" }
$requiredRuntimeIds = @(
    "hermes-main-gateway", "hermes-lite-gateway", "hermes-proxy",
    "dashboard-backend", "dashboard-frontend", "task-queue-runner",
    "workflow-supervisor", "governance-gate", "escalation-approval",
    "typed-dispatch-router", "url-intake-workers", "hermes-internal-cron",
    "promote-draft", "codex-cli-worker", "claude-cli-worker",
    "antigravity-poll-workers", "notebooklm-conveyor", "watchdog"
)
$missingRuntimeIds = @($requiredRuntimeIds | Where-Object { $_ -notin $items.runtime_id })
if ($missingRuntimeIds.Count) { throw "Canonical runtime inventory is incomplete: $($missingRuntimeIds -join ',')" }
foreach ($item in $items) {
    if ($item.start_source.script) {
        $path = Join-Path $root ([string]$item.start_source.script -replace '/', '\')
        if (-not (Test-Path $path -PathType Leaf)) { throw "Missing runtime script: $($item.start_source.script)" }
    }
    if ($item.control.enabled) {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "scripts\runtimes\control-runtime.ps1") -RuntimeId $item.runtime_id -Action start -AgentOSRoot $root -ValidateOnly | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Invalid runtime control: $($item.runtime_id)" }
    }
    $statePaths = @($item.state_paths | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    $hasEvidence = [bool]($item.process_match -or @($item.ports).Count -or $item.http_health -or @($item.log_paths).Count -or $statePaths.Count -or $item.start_source.type -eq "scheduled_task")
    if ($item.enabled -and -not $hasEvidence) { throw "Enabled runtime has no deterministic evidence source: $($item.runtime_id)" }
}
"runtime_registry_status=PASS"; "runtime_count=$($items.Count)"; "controlled_count=$(@($items | Where-Object { $_.control.enabled }).Count)"

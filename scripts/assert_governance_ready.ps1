[CmdletBinding()]
param(
    [string]$AgentOSRoot = "E:\AgentOS",
    [string]$TaskPath = "",
    [string]$ExpectedVersion = "",
    [string]$ExpectedHash = "",
    [switch]$ReadOnly
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $AgentOSRoot).Path
$syncScript = Join-Path $root "scripts\sync_shared_governance.ps1"
$statusPath = Join-Path $root "data\governance\governance_status.json"

if ($ReadOnly) {
    if (-not (Test-Path -LiteralPath $syncScript -PathType Leaf)) {
        Write-Output "governance_gate=blocked"
        Write-Output "reason=governance_sync_missing_for_readonly"
        Write-Output "task_execution_allowed=false"
        exit 20
    }
    if (-not (Test-Path -LiteralPath $statusPath -PathType Leaf)) {
        Write-Output "governance_gate=blocked"
        Write-Output "reason=governance_status_missing_for_readonly"
        Write-Output "task_execution_allowed=false"
        exit 21
    }
} else {
    if (-not (Test-Path -LiteralPath $syncScript -PathType Leaf)) {
        Write-Error "governance gate missing sync script: $syncScript"
        exit 20
    }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $syncScript -AgentOSRoot $root | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $statusPath -PathType Leaf)) {
        Write-Error "governance scan failed"
        exit 21
    }
}

if ($ReadOnly) {
    $scanOutput = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $syncScript -AgentOSRoot $root -ReadOnly)
    if ($LASTEXITCODE -ne 0) {
        Write-Output "governance_gate=blocked"
        Write-Output "reason=governance_readonly_scan_failed"
        Write-Output "task_execution_allowed=false"
        exit 21
    }
    function Get-ScanField([string]$Name) {
        $line = $scanOutput | Where-Object { $_ -match ('^' + [regex]::Escape($Name) + '=') } | Select-Object -Last 1
        if ($line) { return ($line -replace ('^' + [regex]::Escape($Name) + '='), '') }
        return ""
    }
    $persisted = Get-Content -Raw -LiteralPath $statusPath -Encoding UTF8 | ConvertFrom-Json
    $status = [pscustomobject]@{
        governance_status = Get-ScanField "governance_status"
        governance_version = Get-ScanField "governance_version"
        canonical_hash = Get-ScanField "canonical_hash"
        checked_at = "read_only_live_scan"
        drift_count = [int](Get-ScanField "drift_count")
        operational_drift_count = [int](Get-ScanField "operational_drift_count")
    }
    if ($persisted.canonical_hash -ne $status.canonical_hash) {
        Write-Output "governance_gate=blocked"
        Write-Output "reason=governance_hash_recomputed_mismatch"
        Write-Output "computed_hash=$($status.canonical_hash)"
        Write-Output "stored_hash=$($persisted.canonical_hash)"
        Write-Output "task_execution_allowed=false"
        exit 26
    }
} else {
    $status = Get-Content -Raw -LiteralPath $statusPath -Encoding UTF8 | ConvertFrom-Json
}

if ($status.governance_status -notin @("aligned", "operational_review_required")) {
    Write-Output "governance_gate=blocked"
    Write-Output "governance_status=$($status.governance_status)"
    Write-Output "governance_version=$($status.governance_version)"
    Write-Output "governance_hash=$($status.canonical_hash)"
    Write-Output "drift_count=$($status.drift_count)"
    Write-Output "task_execution_allowed=false"
    exit 22
}

if ($TaskPath) {
    if (-not (Test-Path -LiteralPath $TaskPath -PathType Leaf)) {
        Write-Error "task file not found for governance check: $TaskPath"
        exit 23
    }
    $task = Get-Content -Raw -LiteralPath $TaskPath -Encoding UTF8
    $taskVersionMatch = [regex]::Match($task, '(?m)^governance_version:\s*(\S+)\s*$')
    $taskHashMatch = [regex]::Match($task, '(?m)^governance_hash:\s*(\S+)\s*$')
    if (-not $taskVersionMatch.Success -or -not $taskHashMatch.Success) {
        Write-Output "governance_gate=blocked"
        Write-Output "reason=task_governance_binding_missing"
        Write-Output "task_execution_allowed=false"
        exit 24
    }
    $ExpectedVersion = $taskVersionMatch.Groups[1].Value
    $ExpectedHash = $taskHashMatch.Groups[1].Value
}

if ($ExpectedVersion -and $ExpectedVersion -ne $status.governance_version) {
    Write-Output "governance_gate=blocked"
    Write-Output "reason=governance_version_mismatch"
    Write-Output "expected_version=$ExpectedVersion"
    Write-Output "actual_version=$($status.governance_version)"
    Write-Output "task_execution_allowed=false"
    exit 25
}
if ($ExpectedHash -and $ExpectedHash -ne $status.canonical_hash) {
    Write-Output "governance_gate=blocked"
    Write-Output "reason=governance_hash_mismatch"
    Write-Output "expected_hash=$ExpectedHash"
    Write-Output "actual_hash=$($status.canonical_hash)"
    Write-Output "task_execution_allowed=false"
    exit 26
}

Write-Output "governance_gate=passed"
Write-Output "governance_status=$($status.governance_status)"
Write-Output "governance_version=$($status.governance_version)"
Write-Output "governance_hash=$($status.canonical_hash)"
Write-Output "governance_checked_at=$($status.checked_at)"
Write-Output "task_execution_allowed=true"
Write-Output "token_cost=0"
Write-Output "model_calls=0"
if ($status.operational_drift_count -ne $null) {
    Write-Output "operational_drift_count=$($status.operational_drift_count)"
}

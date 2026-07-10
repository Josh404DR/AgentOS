[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')][string]$TaskName,
    [string]$BaseBranch = "master",
    [string]$Remote = "origin"
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$gitSafeRoot = $root.Replace('\', '/')
Push-Location $root
try {
    if (-not (Test-Path ".git")) { throw "Not an AgentOS Git worktree: $root" }
    $status = @(git -c "safe.directory=$gitSafeRoot" status --porcelain)
    if ($LASTEXITCODE -ne 0) { throw "Cannot inspect Git worktree." }
    if ($status.Count) { throw "Worktree is not clean. Commit or resolve changes before starting work." }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\assert_governance_ready.ps1 -AgentOSRoot $root
    if ($LASTEXITCODE -ne 0) { throw "Governance gate failed." }

    git -c "safe.directory=$gitSafeRoot" fetch --prune $Remote
    if ($LASTEXITCODE -ne 0) { throw "git fetch failed." }
    git -c "safe.directory=$gitSafeRoot" switch $BaseBranch
    if ($LASTEXITCODE -ne 0) { throw "Cannot switch to $BaseBranch." }
    git -c "safe.directory=$gitSafeRoot" pull --ff-only $Remote $BaseBranch
    if ($LASTEXITCODE -ne 0) { throw "Fast-forward-only pull failed." }

    $branch = "codex/$TaskName"
    git -c "safe.directory=$gitSafeRoot" switch -c $branch
    if ($LASTEXITCODE -ne 0) { throw "Cannot create task branch $branch." }
    Write-Output "work_start_status=PASS"
    Write-Output "branch=$branch"
} finally {
    Pop-Location
}

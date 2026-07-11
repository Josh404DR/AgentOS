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
    $topLevel = ((git -c "safe.directory=$gitSafeRoot" rev-parse --show-toplevel) -join "").Trim()
    if ($LASTEXITCODE -ne 0 -or [IO.Path]::GetFullPath($topLevel) -ne [IO.Path]::GetFullPath($root)) { throw "Git top-level does not match AgentOS root: $topLevel" }
    $gitName = ((git -c "safe.directory=$gitSafeRoot" config user.name) -join "").Trim()
    $gitEmail = ((git -c "safe.directory=$gitSafeRoot" config user.email) -join "").Trim()
    if (-not $gitName -or -not $gitEmail) { throw "Git user.name and user.email must be configured before starting work." }
    $remoteUrl = ((git -c "safe.directory=$gitSafeRoot" remote get-url $Remote) -join "").Trim()
    if ($LASTEXITCODE -ne 0 -or -not $remoteUrl) { throw "Git remote is missing: $Remote" }
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
    Write-Output "git_identity=$gitName <$gitEmail>"
    Write-Output "windows_identity=$([Security.Principal.WindowsIdentity]::GetCurrent().Name)"
    Write-Output "remote_url=$remoteUrl"
} finally {
    Pop-Location
}

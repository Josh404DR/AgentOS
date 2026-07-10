[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string[]]$Files,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Message,
    [switch]$Push,
    [string]$Remote = "origin"
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$gitSafeRoot = $root.Replace('\', '/')
Push-Location $root
try {
    $branchOutput = @(git -c "safe.directory=$gitSafeRoot" branch --show-current)
    if ($LASTEXITCODE -ne 0) { throw "Cannot inspect current Git branch." }
    $branch = ($branchOutput -join "").Trim()
    if (-not $branch) { throw "Detached HEAD is not supported." }
    if ($branch -in @("master", "main")) { throw "Direct commits to protected branch $branch are forbidden." }
    $status = @(git -c "safe.directory=$gitSafeRoot" status --porcelain)
    if ($LASTEXITCODE -ne 0) { throw "Cannot inspect Git worktree." }
    if (-not $status.Count) { throw "No changes to finish." }

    foreach ($file in $Files) {
        if ([string]::IsNullOrWhiteSpace($file) -or $file -eq ".") { throw "Each staged path must be explicit; '.' is forbidden." }
        $candidate = [IO.Path]::GetFullPath((Join-Path $root $file))
        if (-not $candidate.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Path escapes repository: $file"
        }
        git -c "safe.directory=$gitSafeRoot" add -- $file
        if ($LASTEXITCODE -ne 0) { throw "Failed to stage $file." }
    }

    $staged = @(git -c "safe.directory=$gitSafeRoot" diff --cached --name-only)
    if ($LASTEXITCODE -ne 0 -or -not $staged.Count) { throw "Explicit paths produced no staged changes." }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\entrypoints\agentos-check.ps1
    if ($LASTEXITCODE -ne 0) { throw "Pre-commit checks failed." }
    git -c "safe.directory=$gitSafeRoot" diff --cached --check
    if ($LASTEXITCODE -ne 0) { throw "Staged diff check failed." }
    git -c "safe.directory=$gitSafeRoot" commit -m $Message
    if ($LASTEXITCODE -ne 0) { throw "Commit failed." }

    if ($Push) {
        git -c "safe.directory=$gitSafeRoot" push -u $Remote $branch
        if ($LASTEXITCODE -ne 0) { throw "Push failed." }
    }
    Write-Output "work_finish_status=PASS"
    Write-Output "branch=$branch"
    Write-Output "pushed=$($Push.IsPresent.ToString().ToLowerInvariant())"
} finally {
    Pop-Location
}

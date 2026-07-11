[CmdletBinding()]
param([string]$AgentOSRoot)
$ErrorActionPreference = "Stop"
if (-not $AgentOSRoot) { $AgentOSRoot = Split-Path -Parent $PSScriptRoot }
$root = (Resolve-Path $AgentOSRoot).Path
$fixture = Join-Path ([IO.Path]::GetTempPath()) ("agentos-git-guard-" + [Guid]::NewGuid().ToString("N"))
try {
    New-Item -ItemType Directory -Force -Path (Join-Path $fixture "scripts\entrypoints") | Out-Null
    Copy-Item (Join-Path $root "scripts\entrypoints\agentos-work-start.ps1") (Join-Path $fixture "scripts\entrypoints\agentos-work-start.ps1")
    Copy-Item (Join-Path $root "scripts\entrypoints\agentos-work-finish.ps1") (Join-Path $fixture "scripts\entrypoints\agentos-work-finish.ps1")
    Push-Location $fixture
    try {
        git init -b master | Out-Null
        git config user.name "AgentOS CI"
        git config user.email "agentos-ci@example.invalid"
        git remote add origin $fixture
        [IO.File]::WriteAllText((Join-Path $fixture "fixture.txt"), "base`n", [Text.UTF8Encoding]::new($false))
        git add -- fixture.txt
        git commit -m "fixture base" | Out-Null

        [IO.File]::AppendAllText((Join-Path $fixture "fixture.txt"), "dirty`n", [Text.UTF8Encoding]::new($false))
        $previousPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $startOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\entrypoints\agentos-work-start.ps1 -TaskName fixture 2>&1
        $startExit = $LASTEXITCODE
        $ErrorActionPreference = $previousPreference
        if ($startExit -eq 0 -or ($startOutput -join " ") -notmatch "not clean") { throw "Dirty worktree was not rejected clearly." }

        $ErrorActionPreference = "Continue"
        $finishOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\entrypoints\agentos-work-finish.ps1 -Files fixture.txt -Message "fixture" 2>&1
        $finishExit = $LASTEXITCODE
        $ErrorActionPreference = $previousPreference
        if ($finishExit -eq 0 -or ($finishOutput -join " ") -notmatch "protected branch") { throw "Direct master commit was not rejected clearly." }

        git switch -c codex/fixture | Out-Null
        $ErrorActionPreference = "Continue"
        $dotOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\entrypoints\agentos-work-finish.ps1 -Files . -Message "fixture" 2>&1
        $dotExit = $LASTEXITCODE
        $ErrorActionPreference = $previousPreference
        if ($dotExit -eq 0 -or ($dotOutput -join " ") -notmatch "explicit") { throw "Dot staging was not rejected clearly." }
    } finally {
        Pop-Location
    }

    $startText = [IO.File]::ReadAllText((Join-Path $root "scripts\entrypoints\agentos-work-start.ps1"), [Text.Encoding]::UTF8)
    $finishText = [IO.File]::ReadAllText((Join-Path $root "scripts\entrypoints\agentos-work-finish.ps1"), [Text.Encoding]::UTF8)
    if ($startText -notmatch 'pull --ff-only') { throw "Work start does not enforce fast-forward-only pull." }
    if ($startText -notmatch 'rev-parse --show-toplevel' -or $startText -notmatch 'config user.name' -or $startText -notmatch 'config user.email') { throw "Work start does not verify repository and Git identity." }
    if (($startText + $finishText) -match '(?im)git\s+(reset|stash)|force-with-lease|force\s') { throw "Forbidden automatic Git recovery operation found." }
    if ($finishText -match '(?im)git\s+add\s+\.') { throw "Forbidden dot staging found." }
    if ($finishText -notmatch 'scoped diff' -or $finishText -notmatch 'codex/\*') { throw "Work finish does not expose scoped diff and enforce task branch prefix." }
    "workflow_guard_contract=PASS"
    "dirty_worktree_rejected=true"
    "master_commit_rejected=true"
    "dot_staging_rejected=true"
    "fast_forward_only=true"
    "identity_and_repository_verified=true"
    "scoped_diff_required=true"
} finally {
    if (Test-Path $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}
exit 0

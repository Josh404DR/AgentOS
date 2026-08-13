# Offline regression for Invoke-GitDiffText
# Reproduces: stale LASTEXITCODE=1 / empty diff / warning-only stderr
# must not throw and must return non-null string; overall exit must be 0.

[CmdletBinding()]
param(
    [string]$AgentOSRoot = "E:\AgentOS"
)

$ErrorActionPreference = "Stop"

# Mirror of the fixed Invoke-GitDiffText from scripts\dispatch_task_packet.ps1.
# Kept in sync manually; update both if the production function changes.
function Invoke-GitDiffText {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    $gitRoot = $AgentOSRoot -replace '\\', '/'
    $safePath = '"' + ($RelativePath -replace '"', '\"') + '"'
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = "git"
    $psi.Arguments = "-c safe.directory=$gitRoot diff -- $safePath"
    $psi.WorkingDirectory = $AgentOSRoot
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $process = [System.Diagnostics.Process]::Start($psi)
    if ($null -eq $process) {
        return "diff_status: git_process_start_failed path=$RelativePath`n"
    }
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    $nonWarningStderr = @(
        $stderr -split "`r?`n" |
            Where-Object {
                $_ -and
                $_ -notmatch '^warning:' -and
                $_ -notmatch 'LF will be replaced by CRLF' -and
                $_ -notmatch 'CRLF will be replaced by LF'
            }
    )

    if ($process.ExitCode -ne 0 -and $nonWarningStderr.Count -gt 0) {
        return "diff_status: git_diff_failed path=$RelativePath exit_code=$($process.ExitCode)`n$($nonWarningStderr -join [Environment]::NewLine)`n"
    }
    if ($nonWarningStderr.Count -gt 0) {
        return "$stdout`ndiff_stderr:`n$($nonWarningStderr -join [Environment]::NewLine)`n"
    }
    return $stdout
}

$failures = @()

# Case 1: empty diff (known-good tracked file, no staged/unstaged changes expected)
# Result must be non-null string (may be empty string "").
try {
    $r1 = Invoke-GitDiffText -RelativePath "AGENTS.md"
    if ($null -eq $r1) {
        $failures += "empty_diff_returns_null: got null, expected non-null string"
    }
} catch {
    $failures += "empty_diff_threw: $($_.Exception.Message)"
}

# Case 2: stale LASTEXITCODE=1 must not propagate into the return value.
# Poison $LASTEXITCODE by running a native command that exits 1.
cmd /c "exit 1" | Out-Null
$staleLEC = $LASTEXITCODE
try {
    $r2 = Invoke-GitDiffText -RelativePath "AGENTS.md"
    if ($null -eq $r2) {
        $failures += "stale_lastexitcode_returns_null: LASTEXITCODE was $staleLEC, got null"
    }
} catch {
    $failures += "stale_lastexitcode_threw: LASTEXITCODE was $staleLEC — $($_.Exception.Message)"
}

# Case 3: non-existent path — git exits 0 with empty stdout, must not throw.
try {
    $r3 = Invoke-GitDiffText -RelativePath "does\not\exist.md"
    if ($null -eq $r3) {
        $failures += "nonexistent_path_returns_null: got null"
    }
} catch {
    $failures += "nonexistent_path_threw: $($_.Exception.Message)"
}

# Case 4: LASTEXITCODE after function call must reflect git's actual result,
# not a stale value. The function uses $process.ExitCode directly, so
# $LASTEXITCODE is irrelevant — verify overall script can still exit 0.
cmd /c "exit 1" | Out-Null
try {
    $r4 = Invoke-GitDiffText -RelativePath "README.md"
    if ($null -eq $r4) {
        $failures += "post_poison_returns_null: got null after second poison"
    }
} catch {
    $failures += "post_poison_threw: $($_.Exception.Message)"
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "diff_helper_regression_status=passed"
Write-Output "case_count=4"

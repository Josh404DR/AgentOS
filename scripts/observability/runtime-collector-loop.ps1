[CmdletBinding()]
param(
    [string]$AgentOSRoot,
    [int]$IntervalSeconds = 15,
    [int]$TimeoutSeconds = 30
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($AgentOSRoot)) { $AgentOSRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
$root = (Resolve-Path -LiteralPath $AgentOSRoot).Path
$collector = Join-Path $root "scripts\observability\collect-runtime-status.ps1"
$stateDir = Join-Path $root "data\observability"
$lockPath = Join-Path $stateDir "runtime-collector.lock"
$statusPath = Join-Path $stateDir "runtime-collector-loop.json"
New-Item -ItemType Directory -Force -Path $stateDir | Out-Null

$lock = $null
try {
    $lock = [IO.File]::Open($lockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
} catch [IO.IOException] {
    Write-Error "Another runtime collector loop owns $lockPath"
    exit 2
}

try {
    while ($true) {
        $startedAt = Get-Date
        $stdout = Join-Path $stateDir "runtime-collector.stdout.log"
        $stderr = Join-Path $stateDir "runtime-collector.stderr.log"
        $job = Start-Job -ScriptBlock {
            param($CollectorPath, $RootPath)
            & $CollectorPath -AgentOSRoot $RootPath
        } -ArgumentList $collector, $root
        $null = Wait-Job -Job $job -Timeout $TimeoutSeconds
        if ($job.State -notin @("Completed", "Failed")) {
            Stop-Job -Job $job -ErrorAction SilentlyContinue
            $result = "timeout"
            $exitCode = $null
        } else {
            $result = if ($job.State -eq "Completed") { "success" } else { "failed" }
            $exitCode = if ($result -eq "success") { 0 } else { 1 }
        }
        $jobOutput = @(Receive-Job -Job $job -ErrorAction SilentlyContinue)
        $jobError = @($job.ChildJobs | ForEach-Object { $_.Error })
        [IO.File]::WriteAllLines($stdout, @($jobOutput | ForEach-Object { [string]$_ }), [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllLines($stderr, @($jobError | ForEach-Object { [string]$_ }), [Text.UTF8Encoding]::new($false))
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        $errorText = $null
        if ($result -ne "success") {
            $rawError = if (Test-Path $stderr) { Get-Content $stderr -Raw -ErrorAction SilentlyContinue } else { $null }
            if ([string]::IsNullOrWhiteSpace($rawError)) {
                $errorText = if ($result -eq "timeout") { "collector exceeded ${TimeoutSeconds}s timeout" } else { "collector exited with code $exitCode" }
            } elseif ($rawError.Length -gt 1000) {
                $errorText = $rawError.Substring($rawError.Length - 1000)
            } else {
                $errorText = $rawError
            }
        }
        $status = [ordered]@{
            schema_version = 1
            status = $result
            started_at = $startedAt.ToString("o")
            finished_at = (Get-Date).ToString("o")
            exit_code = $exitCode
            timeout_seconds = $TimeoutSeconds
            error = $errorText
        }
        [IO.File]::WriteAllText($statusPath, ($status | ConvertTo-Json -Depth 4), [Text.UTF8Encoding]::new($false))
        Start-Sleep -Seconds $IntervalSeconds
    }
} finally {
    if ($lock) { $lock.Dispose() }
}

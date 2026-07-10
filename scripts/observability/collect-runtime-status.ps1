[CmdletBinding()]
param(
    [string]$AgentOSRoot,
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($AgentOSRoot)) { $AgentOSRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
$root = (Resolve-Path -LiteralPath $AgentOSRoot).Path
$registry = Get-Content -LiteralPath (Join-Path $root "config\runtime_registry.json") -Raw | ConvertFrom-Json
if (-not $OutputPath) { $OutputPath = Join-Path $root "data\observability\runtime_status.json" }

$processes = @()
try { $processes = @(Get-CimInstance Win32_Process -ErrorAction Stop) } catch { $processProbeError = $_.Exception.Message }
$netstat = @(netstat -ano 2>$null)
$identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$now = Get-Date

$statuses = foreach ($runtime in $registry.runtimes) {
    $matches = @()
    if ($runtime.process_match) {
        $name = [string]$runtime.process_match.name
        $needle = [string]$runtime.process_match.command_contains
        $matches = @($processes | Where-Object {
            $_.Name -like "$name*" -and ([string]::IsNullOrWhiteSpace($needle) -or $_.CommandLine -like "*$needle*")
        })
    }

    $ports = foreach ($port in @($runtime.ports)) {
        $listening = [bool]($netstat | Select-String ":$port\s+.*LISTENING")
        [ordered]@{ port = [int]$port; listening = $listening }
    }
    $http = $null
    if ($runtime.http_health) {
        try {
            $response = Invoke-WebRequest -Uri $runtime.http_health -UseBasicParsing -TimeoutSec 3
            $http = [ordered]@{ uri = $runtime.http_health; ok = ($response.StatusCode -ge 200 -and $response.StatusCode -lt 400); status_code = $response.StatusCode }
        } catch {
            $http = [ordered]@{ uri = $runtime.http_health; ok = $false; status_code = $null; error = $_.Exception.Message }
        }
    }

    $logs = foreach ($relative in @($runtime.log_paths)) {
        $path = Join-Path $root ($relative -replace '/', '\')
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $item = Get-Item -LiteralPath $path
            [ordered]@{ path = $relative; exists = $true; last_write = $item.LastWriteTime.ToString('o'); age_seconds = [math]::Round(($now - $item.LastWriteTime).TotalSeconds, 1) }
        } else {
            [ordered]@{ path = $relative; exists = $false; last_write = $null; age_seconds = $null }
        }
    }

    $state = if (-not $runtime.enabled) { "disabled" } elseif ($http -and -not $http.ok) { "down" } elseif (@($ports).Count -and @($ports | Where-Object { -not $_.listening }).Count) { "down" } elseif ($runtime.kind -eq "per_event" -and -not $matches.Count) { "idle" } elseif ($runtime.process_match -and -not $matches.Count) { "down" } elseif ($http -and $http.ok) { "healthy" } elseif ($matches.Count) { "running" } else { "unknown" }
    [ordered]@{
        runtime_id = $runtime.runtime_id
        display_name = $runtime.display_name
        kind = $runtime.kind
        state = $state
        enabled = [bool]$runtime.enabled
        expected_identity = $runtime.expected_identity
        observed_identity = $identity
        pids = @($matches | ForEach-Object ProcessId)
        ports = @($ports)
        http = $http
        logs = @($logs)
        depends_on = @($runtime.depends_on)
    }
}

$payload = [ordered]@{
    schema_version = "1.0.0"
    collected_at = $now.ToString('o')
    collector_identity = $identity
    process_probe_error = $processProbeError
    runtimes = @($statuses)
}
$parent = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $parent | Out-Null
$temp = "$OutputPath.tmp-$PID"
[IO.File]::WriteAllText($temp, ($payload | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
Move-Item -LiteralPath $temp -Destination $OutputPath -Force
Write-Output "runtime_collector_status=PASS"
Write-Output "runtime_count=$(@($statuses).Count)"
Write-Output "output_path=$OutputPath"

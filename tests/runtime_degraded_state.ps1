[CmdletBinding()]
param([string]$AgentOSRoot)
$ErrorActionPreference = "Stop"
if (-not $AgentOSRoot) { $AgentOSRoot = Split-Path -Parent $PSScriptRoot }
$root = (Resolve-Path $AgentOSRoot).Path
$fixture = Join-Path ([IO.Path]::GetTempPath()) ("agentos-runtime-" + [Guid]::NewGuid().ToString("N"))
try {
    New-Item -ItemType Directory -Force -Path (Join-Path $fixture "config"), (Join-Path $fixture "scripts\observability") | Out-Null
    Copy-Item (Join-Path $root "scripts\observability\collect-runtime-status.ps1") (Join-Path $fixture "scripts\observability\collect-runtime-status.ps1")
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0); $listener.Start(); $port = ([Net.IPEndPoint]$listener.LocalEndpoint).Port; $listener.Stop()
    $registry = @{ schema_version = "fixture"; runtimes = @(
        @{ runtime_id="stopped-backend"; display_name="Stopped backend"; kind="api"; start_source=@{type="manual"}; expected_identity="fixture"; process_match=$null; ports=@($port); http_health="http://127.0.0.1:$port/api/health"; log_paths=@(); depends_on=@(); enabled=$true },
        @{ runtime_id="unrelated-worker"; display_name="Unrelated worker"; kind="per_event"; start_source=@{type="manual"}; expected_identity="fixture"; process_match=@{name="impossible-agentos-fixture";command_contains="none"}; ports=@(); log_paths=@(); depends_on=@(); enabled=$true }
    ) } | ConvertTo-Json -Depth 10
    [IO.File]::WriteAllText((Join-Path $fixture "config\runtime_registry.json"), $registry, [Text.UTF8Encoding]::new($false))
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fixture "scripts\observability\collect-runtime-status.ps1") -AgentOSRoot $fixture | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Fixture collector failed." }
    $status = [IO.File]::ReadAllText((Join-Path $fixture "data\observability\runtime_status.json"), [Text.Encoding]::UTF8) | ConvertFrom-Json
    $down = @($status.runtimes | Where-Object runtime_id -eq "stopped-backend")[0]
    $unrelated = @($status.runtimes | Where-Object runtime_id -eq "unrelated-worker")[0]
    if ($down.state -ne "down") { throw "Stopped backend was not down: $($down.state)" }
    if ($unrelated.state -ne "idle") { throw "Unrelated worker state broke: $($unrelated.state)" }
    "runtime_degraded_state=PASS"; "stopped_backend=down"; "unrelated_worker=idle"
} finally {
    if (Test-Path $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}

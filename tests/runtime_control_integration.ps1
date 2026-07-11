[CmdletBinding()]
param([string]$AgentOSRoot)
$ErrorActionPreference = "Stop"
if (-not $AgentOSRoot) { $AgentOSRoot = Split-Path -Parent $PSScriptRoot }
$root = (Resolve-Path $AgentOSRoot).Path
$fixture = Join-Path ([IO.Path]::GetTempPath()) ("agentos-runtime-integration-" + [Guid]::NewGuid().ToString("N"))
$receipts = @("hermes-gateway", "hermes-lite-gateway")
try {
    $hermesRoot = Join-Path $fixture "fake-hermes"
    $hermesExe = Join-Path $hermesRoot ".venv\Scripts\hermes.exe"
    New-Item -ItemType Directory -Force -Path (Split-Path $hermesExe), (Join-Path $fixture "scripts\runtimes"), (Join-Path $fixture "integrations\hermes_plugins\agentos-typed-dispatch"), (Join-Path $fixture "data\codex_tasks\queue-fixture"), (Join-Path $fixture "config") | Out-Null
    $source = 'using System; using System.Linq; using System.Threading; class P { static void Main(string[] a) { if (a.Contains("--version")) { Console.WriteLine("fixture-hermes 1.0"); return; } Thread.Sleep(60000); } }'
    $sourcePath = Join-Path $fixture "FakeHermes.cs"; [IO.File]::WriteAllText($sourcePath, $source)
    & C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /target:winexe /out:$hermesExe $sourcePath
    if ($LASTEXITCODE -ne 0) { throw "Fake Hermes compilation failed." }
    Copy-Item (Join-Path $root "scripts\start.ps1") (Join-Path $fixture "scripts\start.ps1")
    Copy-Item (Join-Path $root "scripts\start_hermes_lite.ps1") (Join-Path $fixture "scripts\start_hermes_lite.ps1")
    Copy-Item (Join-Path $root "scripts\start_task_queue.ps1") (Join-Path $fixture "scripts\start_task_queue.ps1")
    Copy-Item (Join-Path $root "scripts\runtimes\control-runtime.ps1") (Join-Path $fixture "scripts\runtimes\control-runtime.ps1")
    [IO.File]::WriteAllText((Join-Path $fixture "scripts\task_queue_runner.ps1"), 'param([string]$RootDispatchId,[string]$AgentOSRoot) Start-Sleep -Seconds 60')
    [IO.File]::WriteAllText((Join-Path $fixture "data\codex_tasks\queue-fixture\TASK.md"), "dispatch_id: queue-fixture`n")
    [IO.File]::WriteAllText((Join-Path $fixture "integrations\hermes_plugins\agentos-typed-dispatch\__init__.py"), "# fixture")
    [IO.File]::WriteAllText((Join-Path $fixture "integrations\hermes_plugins\agentos-typed-dispatch\plugin.yaml"), "name: fixture")
    $profile = Join-Path $fixture "hermes-lite-profile"; New-Item -ItemType Directory -Force -Path $profile | Out-Null
    [IO.File]::WriteAllText((Join-Path $profile ".env"), "TELEGRAM_BOT_TOKEN=fixture`nGROQ_API_KEY=fixture`n")
    $registry = @{ schema_version="fixture"; runtimes=@(
        @{runtime_id="hermes-main-gateway";start_source=@{script="scripts/start.ps1"};control=@{enabled=$true;mode="process_receipt";receipt_id="hermes-gateway";start_args=@("-SkipProxy","-HermesRoot",$hermesRoot);pass_agentos_root=$true}},
        @{runtime_id="hermes-lite-gateway";start_source=@{script="scripts/start_hermes_lite.ps1"};control=@{enabled=$true;mode="process_receipt";receipt_id="hermes-lite-gateway";start_args=@("-HermesRoot",$hermesRoot,"-ProfileHome",$profile);pass_agentos_root=$true}},
        @{runtime_id="task-queue-runner";start_source=@{script="scripts/start_task_queue.ps1"};control=@{enabled=$true;mode="queue";requires_dispatch_id=$true}}
    )} | ConvertTo-Json -Depth 10
    [IO.File]::WriteAllText((Join-Path $fixture "config\runtime_registry.json"), $registry)

    foreach ($id in @("hermes-main-gateway", "hermes-lite-gateway")) {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fixture "scripts\runtimes\control-runtime.ps1") -RuntimeId $id -Action start -AgentOSRoot $fixture | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "$id start failed." }
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fixture "scripts\runtimes\control-runtime.ps1") -RuntimeId $id -Action stop -AgentOSRoot $fixture | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "$id stop failed." }
    }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fixture "scripts\runtimes\control-runtime.ps1") -RuntimeId task-queue-runner -Action start -DispatchId queue-fixture -AgentOSRoot $fixture | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Queue fixture start failed." }
    Start-Sleep -Milliseconds 500
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fixture "scripts\runtimes\control-runtime.ps1") -RuntimeId task-queue-runner -Action stop -DispatchId queue-fixture -AgentOSRoot $fixture | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Queue fixture stop failed." }
    "runtime_control_integration=PASS"; "hermes_main_start_stop=true"; "hermes_lite_start_stop=true"; "queue_fixture_start_stop=true"
} finally {
    foreach ($receiptId in $receipts) {
        $path = Join-Path $fixture "data\runtime_receipts\$receiptId.json"
        if (Test-Path $path) { try { $pidValue = ([IO.File]::ReadAllText($path) | ConvertFrom-Json).process_id; Stop-Process -Id $pidValue -Force -ErrorAction SilentlyContinue } catch {} }
    }
    $queueState = Join-Path $fixture "data\queue_runs\queue-fixture.json"
    if (Test-Path $queueState) { try { $pidValue = ([IO.File]::ReadAllText($queueState) | ConvertFrom-Json).process_id; Stop-Process -Id $pidValue -Force -ErrorAction SilentlyContinue } catch {} }
    if (Test-Path $fixture) { Remove-Item $fixture -Recurse -Force }
}

# AgentOS Machine 2 replication script
# Run from Machine 1, targeting a mounted drive/share for Machine 2.
# By default this copies code and safe config scaffolding, but does not copy secrets.

param(
    [string]$SourceAgentOSRoot = "E:\AgentOS",
    [string]$SourceHermesRoot = "E:\AI_Projects_Hub\External_AI_Agents\hermes-agent",
    [string]$TargetAgentOSRoot = "E:\AgentOS",
    [string]$TargetHubRoot = "E:\AI_Projects_Hub",
    [switch]$IncludeHermesUserConfig,
    [switch]$IncludeSecrets
)

$ErrorActionPreference = "Stop"

$TargetHermesRoot = Join-Path $TargetHubRoot "External_AI_Agents\hermes-agent"
$TargetHermesConfigRoot = Join-Path $TargetAgentOSRoot "machine2_hermes_config"

Write-Host "=== AgentOS Machine 2 Replication ===" -ForegroundColor Cyan
Write-Host "Source AgentOS: $SourceAgentOSRoot" -ForegroundColor DarkGray
Write-Host "Source Hermes:  $SourceHermesRoot" -ForegroundColor DarkGray
Write-Host "Target AgentOS: $TargetAgentOSRoot" -ForegroundColor DarkGray
Write-Host "Target Hermes:  $TargetHermesRoot" -ForegroundColor DarkGray

function Assert-PathExists {
    param([Parameter(Mandatory=$true)][string]$Path, [string]$Label = "Path")
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Label not found: $Path"
    }
}

function Copy-Tree {
    param(
        [Parameter(Mandatory=$true)][string]$Source,
        [Parameter(Mandatory=$true)][string]$Target,
        [string[]]$ExcludeDirs = @(),
        [string[]]$ExcludeFiles = @()
    )

    Assert-PathExists -Path $Source -Label "Source"
    New-Item -ItemType Directory -Force -Path $Target | Out-Null

    $args = @($Source, $Target, "/E", "/NFL", "/NDL", "/NP", "/R:2", "/W:2")
    if ($ExcludeDirs.Count -gt 0) { $args += @("/XD") + $ExcludeDirs }
    if ($ExcludeFiles.Count -gt 0) { $args += @("/XF") + $ExcludeFiles }

    & robocopy @args | Out-Host
    if ($LASTEXITCODE -ge 8) {
        throw "robocopy failed from $Source to $Target with exit code $LASTEXITCODE"
    }
}

Assert-PathExists -Path $SourceAgentOSRoot -Label "Source AgentOS"
Assert-PathExists -Path $SourceHermesRoot -Label "Source Hermes"

Write-Host "[1/6] Creating target directories..." -ForegroundColor Green
New-Item -ItemType Directory -Force -Path $TargetAgentOSRoot | Out-Null
New-Item -ItemType Directory -Force -Path $TargetHubRoot | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $TargetHubRoot "External_AI_Agents") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $TargetAgentOSRoot "data\leads") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $TargetAgentOSRoot "data\proposals") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $TargetAgentOSRoot "data\codex_tasks") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $TargetAgentOSRoot "data\projects") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $TargetAgentOSRoot "logs") | Out-Null

Write-Host "[2/6] Copying AgentOS..." -ForegroundColor Green
Copy-Tree -Source $SourceAgentOSRoot -Target $TargetAgentOSRoot -ExcludeDirs @("logs") -ExcludeFiles @("*.log")

Write-Host "[3/6] Copying Hermes project..." -ForegroundColor Green
Copy-Tree -Source $SourceHermesRoot -Target $TargetHermesRoot -ExcludeDirs @(".git", ".uv-cache", "__pycache__", ".pytest_cache") -ExcludeFiles @("gateway_stdout.log", "gateway_stderr.log", "proxy_stdout.log", "proxy_stderr.log", "*.pyc")

Write-Host "[4/6] Preparing safe Hermes config scaffold..." -ForegroundColor Green
New-Item -ItemType Directory -Force -Path $TargetHermesConfigRoot | Out-Null
$envExample = @(
    "# Copy this to the target machine's Hermes home .env and fill secrets locally.",
    "# Default Windows Hermes home:",
    "#   C:\Users\<user>\AppData\Local\hermes\.env",
    "",
    "GOOGLE_API_KEY=",
    "GEMINI_API_KEY=",
    "TELEGRAM_BOT_TOKEN=",
    "TELEGRAM_HOME_CHANNEL="
) -join [Environment]::NewLine
Set-Content -LiteralPath (Join-Path $TargetHermesConfigRoot ".env.template") -Value $envExample -Encoding UTF8

if ($IncludeHermesUserConfig) {
    $sourceConfig = "C:\Users\brian\AppData\Local\hermes\config.yaml"
    $sourceSoul = "C:\Users\brian\AppData\Local\hermes\SOUL.md"
    if (Test-Path -LiteralPath $sourceConfig) {
        Copy-Item -LiteralPath $sourceConfig -Destination (Join-Path $TargetHermesConfigRoot "config.yaml") -Force
    }
    if (Test-Path -LiteralPath $sourceSoul) {
        Copy-Item -LiteralPath $sourceSoul -Destination (Join-Path $TargetHermesConfigRoot "SOUL.md") -Force
    }
}

if ($IncludeSecrets) {
    Write-Warning "IncludeSecrets was set. Copying Hermes .env with secrets. Use only for trusted encrypted transfer."
    $sourceEnv = "C:\Users\brian\AppData\Local\hermes\.env"
    if (Test-Path -LiteralPath $sourceEnv) {
        Copy-Item -LiteralPath $sourceEnv -Destination (Join-Path $TargetHermesConfigRoot ".env") -Force
    }
}

Write-Host "[5/6] Writing Machine 2 first-run checklist..." -ForegroundColor Green
$checklist = @(
    "# Machine 2 First Run",
    "",
    "1. Install prerequisites if missing:",
    "   - PowerShell 5+",
    "   - Python 3.13 or uv",
    "   - Node.js",
    "   - Git",
    "",
    "2. Restore Hermes user config:",
    "   - Copy machine2_hermes_config\SOUL.md to C:\Users\<user>\AppData\Local\hermes\SOUL.md",
    "   - Copy machine2_hermes_config\config.yaml to C:\Users\<user>\AppData\Local\hermes\config.yaml, if present",
    "   - Copy machine2_hermes_config\.env.template to C:\Users\<user>\AppData\Local\hermes\.env and fill secrets locally",
    "",
    "3. Rebuild Hermes venv if needed:",
    "   cd $TargetHermesRoot",
    "   uv sync --python 3.13 --reinstall",
    "",
    "4. Test Hermes:",
    "   $TargetHermesRoot\.venv\Scripts\hermes.exe --version",
    "   $TargetHermesRoot\.venv\Scripts\hermes.exe -z test",
    "",
    "5. Start AgentOS:",
    "   $TargetAgentOSRoot\scripts\start.ps1"
) -join [Environment]::NewLine
Set-Content -LiteralPath (Join-Path $TargetAgentOSRoot "MACHINE2_FIRST_RUN.md") -Value $checklist -Encoding UTF8

Write-Host "[6/6] Verifying replicated files..." -ForegroundColor Green
$required = @(
    (Join-Path $TargetAgentOSRoot "README.md"),
    (Join-Path $TargetAgentOSRoot "scripts\start.ps1"),
    (Join-Path $TargetAgentOSRoot "workflows\hermes_to_codex.md"),
    (Join-Path $TargetAgentOSRoot "workflows\ai_freelancer_os.md"),
    (Join-Path $TargetHermesRoot "pyproject.toml")
)
foreach ($item in $required) {
    if (-not (Test-Path -LiteralPath $item)) {
        throw "Verification failed. Missing: $item"
    }
}

Write-Host "=== Replication package ready ===" -ForegroundColor Cyan
Write-Host "Target AgentOS: $TargetAgentOSRoot" -ForegroundColor Green
Write-Host "Target Hermes:  $TargetHermesRoot" -ForegroundColor Green
Write-Host "Secrets copied: $IncludeSecrets" -ForegroundColor Yellow

[CmdletBinding()]
param([string]$AgentOSRoot = "E:\AgentOS")

$ErrorActionPreference = "Stop"
$statusPath = Join-Path $AgentOSRoot "data\governance\governance_status.json"
$gate = Join-Path $AgentOSRoot "scripts\assert_governance_ready.ps1"
$taskPath = Join-Path $AgentOSRoot "data\codex_tasks\ci-dispatch-resilience-success\TASK.md"
$beforeHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $statusPath).Hash
$beforeTime = (Get-Item -LiteralPath $statusPath).LastWriteTimeUtc
$output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $gate -AgentOSRoot $AgentOSRoot -TaskPath $taskPath -ReadOnly
$exit = $LASTEXITCODE
$afterHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $statusPath).Hash
$afterTime = (Get-Item -LiteralPath $statusPath).LastWriteTimeUtc
if ($exit -ne 0) { Write-Error "read-only gate failed: $($output -join ' | ')"; exit 1 }
if ($beforeHash -ne $afterHash -or $beforeTime -ne $afterTime) { Write-Error "read-only gate modified governance status"; exit 1 }
$status = Get-Content -Raw $statusPath -Encoding UTF8 | ConvertFrom-Json
if ($status.drift_count -ne 0 -or $status.operational_drift_count -lt 0) { Write-Error "tier counts invalid"; exit 1 }
$expectedStatus = if ($status.operational_drift_count -gt 0) { "operational_review_required" } else { "aligned" }
if ($status.governance_status -ne $expectedStatus) { Write-Error "unexpected status=$($status.governance_status) expected=$expectedStatus"; exit 1 }

$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("agentos-governance-tier-" + [guid]::NewGuid().ToString("N"))
$fixtureScripts = Join-Path $fixtureRoot "scripts"
$fixtureGovernance = Join-Path $fixtureRoot "data\governance"
New-Item -ItemType Directory -Force -Path $fixtureScripts, $fixtureGovernance, (Join-Path $fixtureRoot "agents\roles"), (Join-Path $fixtureRoot "docs\governance"), (Join-Path $fixtureRoot "docs") | Out-Null
Copy-Item -LiteralPath $gate -Destination (Join-Path $fixtureScripts "assert_governance_ready.ps1")
Copy-Item -LiteralPath (Join-Path $AgentOSRoot "scripts\sync_shared_governance.ps1") -Destination (Join-Path $fixtureScripts "sync_shared_governance.ps1")
$fixtureFiles = @(
    "CLAUDE.md", "agents\roles\claude.md", "agents\roles\codex.md", "agents\roles\hermes.md",
    "docs\EVIDENCE_AND_REPORTING_CONTRACT.md", "docs\COST_SAVING_ROUTING_PROTOCOL.md",
    "docs\governance\RISK_RULES.md", "docs\governance\WORKFLOW_V1_2_CONTRACT.md"
)
$utf8 = [Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText((Join-Path $fixtureRoot "AGENTS.md"), "governance_version: 1.3.0`nfixture: canonical`n", $utf8)
foreach ($relative in $fixtureFiles) { [IO.File]::WriteAllText((Join-Path $fixtureRoot $relative), "fixture: $relative`n", $utf8) }
$fixtureSync = Join-Path $fixtureScripts "sync_shared_governance.ps1"
$fixtureGate = Join-Path $fixtureScripts "assert_governance_ready.ps1"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $fixtureSync -AgentOSRoot $fixtureRoot -ApproveBaseline | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Error "fixture baseline initialization failed"; exit 1 }
$fixtureStatusPath = Join-Path $fixtureGovernance "governance_status.json"
$fixtureStatusHash = (Get-FileHash -LiteralPath $fixtureStatusPath -Algorithm SHA256).Hash
[IO.File]::WriteAllText((Join-Path $fixtureRoot "CLAUDE.md"), "fixture: changed policy`n", $utf8)
$negativeOutput = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $fixtureGate -AgentOSRoot $fixtureRoot -ReadOnly)
if ($LASTEXITCODE -ne 22 -or $negativeOutput -notcontains "governance_status=review_required") {
    Write-Error "read-only gate did not fail closed on non-AGENTS policy drift: $($negativeOutput -join ' | ')"
    exit 1
}
if ((Get-FileHash -LiteralPath $fixtureStatusPath -Algorithm SHA256).Hash -ne $fixtureStatusHash) {
    Write-Error "negative read-only scan modified fixture status"
    exit 1
}

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $fixtureSync -AgentOSRoot $fixtureRoot -ApproveBaseline | Out-Null
$baselinePath = Join-Path $fixtureGovernance "governance_baseline.json"
$baseline = Get-Content -Raw -LiteralPath $baselinePath -Encoding UTF8 | ConvertFrom-Json
$baseline.files = @($baseline.files | Where-Object { $_.path -ne "agents\roles\codex.md" })
[IO.File]::WriteAllText($baselinePath, ($baseline | ConvertTo-Json -Depth 7), $utf8)
[IO.File]::WriteAllText((Join-Path $fixtureRoot "CLAUDE.md"), "fixture: separately approved`n", $utf8)
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $fixtureSync -AgentOSRoot $fixtureRoot -ApprovePaths "CLAUDE.md" | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Error "fixture scoped approval failed"; exit 1 }
$postApproval = Get-Content -Raw -LiteralPath $fixtureStatusPath -Encoding UTF8 | ConvertFrom-Json
$codexDrift = @($postApproval.drift | Where-Object { $_.path -eq "agents\roles\codex.md" -and $_.reason -eq "not_in_baseline" })
if ($codexDrift.Count -ne 1) { Write-Error "ApprovePaths absorbed an unapproved missing baseline entry"; exit 1 }

Write-Output "governance_tiers_status=passed"
Write-Output "policy_drift_count=$($status.drift_count)"
Write-Output "operational_drift_count=$($status.operational_drift_count)"
Write-Output "readonly_status_unchanged=true"
Write-Output "readonly_noncanonical_policy_fail_closed=true"
Write-Output "approve_paths_missing_entry_preserved=true"

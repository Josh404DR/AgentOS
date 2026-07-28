[CmdletBinding()]
param(
    [string]$AgentOSRoot = "E:\AgentOS"
)

$ErrorActionPreference = "Stop"
$Utf8NoBom = [Text.UTF8Encoding]::new($false)
$failures = [Collections.Generic.List[string]]::new()
$caseCount = 0
$passCount = 0
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("agentos-verify-bundle-" + [guid]::NewGuid().ToString("N"))
$generator = Join-Path $AgentOSRoot "scripts\create_codex_verify_task.ps1"
$version = "1.3.0"
$hash = "0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1"

function Write-FixtureFile {
    param([string]$Path, [string]$Content)
    $parent = Split-Path -Parent $Path
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    [IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
}

function New-FixtureTask {
    param(
        [string]$Id,
        [string]$TaskBody,
        [string]$ResultBody
    )
    $taskDir = Join-Path $fixtureRoot "data\codex_tasks\$Id"
    Write-FixtureFile (Join-Path $taskDir "TASK.md") @"
# Verify bundle fixture

dispatch_id: $Id
type: CODEX_BUILD
assigned_to: Codex
route_to: Codex
codex_mode: build
task_status: completed
dispatch_status: completed
requires_josh_approval: false
approval: offline_fixture
governance_version: $version
governance_hash: $hash

$TaskBody
"@
    Write-FixtureFile (Join-Path $taskDir "OUTPUTS\RESULT.md") $ResultBody
    return $taskDir
}

function Invoke-Generator {
    param([string]$Id)
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $generator `
        -ParentDispatchId $Id -AgentOSRoot $fixtureRoot 2>&1
    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output = ($output -join "`n")
        OutputDir = Join-Path $fixtureRoot "data\codex_tasks\$Id\OUTPUTS"
    }
}

function Assert-Case {
    param(
        [string]$Name,
        [scriptblock]$Arrange,
        [scriptblock]$Assert
    )
    $script:caseCount++
    try {
        $context = & $Arrange
        & $Assert $context
        $script:passCount++
        Write-Output "case=$Name status=PASS"
    } catch {
        $script:failures.Add("$Name`: $($_.Exception.Message)")
        Write-Output "case=$Name status=FAIL reason=$($_.Exception.Message)"
    }
}

function Assert-Match {
    param([string]$Text, [string]$Pattern, [string]$Message)
    if ($Text -notmatch $Pattern) { throw $Message }
}

function Assert-NotMatch {
    param([string]$Text, [string]$Pattern, [string]$Message)
    if ($Text -match $Pattern) { throw $Message }
}

try {
    New-Item -ItemType Directory -Force -Path $fixtureRoot | Out-Null
    & git -c "safe.directory=$($fixtureRoot -replace '\\','/')" init $fixtureRoot 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "fixture git init failed" }

    Assert-Case "read_only_analysis" {
        $id = "fixture-read-only"
        New-FixtureTask $id @"
impact_scope: read-only analysis

## Scope

Inspect ``scripts\read-only-example.ps1``.

## Out of Scope

Do not modify any existing files.
"@ @"
change_required: false
evidence: offline read-only fixture
"@ | Out-Null
        Invoke-Generator $id
    } {
        param($c)
        if ($c.ExitCode -ne 0) { throw "generator exit=$($c.ExitCode): $($c.Output)" }
        $bundle = Get-Content -Raw -Encoding UTF8 (Join-Path $c.OutputDir "VERIFY_BUNDLE.md")
        Assert-Match $bundle '(?m)^change_required: false$' "read-only change_required was not false"
        Assert-Match $bundle '(?m)^changed_file_source: read_only_ticket_no_scope_mining$' "read-only source was not explicit"
        Assert-NotMatch $bundle 'read-only-example\.ps1' "read-only Scope mining was not short-circuited"
    }

    Assert-Case "query_type_evidence" {
        $id = "fixture-query"
        New-FixtureTask $id "impact_scope: internal_only" @"
change_required: false
evidence: query response checked against local fixture
"@ | Out-Null
        Invoke-Generator $id
    } {
        param($c)
        if ($c.ExitCode -ne 0) { throw "generator exit=$($c.ExitCode): $($c.Output)" }
        $bundle = Get-Content -Raw -Encoding UTF8 (Join-Path $c.OutputDir "VERIFY_BUNDLE.md")
        $testResult = Get-Content -Raw -Encoding UTF8 (Join-Path $c.OutputDir "TEST_RESULT.md")
        Assert-Match $bundle '(?m)^change_required: false$' "query change_required was not false"
        Assert-Match $testResult '(?m)^evidence: query response checked against local fixture$' "query evidence was not preserved"
    }

    Assert-Case "revision_original_context" {
        $originalId = "fixture-original"
        $originalDir = New-FixtureTask $originalId "impact_scope: internal_only" "change_required: false"
        Write-FixtureFile (Join-Path $originalDir "OUTPUTS\TEST_RESULT.full.md") "original_gate_evidence=PASS"
        $revisionId = "fixture-revision"
        New-FixtureTask $revisionId @"
revision_of: $originalId
impact_scope: internal_only
"@ @"
changed_file: data\codex_tasks\$revisionId\OUTPUTS\RESULT.md
change_required: true
evidence: revision fixture
"@ | Out-Null
        Invoke-Generator $revisionId
    } {
        param($c)
        if ($c.ExitCode -ne 0) { throw "generator exit=$($c.ExitCode): $($c.Output)" }
        $bundle = Get-Content -Raw -Encoding UTF8 (Join-Path $c.OutputDir "VERIFY_BUNDLE.md")
        Assert-Match $bundle '## Original Ticket Context' "revision original context section missing"
        Assert-Match $bundle 'fixture-original\\OUTPUTS\\TEST_RESULT\.full\.md' "original TEST_RESULT.full.md missing"
    }

    Assert-Case "out_of_scope_whole_file" {
        $id = "fixture-out-of-scope"
        New-FixtureTask $id @"
impact_scope: internal_only

## Scope

Modify ``scripts\allowed.ps1`` and inspect ``scripts\forbidden.ps1``.

## Out of Scope

Do not modify ``scripts\forbidden.ps1``.
"@ "evidence: out-of-scope fixture" | Out-Null
        Write-FixtureFile (Join-Path $fixtureRoot "scripts\allowed.ps1") "Write-Output 'allowed'"
        Write-FixtureFile (Join-Path $fixtureRoot "scripts\forbidden.ps1") "Write-Output 'forbidden'"
        Invoke-Generator $id
    } {
        param($c)
        if ($c.ExitCode -ne 0) { throw "generator exit=$($c.ExitCode): $($c.Output)" }
        $bundle = Get-Content -Raw -Encoding UTF8 (Join-Path $c.OutputDir "VERIFY_BUNDLE.md")
        Assert-Match $bundle 'scripts\\allowed\.ps1' "allowed file missing"
        Assert-NotMatch $bundle 'scripts\\forbidden\.ps1' "explicitly forbidden whole file was included"
    }

    Assert-Case "untracked_new_file" {
        $id = "fixture-untracked"
        New-FixtureTask $id "impact_scope: internal_only" @"
changed_file: scripts\new-delivery.ps1
change_required: true
test_result: PASS
"@ | Out-Null
        Write-FixtureFile (Join-Path $fixtureRoot "scripts\new-delivery.ps1") "Write-Output 'new delivery'"
        Invoke-Generator $id
    } {
        param($c)
        if ($c.ExitCode -ne 0) { throw "generator exit=$($c.ExitCode): $($c.Output)" }
        $diff = Get-Content -Raw -Encoding UTF8 (Join-Path $c.OutputDir "SCOPED_DIFF.patch")
        Assert-Match $diff 'diff_status: new_untracked_file path=scripts\\new-delivery\.ps1' "untracked status missing"
        Assert-Match $diff "Write-Output 'new delivery'" "untracked full content missing"
    }

    Assert-Case "git_manifest_mismatch" {
        $id = "fixture-manifest-mismatch"
        $taskDir = New-FixtureTask $id "impact_scope: internal_only" @"
change_required: false
evidence: manifest mismatch fixture
"@
        Write-FixtureFile (Join-Path $taskDir "OUTPUTS\GIT_VERIFIED_CHANGES.json") @"
{
  "snapshot_status": "captured",
  "before_reason": "",
  "after_reason": "",
  "git_verified_files_modified": [],
  "git_verified_files_created": ["scripts/actual-new-file.ps1"],
  "git_verified_files_deleted": []
}
"@
        Invoke-Generator $id
    } {
        param($c)
        if ($c.ExitCode -ne 0) { throw "generator exit=$($c.ExitCode): $($c.Output)" }
        $bundle = Get-Content -Raw -Encoding UTF8 (Join-Path $c.OutputDir "VERIFY_BUNDLE.md")
        Assert-Match $bundle '(?m)^git_verified_snapshot: captured; modified=0 created=1 deleted=0' "captured manifest summary missing"
        Assert-Match $bundle '(?m)^evidence_manifest_mismatch: true$' "manifest mismatch was not true"
    }

    Assert-Case "git_manifest_no_mismatch" {
        $id = "fixture-manifest-match"
        $taskDir = New-FixtureTask $id "impact_scope: internal_only" @"
change_required: false
evidence: manifest match fixture
"@
        Write-FixtureFile (Join-Path $taskDir "OUTPUTS\GIT_VERIFIED_CHANGES.json") @"
{
  "snapshot_status": "captured",
  "before_reason": "",
  "after_reason": "",
  "git_verified_files_modified": [],
  "git_verified_files_created": [],
  "git_verified_files_deleted": []
}
"@
        Invoke-Generator $id
    } {
        param($c)
        if ($c.ExitCode -ne 0) { throw "generator exit=$($c.ExitCode): $($c.Output)" }
        $bundle = Get-Content -Raw -Encoding UTF8 (Join-Path $c.OutputDir "VERIFY_BUNDLE.md")
        Assert-Match $bundle '(?m)^git_verified_snapshot: captured; modified=0 created=0 deleted=0$' "zero-change captured summary missing"
        Assert-Match $bundle '(?m)^evidence_manifest_mismatch: false$' "matching zero-change manifest was marked mismatch"
    }

    Assert-Case "newer_test_result_refreshes_backup" {
        $id = "fixture-test-result-refresh"
        $taskDir = New-FixtureTask $id "impact_scope: internal_only" @"
changed_file: data\codex_tasks\$id\OUTPUTS\TEST_RESULT.md
change_required: true
"@
        $outputs = Join-Path $taskDir "OUTPUTS"
        $backup = Join-Path $outputs "TEST_RESULT.full.md"
        $current = Join-Path $outputs "TEST_RESULT.md"
        Write-FixtureFile $backup "case_count=6"
        Write-FixtureFile $current "case_count=7`nnew_evidence=PASS"
        [IO.File]::SetLastWriteTimeUtc($backup, [DateTime]::UtcNow.AddMinutes(-2))
        [IO.File]::SetLastWriteTimeUtc($current, [DateTime]::UtcNow.AddMinutes(-1))
        Invoke-Generator $id
    } {
        param($c)
        if ($c.ExitCode -ne 0) { throw "generator exit=$($c.ExitCode): $($c.Output)" }
        $testResult = Get-Content -Raw -Encoding UTF8 (Join-Path $c.OutputDir "TEST_RESULT.md")
        $backupResult = Get-Content -Raw -Encoding UTF8 (Join-Path $c.OutputDir "TEST_RESULT.full.md")
        Assert-Match $c.Output '(?m)^test_result_backup_refreshed=' "newer test result did not refresh backup"
        Assert-Match $testResult '(?m)^case_count=7$' "current test evidence rolled back"
        Assert-Match $backupResult '(?m)^new_evidence=PASS$' "backup did not receive newer evidence"
    }

    Assert-Case "agent_outputs_included_task_control_excluded" {
        $id = "fixture-agent-output-scope"
        $taskDir = New-FixtureTask $id "impact_scope: internal_only" @"
changed_file: data\codex_tasks\$id\TASK.md
changed_file: data\codex_tasks\$id\OUTPUTS\RESULT.md
changed_file: data\codex_tasks\$id\OUTPUTS\TEST_RESULT.md
change_required: true
"@
        Write-FixtureFile (Join-Path $taskDir "OUTPUTS\TEST_RESULT.md") "agent_test_evidence=PASS"
        Invoke-Generator $id
    } {
        param($c)
        if ($c.ExitCode -ne 0) { throw "generator exit=$($c.ExitCode): $($c.Output)" }
        $diff = Get-Content -Raw -Encoding UTF8 (Join-Path $c.OutputDir "SCOPED_DIFF.patch")
        Assert-Match $diff 'OUTPUTS\\RESULT\.md' "agent-authored RESULT.md missing from scoped diff"
        Assert-Match $diff 'OUTPUTS\\TEST_RESULT\.md' "agent-authored TEST_RESULT.md missing from scoped diff"
        Assert-NotMatch $diff 'diff_status: new_untracked_file path=data\\codex_tasks\\fixture-agent-output-scope\\TASK\.md' "TASK.md control artifact entered scoped diff"
        Assert-Match $c.Output 'changed_file=\[data\\codex_tasks\\fixture-agent-output-scope\\TASK\.md\] skipped=pipeline_transport_or_control_artifact' "TASK.md exclusion trace missing"
    }
} finally {
    if (Test-Path -LiteralPath $fixtureRoot) {
        $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        $resolvedFixture = [IO.Path]::GetFullPath($fixtureRoot)
        if ($resolvedFixture.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
        }
    }
}

if ($failures.Count) {
    $failures | ForEach-Object { Write-Error $_ }
    Write-Output "verify_bundle_generation=FAIL cases=$caseCount passed=$passCount failed=$($failures.Count)"
    exit 1
}

Write-Output "verify_bundle_generation=PASS cases=$caseCount passed=$passCount failed=0"

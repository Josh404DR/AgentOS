[CmdletBinding()]
param([string]$AgentOSRoot = "E:\AgentOS")

$ErrorActionPreference = "Stop"
. (Join-Path $AgentOSRoot "scripts\url_knowledge_security.ps1")

$failures = [Collections.Generic.List[string]]::new()
function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { $failures.Add($Message) }
}
function Assert-Throws([scriptblock]$Action, [string]$Message) {
    try {
        & $Action
        $failures.Add($Message)
    } catch {
        # Expected fail-closed behavior.
    }
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("agentos-url-boundary-" + [guid]::NewGuid().ToString("N"))
$dispatchId = "boundary-test-dispatch"
$intakeRoot = Join-Path $tempRoot "data\url_intake\$dispatchId"
$outsideRoot = Join-Path $tempRoot "outside"
New-Item -ItemType Directory -Force -Path $intakeRoot, $outsideRoot | Out-Null
$inside = Join-Path $intakeRoot "source.json"
$outside = Join-Path $outsideRoot "secret.json"
[IO.File]::WriteAllText($inside, '{"text":"繁體中文來源"}', [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText($outside, '{"secret":true}', [Text.UTF8Encoding]::new($false))

try {
    $resolved = Assert-AgentOSSourceJsonBoundary -AgentOSRoot $tempRoot -DispatchId $dispatchId -SourceJsonPath $inside
    Assert-True ($resolved.EndsWith('source.json')) "valid in-bound source_json_path was rejected"

    $traversal = Join-Path $intakeRoot "..\..\..\outside\secret.json"
    Assert-Throws {
        Assert-AgentOSSourceJsonBoundary -AgentOSRoot $tempRoot -DispatchId $dispatchId -SourceJsonPath $traversal
    } "source_json_path containing .. did not fail closed"
    Assert-Throws {
        Assert-AgentOSSourceJsonBoundary -AgentOSRoot $tempRoot -DispatchId $dispatchId -SourceJsonPath $outside
    } "absolute out-of-bound source_json_path did not fail closed"

    $junction = Join-Path $intakeRoot "escape"
    New-Item -ItemType Junction -Path $junction -Target $outsideRoot | Out-Null
    Assert-Throws {
        Assert-AgentOSSourceJsonBoundary -AgentOSRoot $tempRoot -DispatchId $dispatchId -SourceJsonPath (Join-Path $junction "secret.json")
    } "junction/symlink source_json_path did not fail closed"

    $sha = ('A' * 64)
    $strictPass = @"
review_schema_version: 1
review_status: PASS
dispatch_id: $dispatchId
reviewed_result_sha256: $sha
reviewer_role: Claude Inspector
findings: none
"@
    Assert-True (Test-AgentOSStrictClaudeReview $strictPass $dispatchId $sha) "strict Claude PASS schema was rejected"
    Assert-True (-not (Test-AgentOSStrictClaudeReview ($strictPass.Replace('review_status: PASS', 'review_status: PASS_WITH_CAVEATS')) $dispatchId $sha)) "PASS_WITH_CAVEATS was accepted"
    Assert-True (-not (Test-AgentOSStrictClaudeReview "review_status: PASS" $dispatchId $sha)) "incomplete review schema was accepted"

    $verifyPass = @"
verify_schema_version: 1
verify_verdict: PASS
verification_mode: fresh_read_only
source_dispatch_id: $dispatchId
verified_result_sha256: $sha
verifier_role: Codex Verify
"@
    Assert-True (Test-AgentOSFreshCodexVerify $verifyPass $dispatchId $sha) "fresh Codex Verify PASS schema was rejected"
    Assert-True (-not (Test-AgentOSFreshCodexVerify ($verifyPass.Replace('fresh_read_only', 'builder')) $dispatchId $sha)) "non-fresh verifier was accepted"
    Assert-True (-not (Test-AgentOSFreshCodexVerify ($verifyPass.Replace('verify_verdict: PASS', 'verify_verdict: FAIL')) $dispatchId $sha)) "FAIL verifier was accepted"
} finally {
    $resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
    $allowedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedTemp.StartsWith($allowedTemp, [StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($failures.Count) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Output "url_knowledge_security_tests=PASS"
Write-Output "path_boundary_cases=valid,traversal,absolute_outside,junction"
Write-Output "review_gate_cases=strict_pass,caveats,incomplete"
Write-Output "verify_gate_cases=fresh_pass,nonfresh,fail"

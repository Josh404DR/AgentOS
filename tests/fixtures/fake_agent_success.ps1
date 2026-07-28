param([string]$AgentOutputPath)
if ($AgentOutputPath -match 'invalid-verify') {
    [IO.File]::WriteAllText($AgentOutputPath, "verify_verdict: NEEDS_HUMAN_DECISION`n", [Text.UTF8Encoding]::new($false))
    Write-Output "fake_agent_status=verdict_only"
    exit 0
}
$text = @"
change_required: false
evidence: fake_agent_success
test_command: fake_agent_success.ps1
test_result: PASS — offline fixture
"@
[IO.File]::WriteAllText($AgentOutputPath, $text, [Text.UTF8Encoding]::new($false))
Write-Output "fake_agent_status=success"
exit 0

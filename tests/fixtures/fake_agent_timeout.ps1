param([string]$AgentOutputPath)
[IO.File]::WriteAllText("$AgentOutputPath.pid", [string]$PID, [Text.UTF8Encoding]::new($false))
Start-Sleep -Seconds 10
Write-Output "unexpected_completion"
exit 0

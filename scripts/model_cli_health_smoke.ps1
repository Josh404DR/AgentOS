[CmdletBinding()]
param([string]$AgentOSRoot = "E:\AgentOS", [string]$OutputPath, [int]$TimeoutSeconds = 90)
$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $AgentOSRoot).Path
if (-not $OutputPath) { $OutputPath = Join-Path $root "data\ci_health\model-cli-latest.json" }
$work = Join-Path $env:TEMP "agentos-model-cli-smoke-$PID"
New-Item -ItemType Directory -Force -Path $work | Out-Null
$prompt = "Reply with exactly AGENTOS_SMOKE_OK. Do not use tools or modify files."
$promptPath = Join-Path $work "prompt.txt"
[IO.File]::WriteAllText($promptPath, $prompt, [Text.UTF8Encoding]::new($false))

function Invoke-CliProbe {
    param([string]$Name, [string]$Command, [string]$VersionCommand, [string]$FilePath, [string]$Arguments, [string]$StdinText = "")
    $version = (& cmd.exe /d /c $VersionCommand 2>&1 | Out-String).Trim(); $versionExit = $LASTEXITCODE
    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $FilePath; $psi.Arguments = $Arguments; $psi.WorkingDirectory = $root
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true; $psi.RedirectStandardInput = $true
    if ($Name -eq "codex") {
        $null = $psi.EnvironmentVariables.Remove("OPENAI_API_KEY")
        $null = $psi.EnvironmentVariables.Remove("CODEX_API_KEY")
    }
    $process = [Diagnostics.Process]::new(); $process.StartInfo = $psi
    [void]$process.Start()
    if ($StdinText) { $process.StandardInput.Write($StdinText) }
    $process.StandardInput.Close()
    $outputTask = $process.StandardOutput.ReadToEndAsync(); $errorTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) { & taskkill.exe /PID $process.Id /T /F | Out-Null }
    if (-not $timedOut) { $process.WaitForExit() }
    $output = $outputTask.GetAwaiter().GetResult(); $errorText = $errorTask.GetAwaiter().GetResult()
    $exitCode = if ($timedOut) { $null } else { $process.ExitCode }
    $allText = ($output + "`n" + $errorText).Trim()
    $allText = $allText -replace 'sk-[A-Za-z0-9_-]{8,}', '[REDACTED_API_KEY]'
    if ($allText.Length -gt 2000) { $allText = $allText.Substring($allText.Length - 2000) }
    $ok = -not $timedOut -and $exitCode -eq 0 -and $allText -match "AGENTOS_SMOKE_OK"
    $failureKind = if ($ok) { $null } elseif ($timedOut) { "timeout" } elseif ($allText -match "newer version|upgrade to the latest") { "version_incompatible" } elseif ($allText -match "401|invalid_api_key|Incorrect API key") { "authentication" } elseif ($allText -match "quota|session limit|rate limit") { "quota_or_limit" } elseif (-not (Get-Command $Command -ErrorAction SilentlyContinue) -and -not (Test-Path -LiteralPath $Command)) { "binary_missing" } else { "invocation_failed" }
    [ordered]@{ name=$Name; command=$Command; resolved_path=(Get-Command $Command -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source); version=$version; version_exit_code=$versionExit; invocation_exit_code=$exitCode; timed_out=$timedOut; status=$(if($ok){"PASS"}else{"FAIL"}); failure_kind=$failureKind; detail=$allText }
}

$agy = Join-Path $env:LOCALAPPDATA "agy\bin\agy.exe"
$probes = @(
    (Invoke-CliProbe "codex" "codex" "codex --version" "cmd.exe" "/d /c codex -a never exec -C `"$root`" --sandbox read-only -" $prompt),
    (Invoke-CliProbe "claude" "claude" "claude --version" "cmd.exe" "/d /c claude -p --permission-mode default --no-session-persistence" $prompt),
    (Invoke-CliProbe "antigravity" $agy "`"$agy`" --version" $agy "--sandbox --print-timeout 1m --print `"$prompt`"")
)
$result = [ordered]@{ schema_version=1; checked_at=(Get-Date).ToString("o"); identity=[Security.Principal.WindowsIdentity]::GetCurrent().Name; status=$(if(@($probes|Where-Object status -eq "FAIL").Count){"FAIL"}else{"PASS"}); models_invoked=$true; probes=$probes }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null
[IO.File]::WriteAllText($OutputPath, (($result|ConvertTo-Json -Depth 6)+[Environment]::NewLine), [Text.UTF8Encoding]::new($false))
$probes|ForEach-Object{Write-Output "model_cli=$($_.name) status=$($_.status) version=$($_.version) exit=$($_.invocation_exit_code)"}
Write-Output "model_cli_smoke_status=$($result.status)"; Write-Output "result_path=$OutputPath"
if($result.status-ne"PASS"){exit 1}

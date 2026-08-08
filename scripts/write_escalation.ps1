[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$TaskId,
    [Parameter(Mandatory = $true)]
    [ValidateSet("simple_fail","complex_fail","risky_task","classification_unclear","verify_needs_human","raw_intake","raw_intake_approval")]
    [string]$Source,
    [Parameter(Mandatory = $true)][string]$Reason,
    [Parameter(Mandatory = $true)]
    [ValidateSet("approve_risky_action","clarify_requirement","accept_partial_delivery","stop_task","retry_with_changes","raw_intake","raw_intake_approval")]
    [string]$DecisionType,
    [Parameter(Mandatory = $true)][string]$SummaryForJosh,
    [string]$AgentOSRoot = "E:\AgentOS",
    [ValidateSet("ci","runtime")]
    [string]$Environment = "runtime",
    [ValidateSet("true", "false", "")]
    [string]$IsFixture = "",
    # Confirmed root cause (2026-07-27, verified via isolated repro against a
    # minimal param-only script, not guessed): when this script is invoked as
    # a NEW process (`powershell.exe -File ... -Evidence @($a,$b) -AgentOSRoot
    # $x`), the parent shell flattens the -Evidence array into separate bare
    # command-line tokens. The child process's -File argument binder only
    # binds the FIRST such token to -Evidence; the rest are left "unbound"
    # and get mis-assigned POSITIONALLY to whatever optional parameter comes
    # next in declaration order (this is what caused Evidence[1] to land on
    # -Environment and fail its ValidateSet). `ValueFromRemainingArguments`
    # on $Evidence (below) does NOT fix this for -File invocation - confirmed
    # by direct repro, not assumed. Comma-joining a single string also does
    # NOT auto-split back into an array across -File - confirmed by repro.
    # Passing raw JSON as a single string also breaks, because Windows
    # command-line argument parsing strips/mangles embedded double quotes
    # across the process boundary - confirmed by repro. The only approach
    # that survives the -File process boundary intact is Base64-encoded JSON
    # (verified end-to-end, including that malformed input now fails loudly
    # instead of silently becoming an empty array): use -EvidenceB64 for any
    # call site that needs to pass more than one evidence item across a
    # `powershell.exe -File` boundary. -Evidence is kept for backward
    # compatibility with existing single-item / same-process callers.
    [string]$EvidenceB64 = "",
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Evidence = @()
)

$ErrorActionPreference = "Stop"
$utf8 = [Text.UTF8Encoding]::new($false)
. (Join-Path $PSScriptRoot "lib\global_jsonl_lock.ps1")
$safeId = [regex]::Replace($TaskId, '[^A-Za-z0-9_.-]+', '-')
$root = Join-Path $AgentOSRoot "data\escalations"
$taskDir = Join-Path $root $safeId
New-Item -ItemType Directory -Force -Path $taskDir | Out-Null
$createdAt = Get-Date -Format o
$stamp = Get-Date -Format "yyyyMMdd-HHmmss-fff"
$path = Join-Path $taskDir "$stamp.json"
$indexPath = Join-Path $root "ESCALATION_INDEX.jsonl"

if (Test-Path -LiteralPath $indexPath) {
    foreach ($line in Get-Content -LiteralPath $indexPath -Encoding UTF8) {
        if (-not $line.Trim()) { continue }
        try {
            $existing = $line | ConvertFrom-Json
            if ($existing.task_id -eq $TaskId -and
                $existing.source -eq $Source -and
                $existing.reason -eq $Reason -and
                $existing.status -eq "awaiting_josh") {
                Write-Output "escalation_status=already_exists"
                Write-Output "escalation_path=$($existing.artifact_path)"
                Write-Output "escalation_index=$indexPath"
                exit 0
            }
        } catch {
            continue
        }
    }
}

$isFixtureValue = if ($IsFixture -eq "") { $Environment -eq "ci" } else { [bool]::Parse($IsFixture) }

# No try/catch here on purpose: a malformed -EvidenceB64 must be a loud,
# terminating failure (script has $ErrorActionPreference = "Stop" set above),
# not a silent fallback to an empty evidence array. A caller that thinks it
# is recording evidence must never end up with a "successful" escalation
# that actually recorded none.
$finalEvidence = if ($EvidenceB64) {
    $evidenceJsonText = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($EvidenceB64))
    # Confirmed via isolated repro (2026-07-27, PowerShell 5.1.26100.8894):
    # ConvertFrom-Json's returned array carries hidden wrapping that later
    # makes ConvertTo-Json mis-serialize it as {"value":[...],"Count":N}
    # instead of a plain JSON array, whenever that array is nested inside
    # another hashtable (as it is here, inside $payload/$indexLine). A
    # control test proved a literal array serializes correctly and this one
    # does not; rebuilding element-by-element strips the wrapping and
    # restores correct serialization. Do not "simplify" this back to
    # `@(... | ConvertFrom-Json)` - that reintroduces the bug.
    @((ConvertFrom-Json -InputObject $evidenceJsonText) | ForEach-Object { [string]$_ })
} else {
    @($Evidence)
}

$payload = [ordered]@{
    task_id = $TaskId
    source = $Source
    reason = $Reason
    decision_type = $DecisionType
    summary_for_josh = $SummaryForJosh
    options = @(
        [ordered]@{ label = "Approve"; effect = ([char[]]@(0x5141,0x8A31,0x5728,0x6838,0x51C6,0x7BC4,0x570D,0x5167,0x7E7C,0x7E8C,0x57F7,0x884C) -join '') },
        [ordered]@{ label = "Modify"; effect = ([char[]]@(0x8ABF,0x6574,0x9700,0x6C42,0x5F8C,0x91CD,0x8DD1) -join '') },
        [ordered]@{ label = "Stop"; effect = ([char[]]@(0x505C,0x6B62,0x4EFB,0x52D9) -join '') }
    )
    evidence = $finalEvidence
    environment = $Environment
    is_fixture = $isFixtureValue
    created_at = $createdAt
    status = "awaiting_josh"
}

$json = $payload | ConvertTo-Json -Depth 8
[IO.File]::WriteAllText($path, $json + [Environment]::NewLine, $utf8)
$indexLine = ([ordered]@{
    task_id = $TaskId
    source = $Source
    reason = $Reason
    artifact_path = $path
    environment = $Environment
    is_fixture = $isFixtureValue
    created_at = $createdAt
    status = "awaiting_josh"
} | ConvertTo-Json -Compress)
$pendingLine = $indexLine + [Environment]::NewLine
Invoke-GlobalJsonlLockedAppend -LiteralPath $indexPath -PendingContent $pendingLine -AppendAction {
    [IO.File]::AppendAllText($indexPath, $pendingLine, $utf8)
}

Write-Output "escalation_status=created"
Write-Output "escalation_path=$path"
Write-Output "escalation_index=$indexPath"

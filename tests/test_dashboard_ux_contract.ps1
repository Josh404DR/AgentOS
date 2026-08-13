[CmdletBinding()]
param([string]$AgentOSRoot = "E:\AgentOS")

$ErrorActionPreference = 'Stop'
$page = Get-Content (Join-Path $AgentOSRoot 'dashboard\frontend\app\page.tsx') -Raw -Encoding UTF8
$queue = Get-Content (Join-Path $AgentOSRoot 'dashboard\frontend\components\ApprovalQueue.tsx') -Raw -Encoding UTF8
$api = Get-Content (Join-Path $AgentOSRoot 'dashboard\frontend\lib\api.ts') -Raw -Encoding UTF8
$owner = Get-Content (Join-Path $AgentOSRoot 'dashboard\frontend\components\OwnerSession.tsx') -Raw -Encoding UTF8
$start = Get-Content (Join-Path $AgentOSRoot 'dashboard\start.ps1') -Raw -Encoding UTF8
$docs = Get-Content (Join-Path $AgentOSRoot 'docs\DASHBOARD_API_POWERSHELL_UTF8.md') -Raw -Encoding UTF8
$checks = [ordered]@{
    approval_queue_imported = $page -match 'import ApprovalQueue'
    approval_queue_rendered = $page -match '<ApprovalQueue\s*/>'
    unauthenticated_prompt = $queue -match '需登入才能決策'
    decision_endpoint = $api -match '/api/approvals/\$\{encodeURIComponent\(id\)\}/decision'
    token_path_guidance = $owner -match 'data\\dashboard_auth\\owner-token.txt'
    restart_guidance = $owner -match '過期請重啟 backend'
    reclaim_switch = $start -match '\[switch\]\$ReclaimOrphans'
    utf8_content_type = $docs -match 'application/json; charset=utf-8'
    utf8_body_bytes = $docs -match 'UTF8.GetBytes'
}
$failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })
if ($failed.Count) { throw "dashboard UX contract failed: $($failed -join ',')" }
Write-Output 'dashboard_ux_contract=PASS'
$checks.GetEnumerator() | ForEach-Object { Write-Output "$($_.Key)=$($_.Value.ToString().ToLowerInvariant())" }

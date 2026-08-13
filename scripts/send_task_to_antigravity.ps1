param(
    [Parameter(Mandatory = $true)]
    [string]$TaskPath,

    [string]$WindowTitlePattern = "Antigravity",

    [switch]$CopyOnly
)

$ErrorActionPreference = "Stop"
$AgentOSRoot = "E:\AgentOS"

# Verify role file exists before execution
$rolePath = "E:\AgentOS\integrations\antigravity\AGENTOS_ROLE.md"
if (-not (Test-Path -LiteralPath $rolePath -PathType Leaf)) {
    throw "Required role file not found: $rolePath"
}

# 1. Check the canonical governance gate. Operational drift is non-blocking
# for work already inside an approved task scope.
$govGateScript = Join-Path $AgentOSRoot "scripts\assert_governance_ready.ps1"
if (-not (Test-Path -LiteralPath $govGateScript)) {
    throw "Governance gate script not found: $govGateScript"
}

$govOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $govGateScript -AgentOSRoot $AgentOSRoot 2>&1
$executionAllowed = $false
foreach ($line in $govOutput) {
    if ("$line" -like "*task_execution_allowed=true*") {
        $executionAllowed = $true
    }
}
if ($LASTEXITCODE -ne 0 -or -not $executionAllowed) {
    throw "Governance gate denied task execution."
}

# 2. Validate TaskPath
if ($TaskPath.Contains('*') -or $TaskPath.Contains('?')) {
    throw "Wildcards are not allowed in TaskPath."
}

try {
    $resolved = Resolve-Path -LiteralPath $TaskPath -ErrorAction Stop
} catch {
    throw "Invalid TaskPath: $_"
}
$resolvedPath = $resolved.Path

$tasksFolder = Join-Path $AgentOSRoot "data\codex_tasks\"
if (-not $resolvedPath.StartsWith($tasksFolder, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "TaskPath must be located inside E:\AgentOS\data\codex_tasks\"
}

$filename = Split-Path $resolvedPath -Leaf
if ($filename -ne "TASK.md") {
    throw "Filename must be exactly TASK.md"
}

# 3. Read and validate TASK.md contents
$content = Get-Content -Raw -LiteralPath $resolvedPath -Encoding UTF8

if ($content -notmatch "dispatch_id" -and $content -notmatch "task_id") {
    throw "TASK.md is missing 'dispatch_id' or 'task_id'."
}
if ($content -notmatch "assigned_to:\s*Antigravity\s*IDE") {
    throw "TASK.md is missing 'assigned_to: Antigravity IDE'."
}
if ($content -notmatch "acceptance\s*criteria" -and $content -notmatch "Acceptance\s*Criteria") {
    throw "TASK.md is missing 'acceptance criteria' or 'Acceptance Criteria'."
}

# Extract dispatch_id/task_id
$dispatchId = $null
if ($content -match "dispatch_id:\s*([^\r\n]+)") {
    $dispatchId = $Matches[1].Trim()
} elseif ($content -match "dispatch_id\s*=\s*([^\r\n]+)") {
    $dispatchId = $Matches[1].Trim()
} elseif ($content -match "task_id:\s*([^\r\n]+)") {
    $dispatchId = $Matches[1].Trim()
} else {
    throw "Could not extract dispatch_id or task_id from TASK.md"
}

# 4. Assemble the exact text to paste
$base64Text = "6KuL5L6d54WnIEU6XEFnZW50T1NcaW50ZWdyYXRpb25zXGFudGlncmF2aXR5XEFHRU5UT1NfUk9MRS5tZO+8jArln7fooYzku6XkuIsgQWdlbnRPUyDlt6Xllq7vvJoKCnswfQoK5a6M5oiQ5b6M6KuL5bCH57WQ5p6c5a+r5YWl6Kmy5bel5Zau55qEIE9VVFBVVFNcUkVTVUxULm1k44CBCk9VVFBVVFNcU0NPUEVEX0RJRkYucGF0Y2gg6IiHIE9VVFBVVFNcVEVTVF9SRVNVTFQubWTjgII="
$bytes = [System.Convert]::FromBase64String($base64Text)
$formatString = [System.Text.Encoding]::UTF8.GetString($bytes)
$assembledText = ($formatString -f $resolvedPath) + @"

IMPORTANT:
- Re-read the latest TASK.md, including every Revision section.
- Existing OUTPUTS are not proof of completion.
- If the latest Revision rejects existing artifacts, execute the corrections and overwrite those artifacts.
- Do not report completion unless the output timestamps and contents reflect the latest Revision.
"@



# 5. Copy to clipboard
Set-Clipboard -Value $assembledText

# 6. Windows interaction (pasting/submitting)
$pasted = $false
$submitted = $false
$targetWindowTitle = "N/A (CopyOnly)"

if (-not $CopyOnly) {
    $matchingProcesses = @(Get-Process | Where-Object { $PSItem.MainWindowTitle -and ($PSItem.MainWindowTitle -match $WindowTitlePattern -or $PSItem.Name -match $WindowTitlePattern) })
    if ($matchingProcesses.Count -eq 0) {
        throw "No matching visible window found for pattern '$WindowTitlePattern'."
    }
    if ($matchingProcesses.Count -gt 1) {
        throw "Multiple matching windows found for pattern '$WindowTitlePattern'."
    }
    
    $proc = $matchingProcesses[0]
    $targetWindowTitle = $proc.MainWindowTitle
    
    Add-Type -AssemblyName Microsoft.VisualBasic
    Add-Type -AssemblyName System.Windows.Forms
    
    try {
        [Microsoft.VisualBasic.Interaction]::AppActivate($proc.Id)
        Start-Sleep -Milliseconds 500
        [System.Windows.Forms.SendKeys]::SendWait("^v")
        $pasted = $true
        Start-Sleep -Milliseconds 200
        [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
        $submitted = $true
        Write-Output "Task successfully pasted and submitted to window: $targetWindowTitle"
    } catch {
        throw "AppActivate or SendKeys failed: $_"
    }
} else {
    Write-Output "Task successfully copied to clipboard (CopyOnly)."
}

# 7. Create handoff receipt
$receipt = @{
    dispatch_id = $dispatchId
    task_path = $resolvedPath
    target_window_title = $targetWindowTitle
    handed_off_at = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
    pasted = $pasted
    submitted = $submitted
    models_invoked = $false
    external_services_invoked = $false
    permanent_role_change = $false
}
$receiptJson = ConvertTo-Json $receipt -Depth 5
$receiptDir = Join-Path (Split-Path $resolvedPath) "OUTPUTS"
if (-not (Test-Path -LiteralPath $receiptDir)) {
    New-Item -ItemType Directory -Force -Path $receiptDir | Out-Null
}
$receiptPath = Join-Path $receiptDir "ANTIGRAVITY_HANDOFF.json"
[System.IO.File]::WriteAllText($receiptPath, $receiptJson, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "Handoff receipt created at: $receiptPath"

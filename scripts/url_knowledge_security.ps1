Set-StrictMode -Version Latest

if (-not ("AgentOS.NativePath" -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace AgentOS {
    public static class NativePath {
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern uint GetFinalPathNameByHandle(
            SafeFileHandle hFile,
            StringBuilder lpszFilePath,
            uint cchFilePath,
            uint dwFlags);
    }
}
"@
}

function Get-AgentOSFileSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Resolve-AgentOSPhysicalFilePath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $stream = [IO.File]::Open(
        $Path,
        [IO.FileMode]::Open,
        [IO.FileAccess]::Read,
        [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete
    )
    try {
        $buffer = [Text.StringBuilder]::new(32768)
        $length = [AgentOS.NativePath]::GetFinalPathNameByHandle(
            $stream.SafeFileHandle,
            $buffer,
            $buffer.Capacity,
            0
        )
        if ($length -eq 0 -or $length -ge $buffer.Capacity) {
            throw "Unable to resolve physical path for source_json_path."
        }
        $resolved = $buffer.ToString()
        if ($resolved.StartsWith('\\?\UNC\', [StringComparison]::OrdinalIgnoreCase)) {
            return '\\' + $resolved.Substring(8)
        }
        if ($resolved.StartsWith('\\?\', [StringComparison]::OrdinalIgnoreCase)) {
            return $resolved.Substring(4)
        }
        return $resolved
    } finally {
        $stream.Dispose()
    }
}

function Assert-AgentOSSourceJsonBoundary {
    param(
        [Parameter(Mandatory = $true)][string]$AgentOSRoot,
        [Parameter(Mandatory = $true)][string]$DispatchId,
        [Parameter(Mandatory = $true)][string]$SourceJsonPath
    )
    if ($DispatchId -notmatch '^[A-Za-z0-9_.-]+$') {
        throw "Invalid dispatch_id for URL intake boundary."
    }
    if ($SourceJsonPath -match '(^|[\\/])\.\.([\\/]|$)') {
        throw "source_json_path traversal is not allowed."
    }
    $expectedRoot = [IO.Path]::GetFullPath(
        (Join-Path $AgentOSRoot (Join-Path 'data\url_intake' $DispatchId))
    ).TrimEnd('\', '/')
    $lexicalPath = [IO.Path]::GetFullPath($SourceJsonPath)
    $prefix = $expectedRoot + [IO.Path]::DirectorySeparatorChar
    if (-not $lexicalPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "source_json_path must be inside the dispatch URL intake directory."
    }
    if (-not (Test-Path -LiteralPath $lexicalPath -PathType Leaf)) {
        throw "source_json_path does not exist."
    }
    $physicalPath = Resolve-AgentOSPhysicalFilePath -Path $lexicalPath
    if (-not $physicalPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "source_json_path resolves outside the dispatch URL intake directory."
    }
    return $physicalPath
}

function Get-AgentOSMachineField {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Name
    )
    $matches = [regex]::Matches($Text, "(?m)^$([regex]::Escape($Name)):\s*(.*?)\s*$")
    if ($matches.Count -ne 1) { return $null }
    return $matches[0].Groups[1].Value.Trim()
}

function Test-AgentOSStrictClaudeReview {
    param(
        [Parameter(Mandatory = $true)][string]$Review,
        [Parameter(Mandatory = $true)][string]$DispatchId,
        [Parameter(Mandatory = $true)][string]$ResultSha256
    )
    return (
        (Get-AgentOSMachineField $Review 'review_schema_version') -eq '1' -and
        (Get-AgentOSMachineField $Review 'review_status') -ceq 'PASS' -and
        (Get-AgentOSMachineField $Review 'dispatch_id') -ceq $DispatchId -and
        (Get-AgentOSMachineField $Review 'reviewed_result_sha256') -ceq $ResultSha256 -and
        (Get-AgentOSMachineField $Review 'reviewer_role') -ceq 'Claude Inspector'
    )
}

function Test-AgentOSFreshCodexVerify {
    param(
        [Parameter(Mandatory = $true)][string]$Receipt,
        [Parameter(Mandatory = $true)][string]$DispatchId,
        [Parameter(Mandatory = $true)][string]$ResultSha256
    )
    return (
        (Get-AgentOSMachineField $Receipt 'verify_schema_version') -eq '1' -and
        (Get-AgentOSMachineField $Receipt 'verify_verdict') -ceq 'PASS' -and
        (Get-AgentOSMachineField $Receipt 'verification_mode') -ceq 'fresh_read_only' -and
        (Get-AgentOSMachineField $Receipt 'source_dispatch_id') -ceq $DispatchId -and
        (Get-AgentOSMachineField $Receipt 'verified_result_sha256') -ceq $ResultSha256 -and
        (Get-AgentOSMachineField $Receipt 'verifier_role') -ceq 'Codex Verify'
    )
}

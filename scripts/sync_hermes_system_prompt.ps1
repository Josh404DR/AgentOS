[CmdletBinding()]
param(
    [switch]$Check
)

$ErrorActionPreference = "Stop"

$canonicalPath = Join-Path $PSScriptRoot "..\prompts\context_packs\hermes_system_prompt_v2.txt"
$mirrorPath = Join-Path $PSScriptRoot "..\prompts\context_packs\hermes_system_prompt_v2.md"

$canonicalPath = [IO.Path]::GetFullPath($canonicalPath)
$mirrorPath = [IO.Path]::GetFullPath($mirrorPath)

if (-not (Test-Path -LiteralPath $canonicalPath -PathType Leaf)) {
    throw "Canonical Hermes prompt not found: $canonicalPath"
}

$canonicalBytes = [IO.File]::ReadAllBytes($canonicalPath)
$mirrorExists = Test-Path -LiteralPath $mirrorPath -PathType Leaf
$mirrorBytes = if ($mirrorExists) {
    [IO.File]::ReadAllBytes($mirrorPath)
} else {
    [byte[]]::new(0)
}

$sha256 = [Security.Cryptography.SHA256]::Create()
$canonicalHash = ([BitConverter]::ToString($sha256.ComputeHash($canonicalBytes))).Replace("-", "")
$mirrorHash = if ($mirrorExists) {
    ([BitConverter]::ToString($sha256.ComputeHash($mirrorBytes))).Replace("-", "")
} else {
    ""
}
$sha256.Dispose()

$isSynchronized = $mirrorExists -and
    $canonicalBytes.Length -eq $mirrorBytes.Length -and
    $canonicalHash -ceq $mirrorHash

if ($Check) {
    if (-not $isSynchronized) {
        Write-Error "Hermes prompt mirror is out of sync: $mirrorPath"
        exit 1
    }

    Write-Output "hermes_prompt_sync_status=synchronized"
    Write-Output "canonical_path=$canonicalPath"
    Write-Output "mirror_path=$mirrorPath"
    exit 0
}

if (-not $isSynchronized) {
    [IO.File]::WriteAllBytes($mirrorPath, $canonicalBytes)
}

Write-Output "hermes_prompt_sync_status=synchronized"
Write-Output "canonical_path=$canonicalPath"
Write-Output "mirror_path=$mirrorPath"

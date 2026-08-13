[CmdletBinding()]
param([string]$AgentOSRoot = "E:\AgentOS")

$root = (Resolve-Path -LiteralPath $AgentOSRoot).Path
$failures = @()
Get-ChildItem -LiteralPath $root -Recurse -Filter '*.ps1' -File |
    Where-Object { $_.FullName -notmatch '\\(\.git|node_modules|\.next|\.venv)\\' } |
    ForEach-Object {
        $bytes = [IO.File]::ReadAllBytes($_.FullName)
        $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
        $offset = if ($hasBom) { 3 } else { 0 }
        $hasNonAscii = $false
        for ($index = $offset; $index -lt $bytes.Length; $index++) {
            if ($bytes[$index] -ge 0x80) { $hasNonAscii = $true; break }
        }
        if ($hasNonAscii -and -not $hasBom) {
            $failures += $_.FullName.Substring($root.Length).TrimStart('\')
        }
    }
if ($failures.Count) {
    Write-Output 'powershell_utf8_bom=FAIL'
    $failures | Sort-Object | ForEach-Object { Write-Output "missing_utf8_bom=$_" }
    exit 1
}
Write-Output 'powershell_utf8_bom=PASS'
Write-Output 'non_ascii_ps1_require_utf8_bom=true'

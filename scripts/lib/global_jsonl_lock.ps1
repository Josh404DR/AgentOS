Set-StrictMode -Version Latest

function Get-GlobalJsonlMutexName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$LiteralPath
    )

    $absolutePath = [IO.Path]::GetFullPath($LiteralPath).ToLowerInvariant()
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        $pathBytes = [Text.Encoding]::UTF8.GetBytes($absolutePath)
        $hash = ([BitConverter]::ToString($sha256.ComputeHash($pathBytes))).Replace("-", "")
    } finally {
        $sha256.Dispose()
    }
    return "Global\AgentOS.Jsonl.$hash"
}

function Save-GlobalJsonlPendingAppend {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$LiteralPath,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content
    )

    $stamp = Get-Date -Format "yyyyMMdd-HHmmss-fffffff"
    $pendingPath = "$LiteralPath.pending-$PID-$stamp-$([Guid]::NewGuid().ToString('N')).jsonl"
    $utf8 = [Text.UTF8Encoding]::new($false)
    [IO.File]::WriteAllText($pendingPath, $Content, $utf8)
    return $pendingPath
}

function Invoke-GlobalJsonlLockedAppend {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$LiteralPath,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$PendingContent,
        [Parameter(Mandatory = $true)][scriptblock]$AppendAction,
        [ValidateRange(1, 60000)][int]$TimeoutMilliseconds = 5000,
        [ValidateRange(0, 10)][int]$RetryCount = 2,
        [ValidateRange(0, 5000)][int]$RetryDelayMilliseconds = 100
    )

    $mutexName = Get-GlobalJsonlMutexName -LiteralPath $LiteralPath
    for ($attempt = 0; $attempt -le $RetryCount; $attempt++) {
        $mutex = [Threading.Mutex]::new($false, $mutexName)
        $acquired = $false
        try {
            try {
                $acquired = $mutex.WaitOne($TimeoutMilliseconds)
            } catch [Threading.AbandonedMutexException] {
                $acquired = $true
            }

            if ($acquired) {
                & $AppendAction
                return
            }
        } finally {
            if ($acquired) {
                $mutex.ReleaseMutex()
            }
            $mutex.Dispose()
        }

        if ($attempt -lt $RetryCount -and $RetryDelayMilliseconds -gt 0) {
            Start-Sleep -Milliseconds $RetryDelayMilliseconds
        }
    }

    try {
        $pendingPath = Save-GlobalJsonlPendingAppend -LiteralPath $LiteralPath -Content $PendingContent
    } catch {
        throw [InvalidOperationException]::new(
            "lock_timeout; target_path=$LiteralPath; mutex_name=$mutexName; pending_write_failed=$($_.Exception.Message)",
            $_.Exception
        )
    }
    throw [TimeoutException]::new(
        "lock_timeout; target_path=$LiteralPath; mutex_name=$mutexName; pending_path=$pendingPath"
    )
}

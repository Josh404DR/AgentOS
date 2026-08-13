function Resolve-AgentOSDependencyStatus {
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Status,
        [scriptblock]$OnUnknownStatus
    )

    $normalized = $Status.Trim().ToLowerInvariant() -replace '[\s-]+', '_'
    $waitingAliases = @{
        pending_dependency = 'pending_dependency'
        waiting_dependencies = 'pending_dependency'
        blocked_by_dependency = 'pending_dependency'
        waiting_dependency = 'pending_dependency'
        waiting_on_dependency = 'pending_dependency'
    }
    if ($waitingAliases.ContainsKey($normalized)) {
        return [pscustomobject]@{
            IsWaiting = $true
            IsKnown = $true
            CanonicalStatus = $waitingAliases[$normalized]
            OriginalStatus = $Status
        }
    }

    # These are ordinary queue lifecycle states, not dependency-wait variants.
    $nonWaitingStatuses = @(
        '', 'ready', 'ready_to_route', 'created', 'queued', 'running',
        'completed', 'failed', 'blocked', 'escalation_required',
        'approval_required', 'cancelled', 'canceled'
    )
    $isKnown = $normalized -in $nonWaitingStatuses
    if (-not $isKnown -and $OnUnknownStatus) {
        & $OnUnknownStatus $Status
    }
    return [pscustomobject]@{
        IsWaiting = $false
        IsKnown = $isKnown
        CanonicalStatus = $normalized
        OriginalStatus = $Status
    }
}

function Test-AgentOSDependencyWaitingStatus {
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Status,
        [scriptblock]$OnUnknownStatus
    )
    return (Resolve-AgentOSDependencyStatus -Status $Status -OnUnknownStatus $OnUnknownStatus).IsWaiting
}

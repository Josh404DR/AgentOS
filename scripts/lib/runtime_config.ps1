function Get-AgentOSRuntimeConfig {
    [CmdletBinding()]
    param(
        [string]$AgentOSRoot = "E:\AgentOS",
        [string]$ConfigPath
    )

    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $ConfigPath = Join-Path $AgentOSRoot "config\runtime.local.json"
    }
    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        throw "AgentOS runtime config not found: $ConfigPath"
    }

    try {
        $config = Get-Content -Raw -LiteralPath $ConfigPath -Encoding UTF8 |
            ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "AgentOS runtime config is invalid JSON: $ConfigPath. $($_.Exception.Message)"
    }

    if ([string]::IsNullOrWhiteSpace([string]$config.schema_version)) {
        throw "AgentOS runtime config field is missing or empty: schema_version"
    }
    if ($null -eq $config.hermes) {
        throw "AgentOS runtime config field is missing: hermes"
    }
    $environmentOverrides = @{
        root       = "AGENTOS_HERMES_ROOT"
        executable = "AGENTOS_HERMES_EXECUTABLE"
        python     = "AGENTOS_HERMES_PYTHON"
        state_db   = "AGENTOS_HERMES_STATE_DB"
    }
    foreach ($field in $environmentOverrides.Keys) {
        $environmentValue = [Environment]::GetEnvironmentVariable(
            $environmentOverrides[$field]
        )
        if ($null -ne $environmentValue) {
            $config.hermes.$field = $environmentValue
        }
    }
    foreach ($field in @("root", "executable", "python", "state_db")) {
        $value = [string]$config.hermes.$field
        if ([string]::IsNullOrWhiteSpace($value)) {
            throw "AgentOS runtime config field is missing or empty: hermes.$field"
        }
        $pathRoot = [string][IO.Path]::GetPathRoot($value)
        $isFullyQualified = (
            $pathRoot -match "^[A-Za-z]:[\\/]$" -or
            $pathRoot -match "^[\\/]{2}[^\\/]+[\\/][^\\/]+[\\/]?$"
        )
        if (-not $isFullyQualified) {
            throw "AgentOS runtime config path must be absolute: hermes.$field=$value"
        }
    }
    if (-not (Test-Path -LiteralPath ([string]$config.hermes.root) -PathType Container)) {
        throw "Hermes root not found: $($config.hermes.root)"
    }
    foreach ($field in @("executable", "python")) {
        $value = [string]$config.hermes.$field
        if (-not (Test-Path -LiteralPath $value -PathType Leaf)) {
            throw "Hermes $field not found: $value"
        }
    }
    if (-not (Test-Path -LiteralPath ([string]$config.hermes.state_db) -PathType Leaf)) {
        throw "Hermes state_db not found: $($config.hermes.state_db)"
    }
    return $config
}

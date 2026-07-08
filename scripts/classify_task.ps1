[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$MessageText,
    [switch]$AsJson
)

$riskRules = [ordered]@{
    deletion = '(?i)\b(delete|remove|erase|drop|purge)\b|\u522a\u9664|\u6e05\u9664|\u79fb\u9664|\u92b7\u6bc0'
    production_data = '(?i)\bproduction\b.*\b(database|db|data)\b|\b(database|db)\b.*\b(write|update|delete|drop)\b|\u6b63\u5f0f\u8cc7\u6599\u5eab'
    money = '(?i)\b(payment|billing|subscription|purchase|charge)\b|\u4ed8\u6b3e|\u91d1\u6d41|\u5e33\u55ae|\u8a02\u95b1|\u8cfc\u8cb7|\u6263\u6b3e'
    credentials = '(?i)\b(api[ _-]?key|token|credential|password|oauth)\b|\u6191\u8b49|\u5bc6\u78bc|\u91d1\u9470|(?:\b(change|modify|grant|revoke|elevate|set)\b[^\r\n,.;]{0,24}\bpermissions?\b|\bpermissions?\b[^\r\n,.;]{0,24}\b(change|modify|grant|revoke|elevate|set)\b)|(?:\u4fee\u6539|\u8b8a\u66f4|\u6388\u4e88|\u64a4\u92b7|\u63d0\u5347|\u8a2d\u5b9a)[^\r\n\uff0c\u3002\uff1b;]{0,12}\u6b0a\u9650'
    external_write = '(?i)\b(send|publish|post|upload|deploy|release)\b.*\b(external|client|production|github|notebooklm)\b|\u5c0d\u5916.*(\u5beb\u5165|\u50b3\u9001|\u767c\u5e03|\u4e0a\u50b3)|\u90e8\u7f72|\u516c\u958b\u767c\u4f48'
    security_policy = '(?i)\b(allowlist|blocklist|firewall|access control|security rule)\b|\u5b89\u5168\u898f\u5247|\u767d\u540d\u55ae|\u9ed1\u540d\u55ae|\u5b58\u53d6\u63a7\u5236'
    core_rewrite = '(?i)\b(large|massive|full)\b.*\b(refactor|rewrite)\b|\u5927\u91cf\u91cd\u69cb|\u5168\u9762\u91cd\u5beb'
    outage = '(?i)\b(outage|downtime|service interruption)\b|\u670d\u52d9\u4e2d\u65b7|\u505c\u6a5f'
}

$complexRules = [ordered]@{
    explicit_plan = '(?i)\b(plan|parent task|child task|dependency)\b|\u8a08\u756b|\u7236\u5de5\u55ae|\u5b50\u5de5\u55ae|\u4f9d\u8cf4'
    multi_component = '(?i)\b(frontend|backend|database|api)\b.*\b(frontend|backend|database|api)\b|\u524d\u7aef.*\u5f8c\u7aef|\u5f8c\u7aef.*\u524d\u7aef'
    architecture = '(?i)\b(architecture|workflow|dispatcher|queue|gateway|governance)\b|\u67b6\u69cb|\u5de5\u4f5c\u6d41|\u6d3e\u5de5\u5668|\u4f47\u5217|\u6cbb\u7406'
    multiple_deliverables = '(?i)(\u5efa\u7acb|\u4fee\u6539|\u66f4\u65b0|\u65b0\u589e).*(\u4ee5\u53ca|\u4e26\u4e14|\u540c\u6642).*(\u5efa\u7acb|\u4fee\u6539|\u66f4\u65b0|\u65b0\u589e)'
}

$negationPrefix = '(?i)(?:\u4e0d|\u4e0d\u8981|\u4e0d\u5f97|\u7981\u6b62|\u907f\u514d|\u4e0d\u53ef|\u7121\u9700|\u4e0d\u9700|\u4e0d\u6703|do\s+not|must\s+not|without|never)'
$riskTerm = '(?i)(?:delete|remove|erase|drop|purge|payment|billing|subscription|purchase|charge|api[ _-]?key|token|credential|password|oauth|permissions?|send|publish|post|upload|deploy|release|allowlist|blocklist|firewall|access control|security rule|refactor|rewrite|outage|downtime|\u522a\u9664|\u6e05\u9664|\u79fb\u9664|\u92b7\u6bc0|\u4ed8\u6b3e|\u91d1\u6d41|\u5e33\u55ae|\u8a02\u95b1|\u8cfc\u8cb7|\u6263\u6b3e|\u6191\u8b49|\u5bc6\u78bc|\u6b0a\u9650|\u91d1\u9470|\u5beb\u5165|\u50b3\u9001|\u767c\u5e03|\u4e0a\u50b3|\u90e8\u7f72|\u767d\u540d\u55ae|\u9ed1\u540d\u55ae|\u5b58\u53d6\u63a7\u5236|\u5927\u91cd\u69cb|\u5168\u9762\u91cd\u5beb|\u670d\u52d9\u4e2d\u65b7|\u505c\u6a5f)'
$negatedRiskConstraints = @(
    [regex]::Matches(
        $MessageText,
        "$negationPrefix[^\r\n\uff0c\u3002\uff1b;]{0,24}?$riskTerm"
    ) | ForEach-Object { $_.Value }
)
$riskScanText = [regex]::Replace(
    $MessageText,
    "$negationPrefix[^\r\n\uff0c\u3002\uff1b;]{0,24}?$riskTerm",
    "[NEGATED_RISK_CONSTRAINT]"
)

# A boundary that says a risky action must be escalated if encountered is not
# itself a request to perform that action. Remove only complete, line-scoped
# ESCALATION_QUEUE conditions before evaluating active risk intent.
$conditionalEscalationPattern = '(?im)(?:^|[\r\n])\s*[-*]?\s*(?:(?:\u9047\u5230|\u82e5|\u5982\u679c)|(?:when|if)\b)[^\r\n\u3002\uff1b;]{0,180}?(?:\u624d\s*)?(?:\u9032|\u5beb\u5165|\u8f49\u5165|enter|write\s+to)\s*ESCALATION_QUEUE[^\r\n\u3002\uff1b;]*'
$riskScanText = [regex]::Replace(
    $riskScanText,
    $conditionalEscalationPattern,
    "`n[CONDITIONAL_ESCALATION_BOUNDARY]"
)

$riskHits = @()
foreach ($rule in $riskRules.GetEnumerator()) {
    if ($riskScanText -match $rule.Value) { $riskHits += $rule.Key }
}

$complexHits = @()
foreach ($rule in $complexRules.GetEnumerator()) {
    if ($MessageText -match $rule.Value) { $complexHits += $rule.Key }
}

$unclear = [string]::IsNullOrWhiteSpace($MessageText) -or
    ($MessageText.Trim().Length -lt 4)

$taskType = if ($riskHits.Count -gt 0) {
    "Risky"
} elseif ($unclear) {
    "classification_unclear"
} elseif ($complexHits.Count -gt 0) {
    "Complex"
} else {
    "Simple"
}

$result = [ordered]@{
    task_type = $taskType
    risk_hits = @($riskHits)
    complex_hits = @($complexHits)
    negated_risk_constraints = @($negatedRiskConstraints)
    classifier = "rule_based_v1"
    models_invoked = $false
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 5 -Compress
} else {
    Write-Output "task_type=$taskType"
    Write-Output "risk_hits=$($riskHits -join ',')"
    Write-Output "complex_hits=$($complexHits -join ',')"
    Write-Output "negated_risk_constraints=$($negatedRiskConstraints -join ' | ')"
    Write-Output "classifier=rule_based_v1"
    Write-Output "models_invoked=false"
}

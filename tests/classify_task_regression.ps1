[CmdletBinding()]
param(
    [string]$AgentOSRoot = "E:\AgentOS"
)

$ErrorActionPreference = "Stop"
$classifier = Join-Path $AgentOSRoot "scripts\classify_task.ps1"
$decode = {
    param([string]$Text)
    [regex]::Unescape($Text)
}

$cases = @(
    @{
        Name = "admin_permission_instruction_is_not_credential_mutation"
        Message = & $decode "\u552f\u8b80\u7a3d\u6838 Windows \u555f\u52d5\u72c0\u614b\uff0c\u63d0\u4f9b\u9700\u8981\u7cfb\u7d71\u7ba1\u7406\u54e1\u6b0a\u9650\u7684\u7cbe\u78ba\u547d\u4ee4\uff1b\u4e0d\u8981\u57f7\u884c\u547d\u4ee4\u3002"
        ExpectedType = "Simple"
        ExpectedRiskHits = @()
        ExpectedComplexHitsContain = @()
    },
    @{
        Name = "permission_mutation_is_risky"
        Message = & $decode "\u4fee\u6539\u670d\u52d9\u5e33\u865f\u6b0a\u9650\u4e26\u63d0\u5347\u70ba\u7cfb\u7d71\u7ba1\u7406\u54e1\u3002"
        ExpectedType = "Risky"
        ExpectedRiskHits = @("credentials")
        ExpectedComplexHitsContain = @()
    },
    @{
        Name = "credential_rotation_is_risky"
        Message = "Rotate the API token used by the gateway."
        ExpectedType = "Risky"
        ExpectedRiskHits = @("credentials")
        ExpectedComplexHitsContain = @()
    },
    @{
        Name = "negated_deletion_is_not_risky"
        Message = & $decode "\u6aa2\u67e5\u6a94\u6848\u72c0\u614b\uff0c\u4e0d\u522a\u9664\u4efb\u4f55\u6a94\u6848\u3002"
        ExpectedType = "Simple"
        ExpectedRiskHits = @()
        ExpectedComplexHitsContain = @()
    },
    @{
        Name = "prohibition_header_same_line_is_not_risky"
        Message = & $decode "\u660e\u78ba\u7981\u6b62\uff1a\u5b89\u88dd\u6216\u79fb\u9664\u8edf\u9ad4"
        ExpectedType = "Simple"
        ExpectedRiskHits = @()
        ExpectedComplexHitsContain = @()
    },
    @{
        Name = "prohibition_header_bullet_block_is_not_risky"
        Message = & $decode "\u6211\u6838\u51c6\u6b64 Risky \u5de5\u55ae\u57f7\u884c\u3002\n\u660e\u78ba\u7981\u6b62\uff1a\n- \u5b89\u88dd\u6216\u79fb\u9664\u8edf\u9ad4\n- \u4fee\u6539\u6191\u8b49"
        ExpectedType = "Simple"
        ExpectedRiskHits = @()
        ExpectedComplexHitsContain = @()
    },
    @{
        Name = "prohibition_block_ends_before_active_instruction"
        Message = & $decode "\u660e\u78ba\u7981\u6b62\uff1a\n- \u5b89\u88dd\u6216\u79fb\u9664\u8edf\u9ad4\n\n\u8acb\u90e8\u7f72\u7db2\u7ad9\u4e26\u516c\u958b\u767c\u5e03\u3002"
        ExpectedType = "Risky"
        ExpectedRiskHits = @("external_write")
        ExpectedComplexHitsContain = @()
    },
    @{
        Name = "conditional_escalation_boundary_is_not_active_risk"
        Message = & $decode "AgentOS \u63a7\u5236\u6307\u4ee4\uff1a\u555f\u52d5\u65e2\u6709\u81ea\u4e3b\u5de5\u4f5c\u7522\u7dda\u3002\n- \u9047\u5230\u5916\u90e8\u767c\u5e03\u3001commit\u3001push\u3001\u90e8\u7f72\u6216\u5176\u4ed6 Risky Task \u624d\u9032 ESCALATION_QUEUE\u3002"
        ExpectedType = "Simple"
        ExpectedRiskHits = @()
        ExpectedComplexHitsContain = @()
    },
    @{
        Name = "active_deployment_remains_risky"
        Message = & $decode "\u8acb\u90e8\u7f72\u7db2\u7ad9\u4e26\u516c\u958b\u767c\u5e03\u3002"
        ExpectedType = "Risky"
        ExpectedRiskHits = @("external_write")
        ExpectedComplexHitsContain = @()
    },
    # --- Codex planning intent (ticket-1346 regression) ---
    # All CJK chars encoded as \uXXXX so the source file is ASCII-safe on CP950.
    @{
        Name = "codex_planning_english_is_complex"
        Message = & $decode "\u8acb Codex planning \u9019\u500b\u5de5\u55ae"
        ExpectedType = "Complex"
        ExpectedRiskHits = @()
        ExpectedComplexHitsContain = @("explicit_plan")
    },
    @{
        Name = "codex_guihua_cjk_is_complex"
        Message = & $decode "\u8acb Codex \u898f\u5283 \u9019\u500b\u5de5\u55ae"
        ExpectedType = "Complex"
        ExpectedRiskHits = @()
        ExpectedComplexHitsContain = @("explicit_plan")
    },
    @{
        Name = "jiao_gei_codex_planning_is_complex"
        Message = & $decode "\u4ea4\u7d66 Codex planning \u5de5\u55ae"
        ExpectedType = "Complex"
        ExpectedRiskHits = @()
        ExpectedComplexHitsContain = @("explicit_plan")
    },
    @{
        Name = "rang_codex_guihua_is_complex"
        Message = & $decode "\u8b93 Codex \u898f\u5283 \u9019\u500b\u4efb\u52d9"
        ExpectedType = "Complex"
        ExpectedRiskHits = @()
        ExpectedComplexHitsContain = @("explicit_plan")
    },
    @{
        Name = "ticket_1346_repro_is_complex"
        Message = & $decode "\u8acb\u57f7\u884c Agent OS\u5de5\u55ae:\u8acb\u8b93codex\u5e6b\u6211planning \u9019\u500b\u5de5\u55ae"
        ExpectedType = "Complex"
        ExpectedRiskHits = @()
        ExpectedComplexHitsContain = @("explicit_plan")
    },
    # --- Existing Simple fixture must not regress ---
    @{
        Name = "simple_workspace_task_stays_simple"
        Message = & $decode "\u8acb\u78ba\u8a8d\u76ee\u524d\u7684\u8a18\u9304\u72c0\u614b\u3002"
        ExpectedType = "Simple"
        ExpectedRiskHits = @()
        ExpectedComplexHitsContain = @()
    }
)

$failures = @()
foreach ($case in $cases) {
    $json = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $classifier `
        -MessageText $case.Message -AsJson
    if ($LASTEXITCODE -ne 0) {
        $failures += "$($case.Name): classifier exit code $LASTEXITCODE"
        continue
    }

    $actual = ($json -join "") | ConvertFrom-Json
    $actualRiskHits = @($actual.risk_hits)
    $expectedRiskHits = @($case.ExpectedRiskHits)
    $actualComplexHits = @($actual.complex_hits)
    $expectedComplexContain = @($case.ExpectedComplexHitsContain)

    if ($actual.task_type -ne $case.ExpectedType) {
        $failures += "$($case.Name): expected task_type=$($case.ExpectedType), actual=$($actual.task_type)"
    }
    if (($actualRiskHits -join ",") -ne ($expectedRiskHits -join ",")) {
        $failures += "$($case.Name): expected risk_hits=$($expectedRiskHits -join ','), actual=$($actualRiskHits -join ',')"
    }
    foreach ($hit in $expectedComplexContain) {
        if ($actualComplexHits -notcontains $hit) {
            $failures += "$($case.Name): complex_hits missing '$hit'; actual=$($actualComplexHits -join ',')"
        }
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "classifier_regression_status=passed"
Write-Output "case_count=$($cases.Count)"
Write-Output "complex_hit_check=enabled"

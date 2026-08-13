# 快速驗證：派工層依賴狀態正規化
# 檢查 task_queue_runner.ps1 是否正確處理多種依賴狀態字串

param(
    [string]$AgentOSRoot = "E:\AgentOS"
)

. (Join-Path $AgentOSRoot "scripts\lib\dependency_status.ps1")

# 測試用例：所有已知的依賴字串變體
$testCases = @(
    @{ Input = "pending_dependency"; Expected = "pending_dependency"; Name = "標準" },
    @{ Input = "waiting_dependencies"; Expected = "pending_dependency"; Name = "變體1" },
    @{ Input = "blocked_by_dependency"; Expected = "pending_dependency"; Name = "變體2" },
    @{ Input = "waiting_dependency"; Expected = "pending_dependency"; Name = "變體3" },
    @{ Input = "waiting_on_dependency"; Expected = "pending_dependency"; Name = "變體4" },
    @{ Input = "ready_to_route"; Expected = "ready_to_route"; Name = "就緒" },
)

Write-Output "`n【Exp 1 驗證：依賴狀態正規化】"
Write-Output "========================================`n"

$passed = 0
$failed = 0

foreach ($test in $testCases) {
    $result = Resolve-AgentOSDependencyStatus -Status $test.Input
    $isWaiting = $result.IsWaiting
    $canonical = $result.CanonicalStatus

    if ($test.Expected -eq "pending_dependency") {
        $shouldWait = $true
    } else {
        $shouldWait = $false
    }

    $match = ($isWaiting -eq $shouldWait) -and ($canonical -eq $test.Expected)

    if ($match) {
        Write-Output "✓ PASS: $($test.Name)"
        Write-Output "  Input: '$($test.Input)' → Canonical: '$canonical' (IsWaiting: $isWaiting)`n"
        $passed++
    } else {
        Write-Output "✗ FAIL: $($test.Name)"
        Write-Output "  Input: '$($test.Input)'"
        Write-Output "  Expected: Canonical='$($test.Expected)', IsWaiting=$shouldWait"
        Write-Output "  Actual: Canonical='$canonical', IsWaiting=$isWaiting`n"
        $failed++
    }
}

Write-Output "========================================`n"
Write-Output "結果: $passed 通過, $failed 失敗`n"

if ($failed -eq 0) {
    Write-Output "✓ 結論：派工層依賴狀態正規化已完整實現（dependency_status.ps1）`n"
    exit 0
} else {
    Write-Output "✗ 結論：還有未處理的狀態變體`n"
    exit 1
}

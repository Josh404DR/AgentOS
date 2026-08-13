test_status: passed
test_command: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test_dependency_status_normalization.ps1 -AgentOSRoot E:\AgentOS
exit_code: 0
test_output:
dependency_status_normalization_status=passed
known_variants=5
unknown_status_warning=passed

execution_source: 由 Josh 端具備真實 PowerShell 執行能力的環境（非本 revision 的 Claude Worker session）於 2026-08-10 手動執行取得。

covers: AC2（3 個已知變體單元測試）、AC3（未知字串寫入警告 log）。AC5（Hermes Lite/P-3 實測解卡）尚未執行，待本次 Verify PASS 後另行驗證。

第一次嘗試（此 Claude Worker session 因沙盒限制無法執行 PowerShell，7 種方法皆失敗）的完整記錄已搬移至 `TEST_RESULT_revision-1-attempt1.md`，不影響本次結果。

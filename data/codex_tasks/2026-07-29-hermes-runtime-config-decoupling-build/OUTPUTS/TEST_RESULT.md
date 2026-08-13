# TEST_RESULT — Hermes runtime config decoupling Build

test_status: locally_verified_with_environment_caveats
tested_at: 2026-07-29 Asia/Taipei

## 實測結果

| 檢查 | 指令／方法 | 結果 |
|---|---|---|
| Governance readiness | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\assert_governance_ready.ps1` | PASS；`governance_gate=passed`、`governance_status=operational_review_required`、`task_execution_allowed=true` |
| PowerShell syntax | `[System.Management.Automation.Language.Parser]::ParseFile(...)`，逐一檢查 loader 與 9 支 Scope 內 `.ps1` | PASS；全部 `parse_errors=0` |
| Python syntax | 設定中的 `hermes.python -B -m py_compile dashboard\backend\main.py` | PASS；`exit_code=0` |
| Normal config | repo 外 fixture 呼叫 `Get-AgentOSRuntimeConfig` 讀正式 config | PASS；`actual=pass`、root 正確、`exit_code=0` |
| Missing config | `ConfigPath=C:\tmp\agentos-runtime-config-tests\missing.json` | PASS（預期拒絕）；`AgentOS runtime config not found: ...` |
| Invalid JSON | `ConfigPath=C:\tmp\agentos-runtime-config-tests\invalid-json.json` | PASS（預期拒絕）；`AgentOS runtime config is invalid JSON: ... Invalid JSON primitive` |
| Missing executable | fixture 指向不存在的 `hermes.exe` | PASS（預期拒絕）；`Hermes executable not found: ...` |
| PowerShell BOM policy | `tests\test_powershell_utf8_bom.ps1` | PASS；`repository_scan_passed=true`、`exit_code=0` |
| Dashboard UX contract | `tests\test_dashboard_ux_contract.ps1` | PASS；`dashboard_ux_contract=PASS`、`exit_code=0` |
| Hermes setup smoke | `scripts\setup_hermes.ps1` | PASS；成功載入 config，Hermes v0.14.0，`exit_code=0` |
| Hermes quick smoke | `scripts\test_hermes.ps1` | PARTIAL；version/doctor 均執行且腳本 `exit_code=0`，但 sandbox 網路、`auth.lock` ACL 與 cp950 reader thread 產生警告 |
| Dashboard security suite | `dashboard\backend\.venv\Scripts\python.exe -B tests\test_dashboard_security.py` | PASS；`Ran 17 tests in 6.319s`、`OK`、`exit_code=0` |
| Dashboard import smoke | Dashboard `.venv` 執行 `import main` 並輸出 config-derived paths | PASS；`dashboard_runtime_config=passed`、三個 Hermes 路徑正確、`exit_code=0` |

## Fail-closed 原始關鍵輸出

```text
case=missing_config
actual=fail
error=AgentOS runtime config not found: C:\tmp\agentos-runtime-config-tests\missing.json
exit_code=0

case=invalid_json
actual=fail
error=AgentOS runtime config is invalid JSON: C:\tmp\agentos-runtime-config-tests\invalid-json.json. Invalid JSON primitive: .
exit_code=0

case=missing_executable
actual=fail
error=Hermes executable not found: C:\tmp\agentos-runtime-config-tests\does-not-exist\hermes.exe
exit_code=0
```

Fixture 位於 `C:\tmp\agentos-runtime-config-tests\`，未修改上述三種測試中的正式 config。

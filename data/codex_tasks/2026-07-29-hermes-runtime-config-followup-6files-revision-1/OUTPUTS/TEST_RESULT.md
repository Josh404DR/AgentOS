# TEST_RESULT — A01 follow-up revision-1

dispatch_id: 2026-07-29-hermes-runtime-config-followup-6files-revision-1
tested_at: 2026-07-29T21:20:55.2351975+08:00
builder_test_status: passed

## 實測結果

| 測試 | 實際結果 |
|---|---|
| Governance readiness | PASS；`governance_gate=passed`、`task_execution_allowed=true` |
| 刪除前掃描 | PASS；指定的 3 個 `.pyc` 均為 `exists=True` |
| 刪除後掃描 | PASS；指定的 3 個 `.pyc` 均為 `exists=False` |
| PowerShell parser | PASS；`watchdog.ps1`、`model_fallback.ps1`、`replicate_to_machine2.ps1` 均 `parser_errors=0` |
| Python AST 語法檢查 | PASS；`check_db.py`、`daily_token_cost_summary_noagent.py`、`hermes_usage_audit.py` 均 `ast_parse=PASS`，exit 0；使用 `ast.parse` 避免重新產生 bytecode |
| 舊 Hermes 硬編碼搜尋 | PASS；六個母票來源檔匹配數 0 |
| Python fail-closed | PASS；三個 Python caller 注入不存在的 `AGENTOS_HERMES_STATE_DB` 後均 exit 1，精確原因為 `RuntimeError: Hermes state_db not found: E:\AgentOS\nonexistent-fixture\state.db` |
| 測試後 bytecode 掃描 | PASS；指定的 3 個 `.pyc` 仍均為 `exists=False` |
| 母票六檔 hash 穩定性 | PASS；刪除前後 SHA-256 完全相同 |

## 母票六檔 SHA-256

- `dashboard\backend\check_db.py`: `BB452F73CB7181348D3D3BE530EEACBC203276F7E64FE5E7C3CCCB84000CD13D`
- `scripts\watchdog.ps1`: `910A0F2C03D782BFC22A85056EFD2229862F0B60F5A4D95316EA61B99B99B328`
- `scripts\model_fallback.ps1`: `4BDEAA86A24EAF06F2BEAA7DF2D63EE152318DA15D93AB9C7B2921062098F2A9`
- `scripts\replicate_to_machine2.ps1`: `4207EF185AA375B20DE9B08C65143785FE5A010919AD16D89C49B6ABFE72BF00`
- `scripts\daily_token_cost_summary_noagent.py`: `DC46B145753916000AE13A4589CD8A640B58381991E0A30B145399060C2DCDAB`
- `scripts\hermes_usage_audit.py`: `754776FF6E3F83C423AED443DF07D60A5FED001D46B9B00E6BB5C0B3EE7E5E37`

## 掃描說明

兩個 `__pycache__` 目錄仍有其他先前存在、不同版本或不同模組的 `.pyc`；本工單只獲核准刪除明列的三個檔案，未碰觸其他 cache。


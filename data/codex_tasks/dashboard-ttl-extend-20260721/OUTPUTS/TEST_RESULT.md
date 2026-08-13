# Test Result

dispatch_id: dashboard-ttl-extend-20260721
builder_self_check: PASS
independent_verify_status: PASS
verified: true

## Commands and Results

1. 修改前快照與目前 security 檔逐行比較：PASS，`security_exact_changed_lines=2`。
2. `python -B -m unittest tests.test_dashboard_security`：`Ran 16 tests ... OK`。
3. `python -B -m py_compile dashboard\backend\dashboard_security.py tests\test_dashboard_security.py`：PASS。

## Covered Contracts

- 新 security instance `start()` 後，token file 的動態 `expires_at` 距發行時間為 43200 秒（±2 秒）。
- `login()` 回傳 session context 的 `expires_at` 距登入時間為 14400 秒（±2 秒）。
- `AGENTOS_DASHBOARD_TOKEN_TTL_SECONDS=1234` 與 `AGENTOS_DASHBOARD_SESSION_TTL_SECONDS=5678` 覆寫成功。
- 未登入、錯誤／過期 token、Origin、CSRF、非 owner、ACL、receipt、legacy resolution、mutation flag、mojibake note 等既有測試仍 PASS。
- 過期訊息測試仍確認 HTTP 403、`Owner token 已過期`、`expires_at=` 與重啟指引。

Builder self-check 另由 fresh read-only Codex Verify 獨立重跑並出具 PASS。

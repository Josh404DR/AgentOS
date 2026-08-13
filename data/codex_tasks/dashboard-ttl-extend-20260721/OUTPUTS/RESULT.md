# Dashboard TTL Extend Result

dispatch_id: dashboard-ttl-extend-20260721
task_status: verified_complete
builder_self_check: PASS
verified: true
verify_level: full_blind_verify(Phase 0 security redline)
governance_version: 1.3.0
governance_hash: 0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1

## 實際變更

- `dashboard\backend\dashboard_security.py`：
  - `AGENTOS_DASHBOARD_TOKEN_TTL_SECONDS` 預設 `3600 → 43200`。
  - `AGENTOS_DASHBOARD_SESSION_TTL_SECONDS` 預設 `1800 → 14400`。
- `tests\test_dashboard_security.py`：更新預設值期望，新增實際 token/session window 與 env override 測試；既有安全測試未刪除。

UI 與過期提示未寫死舊 TTL；`main.py` 會從 token file 動態讀取並顯示 `expires_at`，故本單沒有修改前端或 `main.py`。

## Security Exact-diff Evidence

- 修改前 `dashboard_security.py` SHA-256：`7EE61C83964DD3662995B89D057E6EBA01E6ACE1A14C6C354683E8BA26E8BD44`
- 修改後 SHA-256：`8D0B66CD5579C0964C92A5716669F67F226C3B498F96277D5844804CFD9A0CBD`
- 逐行比較結果：`security_exact_changed_lines=2`，只有第 62、63 行的四個數值文字不同。

## Builder Self-check

- Phase 0 security suite：16 tests PASS。
- Python compile：PASS。
- token runtime window 測試：43200 秒（允許 2 秒執行誤差）。
- session runtime window 測試：14400 秒（允許 2 秒執行誤差）。
- env override：token=1234、session=5678，皆優先於預設值。

## 驗證狀態

- fresh read-only Codex Verify 已出具 PASS；詳見 `VERIFY_RESULT.md`。
- governance 狀態仍為 `operational_review_required`。

# Test Result

dispatch_id: dashboard-ux-papercuts-20260721
self_check_status: PASS
verified: false
retry_rounds: 0

## 測試結果

1. PowerShell scoped AST parse：PASS。
2. `tests\test_dashboard_ux_contract.ps1`：PASS；ApprovalQueue import/render、未登入提示、decision endpoint、token path／重啟指引、reclaim switch、UTF-8 文件契約全成立。
3. `tests\test_dashboard_orphan_guard.ps1`：PASS；workspace backend/frontend 接受，foreign process 拒絕；模擬 PID 4242 孤兒輸出 PID／process／started_at／手動指令，`-ReclaimOrphans` fail-closed。
4. `tests\test_powershell_utf8_bom.ps1`：PASS；外部 temp 無 BOM 中文 fixture 被拒並列 `missing_utf8_bom=bad.ps1`，repo scan PASS。
5. `python -B -m unittest tests.test_dashboard_security`：15 tests PASS；過期／錯誤 token 均為 403 且訊息區分、預設 TTL 3600、亂碼 note 400、正常中文 note 完整傳入 decision script、測試 escalation 由 `/api/approvals` 可見。
6. `python -B -m unittest tests.test_dashboard_security tests.test_knowledge_workspace`：34 tests PASS。
7. `tests\test_escalation_decision_hardening.ps1`：PASS；receipt、queue、歷史 hash regression 均通過。
8. `npm.cmd run build`：PASS；Next.js production build、TypeScript、4/4 static pages 完成。

## BOM 修復證據

- 初始掃描 33 個既有違規檔；加入本單測試後共 35 個檔案補 BOM。
- 每個檔案寫入後逐 byte 驗證：新檔內容必須等於原內容前置三 bytes `EF BB BF`。
- 最終輸出：`powershell_utf8_bom=PASS`、`repository_scan_passed=true`。

## Caveat

- 未執行整套 live CI smoke，避免觸發範圍外 model CLI／runtime 外部狀態；工單指定的既有 suites 與 frontend build 已實跑。

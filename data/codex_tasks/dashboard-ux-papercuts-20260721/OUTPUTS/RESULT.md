# Dashboard UX Papercuts Result

dispatch_id: dashboard-ux-papercuts-20260721
task_status: completed_self_check
self_check_status: PASS
verified: false
verify_level: self_check_only
governance_version: 1.3.0
governance_hash: 0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1

## 實際變更

- 將 `ApprovalQueue` 掛到首頁「今日」頁右側；未登入顯示「需登入才能決策」，按鈕仍呼叫既有 `/api/approvals/{id}/decision`。
- owner token 預設 TTL 由 600 秒調整為 3600 秒，保留 `AGENTOS_DASHBOARD_TOKEN_TTL_SECONDS` 設定能力；403 登入錯誤分成 token 過期（含 `expires_at` 與重啟指引）及 token 錯誤。
- `dashboard\start.ps1` 新增 `-ReclaimOrphans`。無可信 receipt 的 port owner 會顯示 PID、process、啟動時間、command line 與處置指令；只有 executable 與 command line 均綁定本 workspace 的 uvicorn／Next.js 才可接管。
- decision endpoint 在簽發 receipt 前拒絕全問號或含 `U+FFFD` 的 note，回 HTTP 400；新增 PowerShell 5.1 UTF-8 API 範例文件。
- CI 新增全 repo `.ps1` UTF-8 BOM gate 與 fault injection；35 個既有／本單新增的違規檔只增加 `EF BB BF`，內容 bytes 不變。

## Artifact

- `E:\AgentOS\data\codex_tasks\dashboard-ux-papercuts-20260721\OUTPUTS\RESULT.md`
- `E:\AgentOS\data\codex_tasks\dashboard-ux-papercuts-20260721\OUTPUTS\TEST_RESULT.md`
- `E:\AgentOS\data\codex_tasks\dashboard-ux-papercuts-20260721\OUTPUTS\SELF_CHECK.md`
- `E:\AgentOS\docs\DASHBOARD_API_POWERSHELL_UTF8.md`

## 未解風險

- workspace 原本即有大量不相關 dirty／untracked 內容；本單未整理、回滾、stage、commit 或 push。
- `dashboard` 目前在 Git 狀態中屬 untracked，無法直接以 repository baseline 產生其歷史 diff；紅線稽核改用啟動時證據、精確 scoped patch、hash 與重建的 TTL 單行 no-index diff。
- governance 仍為 `operational_review_required`，不得宣稱整體 workspace production-ready。

## 下一步

- 依工單 `self_check_only` 結案；本結果未標記為 verified。

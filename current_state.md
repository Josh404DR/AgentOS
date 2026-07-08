# AgentOS Current State

updated_at: 2026-07-05 Asia/Taipei
governance_version: 1.2.0
evidence_policy: fresh_local_evidence

## 1. Source of Truth
- E:\AgentOS\AGENTS.md (治理正本)
- E:\AgentOS\current_state.md (現況正本)
- data\codex_tasks\<dispatch_id>\TASK.md / OUTPUTS\RESULT.md (工單與交付)
- data\governance\governance_status.json (實時治理狀態)
- data\metrics\METRICS_LOG.jsonl (指標日誌；**W10 注意：目前僅 5 筆，token/duration 全為 unknown，不可作為效能依據**)
- data\escalations\ESCALATION_INDEX.jsonl + RESOLUTION.json (人工決策索引與決議)

## 2. Current Governance
- 實時狀態：修改本檔案會導致與基線 (governance_baseline.json) 雜湊不符而產生 drift。
- 修改前狀態：assert_governance_ready.ps1 回報 governance_gate=passed, governance_status=aligned。
- 修改後狀態：預期產生 drift，未核准基線前屬 review_required。注意：aligned 不代表內容百分之百正確。

## 3. Current Roles
永久角色：
- Josh：唯一治理 Owner
- Hermes：收件、分類、派工、回報（不擔任實作者）
- Claude：預設 workspace 實作者與修正者
- Codex Plan：Complex Task 拆解父/子工單與依賴
- Codex Verify：以全新/唯讀 session 進行獨立盲審（不接收 Plan 過程與聊天歷史）
- Queue (task_queue_runner.ps1)：負責依賴排程、執行與 verdict 解析等確定性工作，無 AI 決策權

臨時狀態：
- 2026-07-06 已成功將 Antigravity CLI 串接至 Workflow 流程作為 Subagent。在 `scripts\task_queue_runner.ps1` 與 `scripts\dispatch_task_packet.ps1` 中完成對 `"Antigravity CLI"` 的路由及防蓋寫 `RESULT.md` 機作，支援自動與顯式調用。
- 2026-07-06（同日更新）Josh 回報已在四個 Windows 本機帳號分別完成 Antigravity CLI 安裝與登入測試，並以 `whoami` 逐一核實帳號名稱：`brian`（主使用者，host LAPTOP-IMPR60B8，Google 帳號 `ga524362`，目前方案 `pro`，Josh 表示之後不續約會變 `free`）→ alias `pro`；`quide0120`（`free`）→ alias `free-a`；`jamie20260521`（`free`）→ alias `free-b`；`pkg05`（`pro`）→ alias `free-c`（alias 名稱僅為識別用途，不代表實際方案）。`config\antigravity_subagents.json` 四個 worker 皆已 `enabled: true` 並填入上述真實帳號名稱。
- **已知未解阻塞（執行前必讀）**：
  1. `data\governance\governance_status.json` 目前為 `governance_status: review_required`，`drift_count: 3`（`current_state.md`、`scripts\dispatch_task_packet.ps1`、`scripts\task_queue_runner.ps1` hash_changed）。`invoke_antigravity_subagent.ps1` 與 `dispatch_task_packet.ps1` 皆要求 `assert_governance_ready.ps1` 回報 `governance_status=aligned` 才會執行，目前會 fail-closed 中止。需 Josh 核准後執行 `sync_shared_governance.ps1 -ApproveBaseline` 才能解除。
  2. `invoke_antigravity_subagent.ps1`（第73-76行）要求執行當下的 Windows 使用者必須等於該 worker 的 `windows_user`（例如 `AgentOS-Free-A`），且 `fallback_policy.automatic_account_rotation=false`。目前沒有跨帳號自動觸發機制；`task_queue_runner.ps1`/`dispatch_task_packet.ps1` 若在單一（如 Josh 主帳號）session 下執行，會在嘗試呼叫其他帳號 worker 時因使用者不符而 throw。實際派工仍需在對應 Windows 使用者的 session 內觸發，或由 Josh 決定是否建立每帳號的排程/憑證機制（涉及憑證儲存，需 Josh 明確核准）。

## 4. Workflow Status
- 1183、1186、1203 escalation 已有 RESOLUTION.json，josh_action_required=false。
- 最近一次本地觀察：1189、1197、1199、1201、1203 為 completed / PASS。
- 本次更新時 Dashboard API 無法連線，因此未重新確認 live 狀態。
- 注意：ESCALATION_INDEX 中的歷史 awaiting_josh 項目部分屬測試/Fixture，不得誤判為當前 unresolved。

## 5. Repository Structure Status
- Phase 2A 靜態檔案整理：ddg_results.html, page_source.html, upwork_utf8.html, test_threads.png, threads_images, NotebookLM_Necessity_Report.md 已移至 scratch/captures、assets 或 docs/reports。
- P0-02 網路/Threads 工具：get_ip.ps1, get_tailscale_ip.ps1, tailscale_login.ps1, clone_threads.bat 已移至 tools\network\ 或 tools\threads\。
- tools\upwork\scrape_upwork.py 修正：page_source.html 輸出路徑已修正為 scratch\captures\page_source.html，避免污染根目錄。
- P1-02 專案/作品集整理：六個專案目錄 (data-quality-audit-toolkit, ecommerce-market-intelligence-dashboard, ecommerce-operations-automation-pipeline, josh-resume, josh-resume-portfolio-update, staging_site) 已完整保留 nested git metadata 並移入 projects/ 下。
- HERMES_NOTES.md 整理：已移至 data\memory\HERMES_NOTES.md，該檔案仍從屬並受控於 AGENTS.md，非唯一治理正本。

## 6. Current Blockers
- Josh 回報 Claude／Codex 額度目前受限；這是 owner-provided status，不是本機命令驗證。
- py --list 可看到 Python 3.13 註冊，但 py -3.13 實際啟動失敗，指向缺失的 WindowsApps 執行檔；Python launcher 狀態為 broken。

## 7. Immediate Priority

> 重排於 2026-07-08（依據稽核報告 W35）。收入優先，系統優化凍結。

1. **作品集發布**：三個 projects/ 推上公開 GitHub（README 已補 Quick Demo），Python launcher 修復後立即執行。
2. **提案發送**：人工瀏覽案源（104 外包網/PRO360/Tasker/FB 社團），用 data/proposals/template-apps-script-automation.md 改寫，目標 10 份/週。
3. **其餘凍結**：Antigravity、Noteb
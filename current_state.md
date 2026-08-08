# AgentOS Current State

updated_at: 2026-07-20 Asia/Taipei
governance_version: 1.3.0
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
  1. ~~governance drift~~ **已解（2026-07-11）**：`governance_status.json` 於 2026-07-11 02:00 實測為 `aligned`、`drift_count: 0`。以下為歷史紀錄：曾為 `governance_status: review_required`，`drift_count: 3`（`current_state.md`、`scripts\dispatch_task_packet.ps1`、`scripts\task_queue_runner.ps1` hash_changed）。`invoke_antigravity_subagent.ps1` 與 `dispatch_task_packet.ps1` 皆要求 `assert_governance_ready.ps1` 回報 `governance_status=aligned` 才會執行，目前會 fail-closed 中止。需 Josh 核准後執行 `sync_shared_governance.ps1 -ApproveBaseline` 才能解除。
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
- **2026-07-11 Clean Repo / CI/CD / Observability（Phase 0-8）**：Phase 0-8 實作已由 PR #1 squash merge 至 GitHub `master`，merge commit `d0b90dd3bda653da430584e0065830951a6bc4fc`。completion-hardening、audit/cutover 草案與 `.venv` symlink ignore 均已納入；獨立 PR #2 的 PostCSS 8.5.15 修補與 Node24 GitHub Actions 升版先 squash merge 至 release branch，再隨 PR #1 進入 master。master post-merge CI Core `29157937865`、Dashboard `29157937899`、Security `29157937876` 與 dependency graph `29157939725` 全部 Success；Dependabot alert #1 已標記 `fixed`。剩餘驗收為明日 machine-2 acceptance drill；live `E:\AgentOS` cutover 仍須另行核准並依 `docs\roadmap\AGENTOS_LIVE_TREE_CUTOVER_PLAN.md` 執行，目前未切換。

## 6. Current Blockers
- Josh 回報 Claude／Codex 額度目前受限；這是 owner-provided status，不是本機命令驗證。2026-07-11 Codex 於 completion-hardening commit 前實際耗盡額度（有中斷證據）。
- py --list 可看到 Python 3.13 註冊，但 py -3.13 實際啟動失敗，指向缺失的 WindowsApps 執行檔；Python launcher 狀態為 broken。

## 7. Immediate Priority

> **2026-07-20 更新（修正 07-13 版凍結範圍，其餘不變）**：Josh 裁決
> 知識平台（Telegram × Dashboard 知識工作平台計畫）Phase 0/1 可與
> 量化路線**並行**，見 `docs\decisions\ADR-0011-parallel-knowledge-platform.md`
> （含回頭條件：量化路線因搶資源停滯超過一週 → 知識平台讓路）。
> 首張工單：`knowledge-workspace-phase0-security-20260720`（Phase 0
> 安全地基）。Phase 2/3 仍未授權。量化路線仍為主線，順序不變。
>
> ---
>
> **2026-07-13 更新（取代下方 07-08 版）**：Josh 於對話中核准「先量化再優化」路線，
> 見 `docs\plans\2026-07-13-計畫總覽-給Josh.md`（人話版）與
> `docs\plans\2026-07-12-result-chain-optimization.md`（技術版）。
> 順序：裝儀表板（8 個健康數字）→ 修假失敗（編碼／格式守門員）→
> 查詢分流 → 自動學教訓 → 跑 50~100 張工單驗證數字。
> 地圖（戰略地圖／ADR-0009 roadmap 議會迴圈）與議會功能**先凍結**，
> 等 metrics baseline 出來再議——對應 ADR-0010（收斂優先於擴張）。
> 下方 07-08 版「收入優先、系統優化全凍結」與本次核准的方向不一致，
> 保留作歷史紀錄，執行以本次（07-13）為準。
>
> ---
>
> 07-08 版（重排於 2026-07-08，依據稽核報告 W35。收入優先，系統優化凍結）：

1. **作品集發布**：三個 projects/ 推上公開 GitHub（README 已補 Quick Demo），Python launcher 修復後立即執行。
2. **提案發送**：人工瀏覽案源（104 外包網/PRO360/Tasker/FB 社團），用 data/proposals/template-apps-script-automation.md 改寫，目標 10 份/週。
3. **其餘凍結**：Antigravity、NotebookLM、dashboard 新功能、治理擴建、知識鏈——一律凍結至第一筆收入後再議。

## 8. Verify 分級規則（2026-07-08，W05 修正）

盲審（Blind Verify）耗費大量額度，僅在必要時啟用：

| 任務類型 | 驗證方式 |
|---|---|
| 客戶交付物（提案、報告、腳本） | 完整 Blind Verify（反重力 CLI 或 Claude 獨立 session） |
| 核心腳本修改（queue/dispatcher/AGENTS.md） | 完整 Blind Verify |
| 內部分析、文件更新、銷售資產 | Self-check checklist（標記 verify_level: self_check_only） |
| 純唯讀查詢、狀態回報 | 不需驗證 |

單次失敗不得建立 Blind Verify 迴圈；self_check_only 結果不得標記為 verified。

## 9. Quick Handoff
新 IDE 快速接手閱讀順序（拒絕注入完整 progress_log.md 消耗 token）：
1. E:\AgentOS\AGENTS.md
2. E:\AgentOS\current_state.md
3. 具體待執行的 data\codex_tasks\<task_id>\TASK.md

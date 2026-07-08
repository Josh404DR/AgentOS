# AgentOS Documentation Index

本索引將 `E:\AgentOS` 的關鍵文檔、說明與歷史報告進行分類，以便團隊與新 session 的 AI 能快速找到正本、目前狀態與維運手冊。

---

## 1. 治理正本 (Governance Canonicals)

本類別為專案最高權威規章與合約，定義了權限、安全邊界與執行限制。

*   **[`AGENTS.md`](file:///E:/AgentOS/AGENTS.md)** `[canonical]`
    *   **說明**：專案共同治理正本。規定了 Josh 的唯一 owner 權限、三方角色分工（Hermes 協調/派工、Claude 主要實作者、Codex Verify 盲審）、安全警語（不擅自 commit/push/install）、握手協議以及跨視窗同步規範。
*   **[`docs\governance\RISK_RULES.md`](file:///E:/AgentOS/docs/governance/RISK_RULES.md)** `[canonical]`
    *   **說明**：定義了 Risky 任務的判定條件（如涉及 credentials, external_write, deletion），此類任務會被 Rule-based Classifier 攔截並進入 Escalation。
*   **[`docs\governance\WORKFLOW_V1_2_CONTRACT.md`](file:///E:/AgentOS/docs/governance/WORKFLOW_V1_2_CONTRACT.md)** `[canonical]`
    *   **說明**：Workflow v1.2 的核心工作流合約，定義了 Simple、Complex、Risky、classification_unclear 任務類型與重試（最多 2 輪）及驗收判定等級（PASS/FAIL/NEEDS_HUMAN_DECISION）。

---

## 2. 當前狀態 (Current Status & Live State)

反映系統或佇列的當下實際狀態、CI 門檻以及執行日誌。

*   **[`data\governance\governance_status.json`](file:///E:/AgentOS/data/governance/governance_status.json)** `[operational]`
    *   **說明**：實時治理 Gate 狀態檔。記錄當前是否 aligned、governance_version、基準 hash 以及任何未授權的 drift。
*   **[`data\governance\governance_baseline.json`](file:///E:/AgentOS/data/governance/governance_baseline.json)** `[operational]`
    *   **說明**：受管轄檔案的最新核准 Hash 基準列表。
*   **[`data\metrics\METRICS_LOG.jsonl`](file:///E:/AgentOS/data/metrics/METRICS_LOG.jsonl)** `[operational]`
    *   **說明**：佇列任務執行指標，記錄 task_id、實作者、審查者、實際 token 消耗與執行耗時；當 token 或 duration 無法取得時記為 unknown。
*   **[`data\escalations\ESCALATION_INDEX.jsonl`](file:///E:/AgentOS/data/escalations/ESCALATION_INDEX.jsonl)** `[operational]`
    *   **說明**：儲存所有 `awaiting_josh` 的真實工單與測試 Fixture 之升級佇列索引。
*   **[`current_state.md`](file:///E:/AgentOS/current_state.md)** `[operational]`
    *   **說明**：專案當前狀態正本，記述即時的治理、角色、工單狀態、優先順序與 Handoff 順序。

---

## 3. 架構與操作 (Architecture & Operations)

> **注意（2026-07-08）**：以下文件中標記 `status: planned-not-implemented` 的項目，表示文件描述的功能尚未實作，僅為規劃文件，不代表系統現有行為。
>
> - `docs/24H_STABILITY_MONITOR_PLAN.md` — status: planned-not-implemented
> - `docs/EVIDENCE_HYGIENE_PLAN.md` — status: planned-not-implemented
> - `docs/FREE_CLOUD_WINDOW_POLICY.md` — status: planned-not-implemented
> - `docs/MEMORY_ARCHITECTURE.md` — status: planned-not-implemented（L3 RAG 層未實作）
> - `docs/REPOSITORY_STRUCTURE_PLAN.md` — status: planned-not-implemented
> - `docs/PRE_FLIGHT_TEST_PLAN.md` — status: planned-not-implemented

指導專案架構、模型路由以及腳本操作的說明文檔。

*   **[`README.md`](file:///E:/AgentOS/README.md)** `[operational]`
    *   **說明**：專案概覽與基本啟動流程。角色描述已於 2026-07-05 對齊 `AGENTS.md`。
*   **[`docs\ARCHITECTURE.md`](file:///E:/AgentOS/docs/ARCHITECTURE.md)** `[operational]`
    *   **說明**：系統架構與各模組現況清單。角色描述已於 2026-07-05 對齊 `AGENTS.md`。
*   **[`docs\MEMORY_ARCHITECTURE.md`](file:///E:/AgentOS/docs/MEMORY_ARCHITECTURE.md)** `[operational]`
    *   **說明**：系統的 3-Layer 記憶模型說明（L1- red-lines, L2- Markdown Truth, L3- NotebookLM）。
*   **[`docs\COST_SAVING_ROUTING_PROTOCOL.md`](file:///E:/AgentOS/docs/COST_SAVING_ROUTING_PROTOCOL.md)** `[operational]`
    *   **說明**：定義 Token 費用控制與 Lite 模式的路由指南。
*   **[`docs\EVIDENCE_AND_REPORTING_CONTRACT.md`](file:///E:/AgentOS/docs/EVIDENCE_AND_REPORTING_CONTRACT.md)** `[operational]`
    *   **說明**：交付證據格式與權威狀態標籤的命名規範。
*   **[`docs\AGENT_ROUTING_PLAN.md`](file:///E:/AgentOS/docs/AGENT_ROUTING_PLAN.md)** `[operational]`
    *   **說明**：本機與訂閱 AI 資源的定價及協同路由規劃。
*   **[`docs\TELEGRAM_TYPED_DISPATCH_HANDOFF.md`](file:///E:/AgentOS/docs/TELEGRAM_TYPED_DISPATCH_HANDOFF.md)** `[operational]`
    *   **說明**：記述 Telegram hook 運作與顯式 `[TYPE:...]` 指令的手冊。
*   **[`docs\NOTEBOOKLM_CONVEYOR.md`](file:///E:/AgentOS/docs/NOTEBOOKLM_CONVEYOR.md)** `[operational]`
    *   **說明**：NotebookLM Conveyor 傳送帶備份機制的每週操作說明。
*   **[`docs\THREADS_URL_INTAKE.md`](file:///E:/AgentOS/docs/THREADS_URL_INTAKE.md)** `[operational]`
    *   **說明**：Threads 鏈接自動擷取與分析流程說明。
*   **[`docs\PRE_FLIGHT_TEST_PLAN.md`](file:///E:/AgentOS/docs/PRE_FLIGHT_TEST_PLAN.md)** `[operational]`
    *   **說明**：多模型連接與 CLI Bridge 的測試計畫。
*   **[`docs\RESOURCE_INVENTORY.md`](file:///E:/AgentOS/docs/RESOURCE_INVENTORY.md)** `[operational]`
    *   **說明**：本機運作中 CLI 工具版本與訂閱額度清單。
*   **[`docs\SETUP_STATUS.md`](file:///E:/AgentOS/docs/SETUP_STATUS.md)** `[operational / review_required]`
    *   **說明**：記述 Hermes 代理環境設定與 proxy block 的排除指引。
*   **[`agents\roles\`](file:///E:/AgentOS/agents/roles/) 目錄下的 `hermes.md` / `codex.md` / `gemini.md` / `claude.md`** `[operational]`
    *   **說明**：各角色的功能定位與 ZH-TW 指引（補充用，從屬於 `AGENTS.md`）。
*   **常用腳本維運操作**：
    *   `powershell -File scripts\assert_governance_ready.ps1`：一鍵校對治理基線雜湊，檢測 drift。
    *   `powershell -File scripts\sync_shared_governance.ps1 -ApproveBaseline`：Josh 核准變更後，更新並覆蓋 baseline。
    *   `powershell -File scripts\task_queue_runner.ps1`：執行佇列中的任務封包。

---

## 4. 工單與交付 (Tickets & Deliveries)

佇列分發、歷史執行工單以及接案交付路徑中的核心產出。

*   **`data\codex_tasks\<dispatch_id>\` 目錄** `[operational]`
    *   **[`TASK.md`](file:///E:/AgentOS/data/codex_tasks/)**：定義具體工單目標、驗收條件與依賴關係。
    *   **`OUTPUTS\RESULT.md`**：交付成果的合約檔案（包含 findings 與 status 等）。
    *   **`OUTPUTS\SCOPED_DIFF.patch`**：工單所修改程式碼的實際 Patch。
    *   **`OUTPUTS\TEST_RESULT.md`**：本機測試通過的指令與日誌證據。
*   **`data\leads\`** `[operational]`
    *   **說明**：接案前置 lead 分析檔案（如 `2026-06-24.md`），目前因 cloudflare 阻擋處於 pending_review。
*   **`data\proposals\`** `[operational]`
    *   **說明**：提案草案，目前僅有 mock/template，待真實 leads 驅動。

---

## 5. 作品與專案 (Projects)

Josh 的接案作品與開發專案，已完整收納於 projects\ 子目錄下。

*   **[`projects\data-quality-audit-toolkit\`](file:///E:/AgentOS/projects/data-quality-audit-toolkit/)** `[operational]`
    *   **說明**：數據品質審計工具套件。包含獨立 `.git` 及未追蹤之 `assets\`。
*   **[`projects\ecommerce-market-intelligence-dashboard\`](file:///E:/AgentOS/projects/ecommerce-market-intelligence-dashboard/)** `[operational]`
    *   **說明**：電商市場情報儀表板。包含獨立 `.git`。
*   **[`projects\ecommerce-operations-automation-pipeline\`](file:///E:/AgentOS/projects/ecommerce-operations-automation-pipeline/)** `[operational]`
    *   **說明**：電商營運自動化管道。包含獨立 `.git`。
*   **[`projects\josh-resume\`](file:///E:/AgentOS/projects/josh-resume/)** `[operational]`
    *   **說明**：Josh 個人履歷專案。包含獨立 `.git`。
*   **[`projects\josh-resume-portfolio-update\`](file:///E:/AgentOS/projects/josh-resume-portfolio-update/)** `[operational]`
    *   **說明**：Josh 履歷作品集更新檔。無獨立 `.git`。
*   **[`projects\staging_site\`](file:///E:/AgentOS/projects/staging_site/)** `[operational]`
    *   **說明**：Staging 測試站點目錄（目前為空）。無獨立 `.git`。

---

## 6. 歷史與報告 (Historical Reports)

append-only 專案歷史、指標備份與測評報告。

*   **[`progress_log.md`](file:///E:/AgentOS/progress_log.md)** `[historical]`
    *   **說明**：append-only 專案開發里程碑日誌。
*   **[`archive\Cursor_use\PROJECT_HEALTH_REPORT_UPDATED.md`](file:///E:/AgentOS/archive/Cursor_use/PROJECT_HEALTH_REPORT_UPDATED.md)** `[historical]`
    *   **說明**：2026-07-05 最新寫入的專案健康度與變現評估報告。
*   **`archive\Cursor_use\` 中的 [`PROJECT_ANALYSIS.md`](file:///E:/AgentOS/archive/Cursor_use/PROJECT_ANALYSIS.md) 與 [`RECOMMENDATIONS.md`](file:///E:/AgentOS/archive/Cursor_use/RECOMMENDATIONS.md)** `[historical / review_required]`
    *   **說明**：2026-06-26 報告，過期 8 天以上，需由 Cursor 重新同步。
*   **[`archive\scripts\restart_dashboard_legacy.ps1`](file:///E:/AgentOS/archive/scripts/restart_dashboard_legacy.ps1)** `[historical / unsafe]`
    *   **說明**：舊版儀表板重啟腳本。歷史存檔，不安全。
*   **[`archive\scripts\temp_commit_legacy.sh`](file:///E:/AgentOS/archive/scripts/temp_commit_legacy.sh)** `[historical / do_not_execute]`
    *   **說明**：舊版暫存提交 shell 腳本。歷史存檔，請勿執行。
*   **[`docs\guides\HERMES_STARTUP.md`](file:///E:/AgentOS/docs/guides/HERMES_STARTUP.md)** `[review_required]`
    *   **說明**：Hermes 啟動操作指南。內容包含過時之舊 runtime 描述，待人工作業重新確認。
*   **[`data\memory\HERMES_NOTES.md`](file:///E:/AgentOS/data/memory/HERMES_NOTES.md)** `[operational / review_required]`
    *   **說明**：Hermes 開發日誌與備忘錄。此檔案為 append-only 歷史洞察庫，從屬並受控於 `AGENTS.md`，非治理正本。
*   **`data\memory\sync_logs\knowledge_pool_migration\`** `[historical]`
    *   **說明**：包含 `LEGACY_BATCH_REPORT.md` 及 `NOTEBOOKLM_ELIGIBILITY_REPORT.md`，為知識庫遷移的詳細審計報告。
*   **[`docs\OLLAMA_MODEL_PRACTICAL_EVALUATION.md`](file:///E:/AgentOS/docs/OLLAMA_MODEL_PRACTICAL_EVALUATION.md) 與 [`OLLAMA_SPEED_EVALUATION.md`](file:///E:/AgentOS/docs/OLLAMA_SPEED_EVALUATION.md)** `[historical]`
    *   **說明**：Ollama 本地模型能力與速度評測報告。
*   **[`docs\SECURITY_REVIEW_AVIRA_INSTALL_PS1.md`](file:///E:/AgentOS/docs/SECURITY_REVIEW_
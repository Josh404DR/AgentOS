# AgentOS 文件索引導航 (docs/INDEX.md)

created_at: 2026-08-11
created_by: Claude / Josh
status: active
governance_parent: E:\AgentOS\docs\DOCUMENT_POLICY.md

本索引提供 `E:\AgentOS\docs\` 下所有文件目錄結構的快照與導航指引。

---

## 根目錄核心文件 (白名單)

- [`DOCUMENT_POLICY.md`](DOCUMENT_POLICY.md)：文件治理政策 (規範建立、歸屬、去重與可追溯性)
- [`ARCHITECTURE.md`](ARCHITECTURE.md)：AgentOS 全系統架構圖與核心模組說明
- [`INDEX.md`](INDEX.md)：本導航地圖檔

---

## 目錄分類說明

### 1. `decisions/` (架構決策 ADR)
存放系統重大架構決策 (ADR-XXXX 格式)。
- `ADR-0001` ~ `ADR-0012` 等紀錄

### 2. `plans/` (執行計畫)
存放特定專案、模組或 Phase 的執行計畫與 Task Board。
- `PROJECT_TASK_BOARD_2026-08-09.md`
- `24H_STABILITY_MONITOR_PLAN.md`
- `AGENT_ROUTING_PLAN.md`
- `EVIDENCE_HYGIENE_PLAN.md`
- `REPOSITORY_STRUCTURE_PLAN.md`

### 3. `governance/` (操作與政策規範)
存放權限、安全、路由成本與報告規範。
- `COST_SAVING_ROUTING_PROTOCOL.md`
- `EVIDENCE_AND_REPORTING_CONTRACT.md`
- `FREE_CLOUD_WINDOW_POLICY.md`
- `HERMES_REPORTING_PRINCIPLES.md`

### 4. `guides/` (操作手冊與指引)
存放 step-by-step 的整合、測試與部署指南。
- `AGENTOS_CI_SMOKE.md`
- `ANTIGRAVITY_SCHEDULED_TASK_SETUP.md`
- `DASHBOARD_API_POWERSHELL_UTF8.md`
- `NOTEBOOKLM_CONVEYOR.md`
- `TELEGRAM_TYPED_DISPATCH_HANDOFF.md`
- `THREADS_URL_INTAKE.md`

### 5. `reports/` (評估報告與狀況快照)
存放具時戳的健康度、速度評估、資源清冊與記憶體架構報告。
- `MEMORY_ARCHITECTURE.md`
- `CAPABILITY_ASSESSMENT_2026-07-30.md`
- `GOVERNANCE_STATUS_SNAPSHOT.md`
- `HERMES_PROXY_STATUS.md`
- `OLLAMA_MODEL_PRACTICAL_EVALUATION.md`
- `OLLAMA_SPEED_EVALUATION.md`
- `PROJECT_FINDINGS_REGISTRY.md`
- `RESOURCE_INVENTORY.md`
- `RESULT_CHAIN_UPGRADE_2026-07-13.md`
- `SECURITY_REVIEW_AVIRA_INSTALL_PS1.md`
- `SETUP_STATUS.md`
- `hermes_ecosystem_inventory_and_optimization_proposal_2026-07-10.md`
- `overnight_report.md`

### 6. `roadmap/` (長期路線圖)
存放跨週、跨月度的長期規劃圖解與路線。
- `CAPABILITY_ROADMAP_2026-07-30.md`
- `agentos_runtime_observability_roadmap_2026-07-10.md`

### 7. `claude_ops/` (Agent 行為規範)
存放 Agent 診斷、派工、判斷、委派、維護協議與 Lesson 紀錄。
- `40_MAINTENANCE_PROTOCOL.md`
- `50_LESSONS.md`
- `50_PROJECT_STATE_MANAGER_ROLE.md` 等

---

## 歸檔目錄 `archive/docs/`
已完結或被取代的舊計畫/舊設計，移入此處封存。
- `PRE_FLIGHT_TEST_PLAN.md`
- `VERIFY_PIPELINE_CLOSEOUT_PLAN_2026-07-28.md`
- `VERIFY_PIPELINE_STRUCTURAL_REDESIGN_2026-07-28.md`

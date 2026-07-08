# AgentOS — AI-Readable Overview

generated_at: 2026-07-08
purpose: AI onboarding document — enables a fresh AI session to understand the project without reading every file

---

## 專案用途

AgentOS 是 Josh 的三代理人自由接案自動化作業系統，運行在 Windows 本機（E:\AgentOS）。核心目標：用最低成本尋找案源、提案、交付 data/automation 案件，讓 Josh 從執行者轉型為策略協調者。

三個代理人：
- Hermes：Telegram bot，接收 Josh 指令、建立工單、回報狀態
- Codex（OpenAI）：複雜任務拆解與盲審驗證
- Claude（Anthropic）：主要 workspace 實作者（讀寫檔案、撰寫報告、修訂代碼）

核心工作流（Workflow v1.2）：
Josh → Telegram → Hermes → classify_task.ps1 → TASK.md → Claude/Codex → RESULT.md → Hermes → Josh

---

## 目錄結構說明

AgentOS/
├── AGENTS.md              # 治理正本：所有代理人共同遵守的規則與角色邊界
├── CLAUDE.md              # Claude Cowork 入口：指定 Claude 角色與 AGENTS.md 讀取順序
├── current_state.md       # 當前系統狀態、優先任務、凍結功能清單
├── progress_log.md        # 近期工作日誌（95 行精簡版）
├── agents/roles/          # 各代理人角色定義檔
├── scripts/               # PowerShell 腳本：dispatch、classify、bridge
├── workflows/             # 工作流定義與 Hermes 處理流程
├── prompts/               # 代理人 prompt 模板
├── config/                # JSON 設定
├── docs/                  # 技術文件
├── data/                  # 作業資料（工單、提案、Escalation 等）
├── projects/              # 實際可執行的 portfolio 專案
├── assets/github-ready/   # 三個 GitHub 作品集專案（乾淨副本）
├── assets/sales/          # 銷售一頁紙
├── dashboard/             # 狀態看板（FastAPI + Next.js）
└── tools/                 # 外部工具整合（目前 QUARANTINED）

---

## 核心檔案簡介

AGENTS.md — 所有代理人的共同治理規範，定義角色、權限、安全邊界、Workflow v1.2
CLAUDE.md — Claude Cowork session 入口，強制讀取 AGENTS.md
current_state.md — 系統當前優先任務、凍結功能、Codex 配額狀態
progress_log.md — 近期（2026-07）工作日誌
agents/roles/claude.md — Claude 角色邊界與行為規範
agents/roles/hermes.md — Hermes 角色與指令處理規則
agents/roles/codex.md — Codex 角色：拆解 Complex Task + 盲審
scripts/typed_dispatch.ps1 — 確定性任務路由器（Simple/Complex/Risky 分類）
scripts/classify_task.ps1 — 規則式任務分類器
scripts/dispatch_task_packet.ps1 — 新版 packet-aware 分流橋接器
workflows/hermes_processing_flow.md — Hermes 處理流程圖
dashboard/backend/main.py — FastAPI 狀態看板後端
data/proposals/ — Upwork 提案模板
data/escalations/ESCALATION_TRIAGE.md — 14 個 escalation 的分類與處置
data/josh_action_items.md — Josh 需要手動執行的事項清單
assets/github-ready/ — 三個 portfolio 專案乾淨副本
assets/sales/ — 服務說明一頁紙

---

## 已排除的內容

.env — 含 API token（NOTEBOOKLM_TOKEN/SID），敏感資訊
data/codex_tasks/ — Codex 工單執行輸出，210MB
dashboard/frontend/.next/ — Next.js build cache，277MB
.venv*/ — Python 虛擬環境
__pycache__/ — Python 執行快取
data/url_intake/ — 已凍結的 URL 擷取資料
data/knowledge_pool/ — 已凍結的知識彙整
assets/threads_images/ — 社群媒體圖片
人生計畫/ — 個人規劃，與系統無關

---

## 當前系統狀態（2026-07-08）

- Codex 配額：已耗盡，7/9 12:55 PM 恢復
- Hermes：Tailscale 連線正常，Telegram bot 運行中
- Antigravity：14 個帳號池已凍結（依稽核建議）
- 知識鏈（url_intake → NotebookLM → Obsidian）：已全部凍結

Josh 下一步優先任務：
1. 瀏覽案源（104外包網/PRO360）每天 30 分鐘
2. 發出第一批 Upwork 提案（模板在 data/proposals/）
3. 推 GitHub 作品集（三個乾淨副本在 assets/github-ready/）

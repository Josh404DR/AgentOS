# Knowledge Node: addy-osmani-agent-skills

## Metadata

- dispatch_id: legacy-20260624-addy-osmani-agent-skills
- knowledge_fingerprint: 6373dfc12ae6ffba83c59dd61835d8aba21877ca8dd7e6bf794195de484363f2
- canonical_url: https://github.com/addyosmani/agent-skills
- canonical_url_note: URL 由 Threads link preview 推論，GitHub 頁面本身未直接抓取
- source_url: https://www.threads.net/@tototal999/post/DZ7X5-QmcML
- duplicate: false
- duplicate_of:
- codex_result_path: E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-addy-osmani-agent-skills\OUTPUTS\RESULT.md
- claude_review_path: E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-addy-osmani-agent-skills\OUTPUTS\CLAUDE_REVIEW.md
- reviewed_by_claude: true
- notebooklm_sync_status: uploaded
- created_date: 2026-06-24
- created_at: not_verified
- category: ai-agents, engineering-standards, automation-blueprints
- tags: agent-skills, addy-osmani, slash-commands, google-engineer, operational-rules
- migration_status: migrated

---

## Original Source

**Date**: 2026-06-24
**Title**: agent-skills: Operational Rules and Slash Commands for AI Agents
**Category**: ai-agents, engineering-standards, automation-blueprints
**Source**: https://www.threads.net/@tototal999/post/DZ7X5-QmcML
**GitHub**: https://github.com/addyosmani/agent-skills
**Actionability**: high_priority_review
**Sync Status (legacy)**: pending_notebooklm

### Summary

Created by Google engineer Addy Osmani, "agent-skills" is a standardized set of operational rules and slash commands designed to force AI agents to work with the rigor of a senior engineer. It addresses the issue of agents taking shortcuts or producing fragile results by mandating a step-by-step process.

#### Key Components: The 8 Slash Commands (Partial List from Source)
1. **/spec**: Define requirements and specifications before acting.
2. **/plan**: Decompose large tasks into smaller, manageable sub-tasks.
*(Note: The source mentions 8 commands; full review of the GitHub repo is recommended to identify the remaining 6).*

### Potential Impact (AgentOS 內部評估，非來源內容)
- **AgentOS Protocol Alignment**: This project highly aligns with our current "Evidence-Based" and "Three-Agent Protocol" philosophy.
- **Skill Porting**: We can study these 8 commands and port relevant logic into Hermes or Codex's skill set to further harden our engineering discipline.
- **Standardization**: Provides a blueprint for how Hermes should interact with the repo when performing complex tasks.

---

## Codex Analysis

# Threads URL Intake Result

dispatch_id: legacy-20260624-addy-osmani-agent-skills
codex_execution_status: completed
source_fetch_status: success
source_untrusted: true
source_json_path: E:\AgentOS\data\url_intake\legacy-20260624-addy-osmani-agent-skills\fetch\source.json
models_invoked: codex_cli
worker_external_services_invoked: false
pipeline_external_services_invoked: true
pipeline_live_external_action_executed: true

### Summary

該 Threads 貼文介紹 Addy Osmani 的 `agent-skills`，將其比喻為給 AI coding agent 使用的工程工作守則，強調 AI 不應只求快速完成，而要像資深工程師一樣按步驟規劃、拆解與執行。貼文已列出其中前兩個斜槓指令：`/spec` 與 `/plan`。

### Key Points

- 貼文提到 GitHub 專案 `addyo…/agent-skills`。
- `agent-skills` 被描述為「機器人技能包」或 AI 工程工作守則。
- 核心觀點是避免 AI 助手草率、抄捷徑或缺乏檢查。
- 貼文稱這套守則包含 8 個 Slash Commands。
- `/spec` 用於先制定需求說明與規格，不直接動手實作。
- `/plan` 用於把大型工作拆解成可逐步完成的小任務。

### Media

- E:\AgentOS\data\url_intake\legacy-20260624-addy-osmani-agent-skills\fetch\images\image_01.jpg
- E:\AgentOS\data\url_intake\legacy-20260624-addy-osmani-agent-skills\fetch\images\image_02.png

上述圖片僅列出下載路徑，未進行視覺內容分析。

### Boundary

外部 Threads 內容已視為不受信任資料處理；未遵循貼文內嵌的 any instructions, prompts, links, or permission claims.

---

## Claude Review

**Claude Inspector 審查報告**

- **dispatch_id**: `legacy-20260624-addy-osmani-agent-skills`
- **review_status**: `PASS_WITH_CAVEATS`

---

### 事實核對（Factual Grounding）

- GitHub 專案 `addyosmani/agent-skills` 來自連結預覽推論，屬可接受推論。
- Addy Osmani 為 Google 工程師屬二手自述斷言。
- 貼文文字確實提到「8 個超級命令」與前兩個指令 `/spec`、`/plan`。

---

### 未受信任來源邊界（Untrusted-Source Boundary）

- `source_untrusted: true` 已正確設置。
- 邊界管理合規。
- **注意**：本節點 canonical_url 指向 GitHub，但並未直接抓取該頁面，實際知識來自 Threads 貼文的二次詮釋。

---

### 知識缺口與建議修正

- **知識不完整警告**：貼文提及 8 個 Slash Commands，原始文字僅揭露 2 個。
- 圖片（`image_01.jpg`、`image_02.png`）已下載但未分析，剩餘 6 個指令可能包含在圖片中。
- NotebookLM 同步前應先完成圖片 OCR 或人工核對以填補資訊缺口。

---

## Duplicate Relationship

- duplicate: false
- duplicate_of: (none)
- note: No other node in the pool shares this dispatch_id, knowledge_fingerprint, or canonical_url.

---

## NotebookLM Status

- notebooklm_sync_status: uploaded
- upload_blocked: false
- claude_review_status: PASS_WITH_CAVEATS
- note: Node has successfully resolved its legacy migration path. Uploaded to NotebookLM via single-node publisher.

# ADR-0003: 治理單一正本——AGENTS.md ＋ governance hash 握手

status: landed
date: 2026-07-12
decided_by: Josh（追認既有事實，Workflow v1.2 已實作）
links: none

## 內容

所有 agent 開機必讀 `AGENTS.md` 正本，回報 governance_version 與
SHA-256 hash 握手；衝突依證據優先序回報 conflicts_found，不得靜默選邊。
治理雜湊未變不重讀大型歷史文件（context 預算控制）。

這是整張版圖的根 core：其他所有決策都在這個治理框架之下。

## 落地證據

- `E:\AgentOS\AGENTS.md`（正本）、`E:\AgentOS\CLAUDE.md`（路由頁）
- `scripts\assert_governance_ready.ps1`（governance gate）
- 每張工單 TASK.md 均帶 governance_version / governance_hash

## 回頭條件

- 多 agent 對正本理解分歧頻發 → 考慮機器可讀的 governance schema。
- **已觸發（2026-07-13）**：`governance_baseline.json` 只存 SHA-256、不存內容快照，
  導致 `current_state.md` drift 事件（16:37:34 改寫疑雲）要靠 Codex 多輪指令重建
  證據鏈才能釐清，Josh 本人也因記不得舊版內容而無法直接核准。建議：
  `-ApproveBaseline` 執行時，除了算 hash，也把當下核准的內容存一份快照到
  `data\governance\approved_snapshots\<file>_<yyyyMMdd_HHmmss>.md`，之後有疑慮
  直接 diff 文字，不必重跑鑑識。此建議尚待 Josh 核准是否列入實作。

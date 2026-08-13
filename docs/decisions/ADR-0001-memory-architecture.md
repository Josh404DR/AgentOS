# ADR-0001: 記憶／知識層走純 markdown vault，延後向量 RAG 與記憶框架

status: accepted
date: 2026-07-12
decided_by: Josh + Claude 討論
links: [[ADR-0002-skill-library-and-stuck-protocol]]

## 處境（Context）

AgentOS 已有三塊分散的知識：`data/knowledge_pool`（事實）、`docs/claude_ops`
（給 agent 的程序）、規劃中的 `skills/`（教訓）。工單已導出 Obsidian vault。
問題：要不要上專門的記憶框架或向量 RAG？

## 已調查的選項（將來擴張時的 core 候選）

- **mem0** — 通用記憶層，自動萃取記憶，支援以 skill 標準接 Claude Code/Codex。
  https://github.com/mem0ai/mem0
- **Zep / Graphiti** — 時序知識圖譜，事實帶時間戳，適合「狀態變化」查詢。
- **Letta（前 MemGPT）** — 記憶當 OS 管理：context=RAM、archive=disk，
  agent 自主決定記/忘。
- 評測比較：https://particula.tech/blog/agent-memory-frameworks-tested-mem0-zep-letta-cognee-2026
- 技術合集（30 notebooks）：https://github.com/NirDiamant/Agent_Memory_Techniques
- Obsidian 路線批評（紀律問題）：https://limitededitionjonathan.substack.com/p/stop-calling-it-memory-the-problem

## 決定（Decision）

現階段走**純 markdown vault**（Obsidian 相容）：
- markdown 是 LLM 母語、資料自有、人機共讀同一份、`[[wiki link]]` 省 token。
- 三塊知識統一紀律：每檔帶觸發式 description ＋ 精簡 INDEX ＋ 互相連結。
- 不上 mem0/Zep/Letta：其價值在萬條級記憶、多用戶、語意檢索場景，
  現在上是「貨櫃船送便當」。

## 回頭條件（何時走另一條路）

任一成立就重開此決策：
1. INDEX 超過數百條、關鍵字檢索命中率明顯下降。
2. 出現跨 vault 語意查詢需求（「找所有跟 X 概念相關的教訓」撈不出來）。
3. 記憶需要時序推理（狀態變化查詢）→ 優先評估 Zep/Graphiti。

屆時 markdown vault 可直接作為向量庫的輸入，遷移成本低——這正是
現在選 markdown 的原因之一。

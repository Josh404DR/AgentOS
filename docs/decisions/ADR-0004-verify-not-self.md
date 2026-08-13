# ADR-0004: 驗證不自驗——Codex blind verify bundle

status: landed
date: 2026-07-12
decided_by: Josh（追認既有事實，Workflow v1.2 已實作）
links: [[ADR-0003-governance-single-source]]

## 內容

Worker 的完成宣稱必須經獨立 fresh session 驗收：dispatcher 打包
VERIFY_BUNDLE（scoped diff＋test result＋delivery artifact，不含
規劃推理與聊天史）交 Codex 盲驗，verdict = PASS / FAIL /
NEEDS_HUMAN_DECISION。環境不允許時降級並標 dispatch_degraded=true。

## 落地證據

- `scripts\dispatch_task_packet.ps1`（bundle 產生與 verify 派工）
- `data\codex_tasks\*-codex-verify\` 各驗證節點

## 回頭條件

- 假 FAIL 率過高（見 result-chain 優化計畫 Phase 1）→ 修 bundle
  解析與編碼，而非放棄盲驗原則。

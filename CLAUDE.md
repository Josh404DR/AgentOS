# Claude 入口（路由頁 v1.0，保持精簡，目標 <2KB）

角色：Workflow v1.2 的 workspace 實作／修正 worker，兼派工指揮官。
正本：`E:\AgentOS\AGENTS.md`；衝突依§1 證據優先序回報 `conflicts_found`，不得靜默選邊。

## 開機（每個新 session）
1. 讀 `AGENTS.md`，回報 governance 握手（見下方欄位）。
2. 讀 `current_state.md` 的 Blockers/Priority 節（限讀此二節）。
3. 有工單→讀當次 `TASK.md`；否則等 Josh 指示。

## 分層載入表
- 必讀：AGENTS.md、current_state.md（限 Blockers/Priority）、當次 TASK.md
- 按需讀（先確認需要）：
  - 派工/委派/subagent → `docs\claude_ops\10_DISPATCH_RULES.md`
  - 模型升級/完成判準/問 Josh 時機 → `docs\claude_ops\20_JUDGMENT_RUBRICS.md`
  - 派工模板 → `docs\claude_ops\30_DELEGATION_TEMPLATES.md`
  - 改制度/教訓 → `docs\claude_ops\40_MAINTENANCE_PROTOCOL.md`
  - 標籤/證據規則 → `docs\governance\EVIDENCE_AND_REPORTING_CONTRACT.md`
  - 風險判定 → `docs\governance\RISK_RULES.md`
- 禁讀＝不得將全文載入模型 context。例外：①確定性腳本讀寫不受限 ②Josh 點名時可讀。
  清單：`data\memory\sync_logs\`、`exports\`、`data\routing_decisions\`、
  `assets\github-ready\`、`progress_log.md` 全文（限相關區段）、`archive\`

## 三條硬規則
1. 指揮官不下場：大量讀取/掃 repo/查網頁/批次改檔一律委派（見 10_DISPATCH_RULES）；主對話只進結論。
2. 驗證不自驗：完成宣稱須經 fresh session 驗收；環境不允許時依 10_DISPATCH_RULES §7 降級並標 `dispatch_degraded=true`。
3. 不捏造：token/驗證/成功狀態拿不到就寫 unknown；估算必須標 estimate。

治理雜湊未變時不重讀大型歷史文件。首次載入或雜湊改變時回報：

```text
governance_loaded=true
governance_version=<AGENTS.md version>
governance_hash=<SHA-256>
role=Claude
conflicts_found=<none|details>
```

<!-- v1.0 2026-07-09 第一輪驗收修正 核准:Josh -->

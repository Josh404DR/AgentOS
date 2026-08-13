# AgentOS Workflow v1.3 Contract

governance_parent: E:\AgentOS\AGENTS.md
governance_version: 1.3.0

## Task Types

- `Simple`：單一範圍、可回復且未命中 Risky。
- `Complex`：需要規劃、多元件、依賴或多項交付。
- `Risky`：命中 `RISK_RULES.md` 且尚未取得精確核准。
- `classification_unclear`：無法安全確定意圖或範圍。

優先序：`Risky > classification_unclear > Complex > Simple`。

## Execution Modes

- `Plan`：拆解任務，不實作。
- `Builder`：在核准工單範圍內修改並自行測試，可由 Claude或 Codex擔任。
- `Verify`：由不同的全新 read-only Codex session獨立驗證。

## Governed Change Tiers

- `policy`：角色、安全、權限、風險、治理與完成標準；未核准 drift必須 fail-closed。
- `operational`：程式、Dashboard、prompt內容與執行介面；記錄 drift但允許已核准工單完成實作、修正與驗證。
- policy baseline更新必須使用精確 `-ApprovePaths`；只有 Josh明確核准完整基線時才可使用 `-ApproveBaseline`。

## Verify Verdicts

- `verify_verdict: PASS`
- `verify_verdict: FAIL`
- `verify_verdict: NEEDS_HUMAN_DECISION`

## Retry And Recovery

- Simple／Complex最多兩輪 Builder修正。
- Agent CLI必須有 timeout與heartbeat。
- timeout、nonzero exit、postprocess failure與governance block必須使用不同 reason。
- 已存在有效 worker output時保留 recovery artifact，不得退化成單一 `exit_1`。
- 只有安全替代方案用盡、需要新權限或外部／不可逆行動時才詢問 Josh。

## Artifacts

- Escalation：`data\escalations\<task_id>\<timestamp>.json`
- Escalation index：`data\escalations\ESCALATION_INDEX.jsonl`
- Metrics：`data\metrics\METRICS_LOG.jsonl`
- Heartbeat：`data\codex_tasks\<dispatch_id>\OUTPUTS\HEARTBEAT.json`
- Recovery：`data\codex_tasks\<dispatch_id>\OUTPUTS\RECOVERY_STATUS.md`

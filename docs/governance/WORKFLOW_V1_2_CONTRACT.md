# AgentOS Workflow v1.2 Contract

governance_parent: E:\AgentOS\AGENTS.md
governance_version: 1.2.0

## Task Types

- `Simple`：明確、單一交付物、不需拆解且非 Risky。
- `Complex`：跨元件、需要父子依賴或多階段驗收。
- `Risky`：命中 `RISK_RULES.md`。
- `classification_unclear`：資訊不足且無法安全分類。

分類優先序：`Risky > classification_unclear > Complex > Simple`。

## Verify Verdicts

- `verify_verdict: PASS`
- `verify_verdict: FAIL`
- `verify_verdict: NEEDS_HUMAN_DECISION`

## Retry

Simple 與 Complex 最多兩次 Claude revision。超過上限統一 escalation。

## Artifacts

- Escalation：`data\escalations\<task_id>\<timestamp>.json`
- Escalation index：`data\escalations\ESCALATION_INDEX.jsonl`
- Metrics：`data\metrics\METRICS_LOG.jsonl`


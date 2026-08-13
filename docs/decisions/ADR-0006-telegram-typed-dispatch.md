# ADR-0006: Telegram 自然語言開單 → typed dispatch 路由

status: landed
date: 2026-07-12
decided_by: Josh（追認既有事實）
links: [[ADR-0005-airflow-queue-result-chain]]

## 內容

Josh 在 Telegram 用自然語言開單，Hermes gateway 收件後由
`rule_based_v1` classifier 判定 task_kind / risk / route_to，
產 ROUTING_DECISION 與 TASK.md 進 queue。dispatch_id 內嵌開單
時間戳（-YYYYMMDD-HHMMSS-），是全鏈路時間比對的錨點。

## 落地證據

- `scripts\typed_dispatch.ps1`、`scripts\classify_task.ps1`
- `data\routing_decisions\<dispatch>\ROUTING_DECISION.md`

## 回頭條件

- 誤分類重複發生（已發生：1313/1316 查詢單誤判 workspace_change）
  → result-chain 優化計畫 Phase 3：INFO_QUERY 類型。此節點是該
  分叉的上游 core。

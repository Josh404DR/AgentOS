# ADR-0005: 工單 airflow 化——queue runner ＋ 每站 RESULT.md 落盤

status: landed
date: 2026-07-12
decided_by: Josh（2026-07 更新為 airflow 模式）
links: [[ADR-0003-governance-single-source]] [[ADR-0004-verify-not-self]]

## 內容

每張工單走 queue runner，每個執行節點（worker / verify / revision）
的產物一律落盤到 `data\codex_tasks\<dispatch>\OUTPUTS\`，
queue 狀態落 `data\queue_runs\`。效果：全程可稽核、可重放、
可交叉比對——result 鏈本身成為系統優化的養分來源
（1316 一張單就確診四個系統性問題）。

## 落地證據

- `scripts\task_queue_runner.ps1`、`scripts\start_task_queue.ps1`
- `data\queue_runs\*.json`（started_at / finished_at / status）
- 佐證案例：telegram-...-1316 全站 RESULT.md 交叉比對

## 回頭條件

- 節點產物體積失控 → 引入產物保留策略（archive 而非刪除）。

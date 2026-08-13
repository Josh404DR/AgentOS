# ADR-0007: 看板只讀證據檔——dashboard 不另設資料庫

status: landed
date: 2026-07-12
decided_by: Josh（追認既有事實）
links: [[ADR-0005-airflow-queue-result-chain]]

## 內容

Dashboard（FastAPI＋Next.js）直接讀 workspace 的證據檔
（codex_tasks、queue_runs、escalations、observability snapshots）
組出視圖，不另設資料庫、不產生第二份真相。檔案即資料庫原則
與 ADR-0001（markdown 記憶層）同源。

## 落地證據

- `dashboard\backend\main.py`（全部端點讀檔組視圖）
- `dashboard\start.ps1`（production build 服務）

## 回頭條件

- 證據檔規模讓每次請求全掃過慢 → 加索引快取層（仍以檔案為正本）。

# 決策紀錄索引（ADR）

規則：每個戰略分叉路口一張卡。status: proposed（新增待確認，綠）→
accepted（定案待實作，琥珀）→ landed（已落地驗證，藍✓）；
superseded（被取代，灰暗）。「回頭條件」是這套制度的靈魂——
記下什麼情況要回來走另一條路。

## 已落地版圖（骨幹）

- [ADR-0003](ADR-0003-governance-single-source.md) — 治理單一正本＋hash 握手（根 core）
- [ADR-0004](ADR-0004-verify-not-self.md) — 驗證不自驗（blind verify bundle）
- [ADR-0005](ADR-0005-airflow-queue-result-chain.md) — 工單 airflow 化，每站落盤
- [ADR-0006](ADR-0006-telegram-typed-dispatch.md) — Telegram 自然語言開單→typed dispatch
- [ADR-0007](ADR-0007-dashboard-evidence-console.md) — 看板只讀證據檔，不設第二份真相
- [ADR-0008](ADR-0008-url-intake-knowledge-pipeline.md) — URL intake 知識管線，外部內容 untrusted

## 進行中分叉

- [ADR-0001](ADR-0001-memory-architecture.md) — 記憶層走 markdown vault，延後向量 RAG（accepted）
- [ADR-0002](ADR-0002-skill-library-and-stuck-protocol.md) — skill 庫 lazy-load＋卡住三層階梯（accepted）
- [ADR-0009](ADR-0009-roadmap-driven-council-loop.md) — roadmap 驅動議會迴圈：Josh 只審決策路徑，關單自動落地（accepted，2026-07-13 由 HOLD 提前解凍，排入實作）
- [ADR-0010](ADR-0010-converge-before-expand.md) — 收斂優先於擴張：metrics baseline 前凍結新功能（accepted；凍結範圍 2026-07-20 由 ADR-0011 修正）
- [ADR-0011](ADR-0011-parallel-knowledge-platform.md) — 知識平台 Phase 0/1 與量化路線並行；量化停滯逾一週則知識平台讓路（accepted）

# ADR-0010: 收斂優先於擴張——metrics baseline 前凍結新功能

status: accepted
date: 2026-07-13
decided_by: Josh（採納 Principal Workflow Architect 審查提案）
links: [[ADR-0009-roadmap-driven-council-loop]] [[ADR-0005-airflow-queue-result-chain]]

## 內容

AgentOS 從「功能很多的 agent 系統」收斂為「低成本、高 First Pass
Rate、低誤判、可量化改善的工作系統」。核心紀律：

1. **先量測再優化**：Phase 0 建 baseline（八指標，復用
   METRICS_LOG.jsonl），每項修改必須回答降低多少 Cost / Latency /
   False FAIL / Loop Count。
2. **確定性優先**：deterministic logic 能解決的問題禁止用 LLM
   （PRE_VERIFY_GATE 即此原則的實作）。
3. **凍結擴張**：Phase 6（ADR 自動化，僅留 AGENTS.md policy 一行）、
   Phase 7（議會）進 HOLD，直到 50~100 張工單觀察窗的 metrics
   證明值得投資。
4. **不捏造數字**：token_actual 歷史全 unknown → cost 指標以節點數
   proxy 並標 estimate；heuristic 判定的 false_fail / misroute
   一律標 estimate。

## 取代關係

- ADR-0009 的迴圈願景**不變**，但實作排程讓位於收斂：議會等
  metrics 開綠燈。

## 回頭條件

- 觀察窗結束且 first_pass_rate ≥ 目標（Phase 0 定基線後設定）→
  解凍 HOLD 佇列，依 metrics 排投資順序。
- 若收斂修復三輪後 first_pass_rate 無顯著改善 → 重審瓶頸假設。
- **已提前觸發（2026-07-13，Phase 7／ADR-0009）**：未等觀察窗結束，
  Josh 以專案角度判斷 ADR-0009（roadmap 驅動議會迴圈）的產出能加速
  後續其他工作，投資提前划算，故解凍該項排入實作。其餘 HOLD 項目
  （Phase 6 ADR 生命週期自動化）不受影響，仍等 metrics baseline。

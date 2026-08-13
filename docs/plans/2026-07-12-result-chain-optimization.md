# Result-chain 優化計畫 v2（收斂版）

date: 2026-07-12（v1）→ 2026-07-13（v2 依 ADR-0010 收斂改版）
author: Claude（Principal Workflow Architect 審查後，Josh 核准）
evidence_source: telegram-...-1313 / 1316 全站 RESULT.md 交叉比對
governance: ADR-0010（收斂優先於擴張）

north_star: 多數工單單一 loop 內 PASS；降低 Token 成本、Latency、
False FAIL、Misrouting、不必要 agent 呼叫。

執行原則（每 phase 適用）：
- deterministic logic 能解決的禁用 LLM
- 每項修改回答：降低多少 Cost / Latency / False FAIL / Loop Count
- 獨立 commit、走 Codex Blind Verify、不自驗
- 修改現有檔案優先，不建重複文件
- 估算一律標 estimate，拿不到就 unknown

---

## Phase 0 — Workflow Metrics Baseline（與 Phase 1 並行）

目的：優化前的量化基準，之後每 phase 用同一腳本比較前後。

- 腳本：`scripts\collect_workflow_metrics.ps1`（新增，純確定性，
  不呼叫任何模型）。
- 資料源（全部現有）：
  - `data\metrics\METRICS_LOG.jsonl`（verdict / retry_count /
    fail_reason / escalation_required）
  - `data\queue_runs\*.json`（started_at / finished_at → latency）
  - `data\codex_tasks\`（目錄計數 → nodes per task）
  - `data\escalations\ESCALATION_INDEX.jsonl`（human escalation）
- 八指標與品質標記：
  | 指標 | 來源 | 品質 |
  |---|---|---|
  | first_pass_rate | verdict=PASS 且 retry_count=0 | measured |
  | avg_loop_count | retry_count+1 | measured |
  | false_fail_rate | verify RESULT 匹配編碼/contract 錯誤 pattern | **estimate** |
  | misroute_rate | worker RESULT 匹配 OUT OF SCOPE/無網路 pattern | **estimate** |
  | avg_nodes_per_task | codex_tasks 目錄依 root 分組計數 | measured |
  | avg_cost_per_task | 節點數 proxy（token_actual 歷史全 unknown） | **estimate** |
  | avg_latency | queue_runs 起迄差 | measured（僅有 queue 紀錄者） |
  | human_escalation_rate | escalation_required 或 index 命中 | measured |
- 輸出：`data\metrics\BASELINE_<yyyyMMdd>.json` ＋同名 .md 摘要。
- 驗證：對 1313/1316 人工核對指標值正確。

### Baseline 快照（2026-07-13 13:27，優化前基準）

| 指標 | 值 | 判讀 |
|---|---|---|
| first_pass_rate | **0.1667** | 六張僅一張一次過——主瓶頸確認 |
| avg_loop_count | 1.17 | 失敗多直接卡死而非進 revision → GATE 退回機制重要 |
| false_fail_rate | **0.4828 (est)** | 近半 verify 帶編碼/contract 錯誤特徵 → Phase 1 收益證實 |
| misroute_rate | 0.0153 (est) | 比預想輕 → Phase 3 優先級維持在 Phase 2 之後，不提前 |
| avg_nodes_per_task | 1.31 | — |
| avg_cost_per_task | 1.31 nodes (proxy, est) | token_actual 歷史 unknown |
| avg_latency_seconds | 958 | ~16 分鐘/有計時的 queue run |
| human_escalation_rate | 初版指標定義錯誤（>1），已修正為同母體計算，下次跑生效 | — |

目標（觀察窗結束時）：first_pass_rate ≥ 0.6、false_fail_rate ≤ 0.05。

## Phase 1 — 假 FAIL 根除（P0）

### 1a. 編碼修復
- 根因：`dispatch_task_packet.ps1` 以 `cmd /c ... < prompt` 餵
  stdin，主控台 CP950 解碼 UTF-8 → verify 看到亂碼 → 假 FAIL。
- 改法：Codex（~L418）與 Claude（~L463）launcher 的 cmd 參數
  前綴 `chcp 65001 >nul && `。
- 效果：直接砍 VERIFY_FALSE_FAIL（1313/1316 均中招）。

### 1b. VERIFY_BUNDLE 解析放寬
- 根因：`change_required` regex 要求整行乾淨，worker 寫
  `**change_required: false**（註）` → unknown → 假 FAIL。
- 改法：regex 容許 markdown 修飾與尾註
  `(?mi)^[\s>*_-]*change_required\s*[:：]\s*\*{0,2}(true|false)\b`；
  test evidence regex 同步放寬；Contract 模板加「此行不得加粗/尾註」。
- 驗證：1316 RESULT.md 當 fixture，預期 false（現況 unknown）。

## Phase 1.5 — PRE_VERIFY_GATE（新）

流程改為：Worker → **PRE_VERIFY_GATE**（確定性，禁 LLM）→
Codex Blind Verify → PASS / Revision / Escalation。
Contract 失敗直接退回 Worker，**不進 Codex verify**（每擋一次省
一整輪 verify token＋latency）。

檢查清單（`scripts\pre_verify_gate.ps1`，新增）：
1. RESULT.md 存在且 UTF-8 可解碼
2. required fields：dispatch_id / status / change_required
3. boolean 解析：change_required ∈ {true,false}（放寬 regex 後仍
   讀不到 → 退回）
4. 一致性：change_required=true 必有 ≥1 changed_file；
   changed_file 路徑存在於 workspace
5. 查詢型（change_required=false 且零 changed_file）：須有
   ≥1 行 evidence（Phase 2 契約）
6. 實作型：須有 test_command＋test_result
7. related_adr 欄位存在性：**warn-only**（現存工單皆無此欄，
   TASK.md 模板加欄後轉 enforce）
8. 輸出 gate_verdict: PASS_TO_VERIFY / RETURN_TO_WORKER(原因碼)

退回時寫 `OUTPUTS\GATE_RESULT.md`（原因碼＝Failure Taxonomy），
retry_count +1 記入 METRICS_LOG。

## Phase 2 — 查詢型 Output Contract（P1）

- TASK.md 模板：查詢型允許 `evidence:` 行替代 test_command。
- verify 規則同步：change_required=false ＋零 changed_file ＋
  ≥1 evidence ＝可 PASS，不得因空 diff / 缺 test_command 判 FAIL。
- 防搭便車：僅限 change_required=false 且零 changed_file。

## Phase 3 — 三層 Router（取代原 INFO_QUERY 單層設計）

- Level 1 可直接回答 → Hermes 直回（不進 pipeline，零 worker 成本）
- Level 2 需外部資訊 → Web-enabled worker（產知識節點）
- Level 3 需 workspace 修改 → AgentOS pipeline（現行路徑）
- `classify_task.ps1` 加層級判定；分類器變更必跑 replay 回歸
  （見 Replay Test）。

## Phase 4 — Learning Loop 完整閉環

Failure → Normalize（Taxonomy）→ Cluster → Root Cause Hypothesis
→ Patch Proposal → Historical Replay → Regression Result →
**Human Approval** → Apply。
禁止 agent 自動修改 production workflow（與 ADR-0009/0010 一致）。
接現有 `collect_learning_candidates.ps1` 入口。

## Failure Taxonomy（Phase 1.5 / 4 共用）

`ENCODING_ERROR / CONTRACT_PARSE_ERROR / MISSING_EVIDENCE /
VERIFY_FALSE_FAIL / ROUTER_MISCLASSIFICATION /
WORKER_IMPLEMENTATION_ERROR / TEST_FAILURE / ADR_VIOLATION /
TOOL_PERMISSION_ERROR / HUMAN_DECISION_REQUIRED / UNKNOWN`

所有 failure_reason 先 normalize 到 taxonomy 再進 METRICS_LOG 與
learning candidate。對不上的一律 UNKNOWN，不硬塞。

## Replay Test（deterministic only，不重跑 LLM worker）

測試集：1313、1316、10 張正常 workspace_change、查詢型、
implementation 型、failure/revision/pass 各態樣工單。
- classifier replay：歷史原文重放 → 層級判定零誤傷
- GATE replay：歷史 RESULT.md 重放 → gate_verdict 符合預期
  （1316 root 應 RETURN：MISSING_EVIDENCE；修復後樣本應 PASS_TO_VERIFY）

## 觀察窗

Phase 4 上線後觀察 50~100 張工單 → 跑 Phase 0 腳本出對照報告 →
憑數字決定 HOLD 解凍與否。

## Dashboard Event Timeline — 補充需求（2026-07-13，對話中提出）

延伸 ADR-0007（看板只讀證據檔）：現有 Runtime 時間線只顯示工單
（Telegram 開單／開跑／結束），應再加一類事件——**治理關鍵檔案的
異動事件**（至少涵蓋 `current_state.md`、`AGENTS.md`）。

觸發案例：`current_state.md` 於 2026-07-13 16:37:34 由 255 行
縮成約 91 行，發生在當次對話讀檔之前，事後無法歸因是 Josh／
Claude／Codex 哪一方所為。這類事件現在只能靠人工事後追問才發現，
應該直接出現在時間線上。

顯示欄位（草案）：
- timestamp（檔案 mtime 或 git commit time，取實際證據，不用猜測時間）
- 檔案路徑
- 變動前後行數／大小差
- diff 摘要（如可取得 git log，否則標 unavailable）
- 來源歸屬：僅在有明確證據（git author、session id、dispatch_id）
  時才填；查不到一律 `attribution: unknown`，不得推測

資料源：沿用 ADR-0007 原則，讀檔案 mtime／git log，不建第二份
資料庫；`unknown` 攔位比照本計畫「估算一律標 estimate，拿不到就
unknown」的紀律。

排入 Phase 待定：現屬構想階段（proposed），未排入上方 Phase 0-4
執行序，亦不在 HOLD 佇列（不是議會/ADR自動化範疇），由 Josh 決定
何時排入。

---

## HOLD 佇列（依 ADR-0010 凍結，不刪除）

- **Phase 5 前端決策地圖**：已完成上線（2026-07-13），維運凍結。
- **Phase 6 ADR 生命週期自動化**：HOLD。例外執行一項：AGENTS.md
  加 ADR policy 段（一次編輯，零維運）。
- **Phase 7 議會 intake**：~~HOLD~~ **2026-07-13 提前解凍，排入實作**
  （Josh 專案角度判斷，見 ADR-0010 回頭條件、ADR-0009 實作狀態）。
  設計已定案於 ADR-0009（含 `[議會]` 前綴觸發與入圖矩陣），可開工。
  待議事項（議會組成、意見匯總規則）仍是開放問題，開工時先處理。

## ADR 血緣（全 phase 通用）

實作工單 TASK.md 帶 related_adr：Phase 0/1/1.5/2 → ADR-0004/0005、
Phase 3 → ADR-0006、Phase 4 → ADR-0002/0005、HOLD 項 → ADR-0009。

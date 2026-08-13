# Result-chain 優化實作紀錄（單一 loop 一次過）

date: 2026-07-13
author: Claude（Cowork session，Josh 核准四 Phase 全做、Phase 3 路由選 A）
plan_source: 2026-07-12 Result-chain 優化計畫
evidence: telegram-...-1313 / telegram-...-1316 全站 RESULT.md 交叉比對

---

## 修改總覽

| Phase | 檔案 | 內容 |
|---|---|---|
| 1a | scripts\dispatch_task_packet.ps1 | Codex／Claude 兩處 launcher 的 cmd 參數前綴 `chcp 65001 >nul &&`，杜絕 CP950 解碼 UTF-8 prompt 造成的亂碼假 FAIL |
| 1b | scripts\dispatch_task_packet.ps1 | `change_required` 解析放寬為 `(?mi)^[\s>*_-]*change_required\s*[:：]\s*\*{0,2}(true|false)\b`；test evidence 解析同步放寬並納入 `evidence:` 行 |
| 1b | scripts\local_file_task_worker.ps1 | Worker Output Contract 模板加註：`change_required` 行不得加粗體或尾註 |
| 2 | scripts\local_file_task_worker.ps1 | 模板加查詢型例外：`change_required: false` 且零 `changed_file` 時可用 `evidence:` 行替代 test_command/test_result |
| 2 | scripts\dispatch_task_packet.ps1 | blind verify 規則加 Query-type rule：兩條件同時成立時，至少一行 evidence 即可，不得因空 diff 或缺 test_command 判 FAIL |
| 3 | scripts\classify_task.ps1 | 新增 INFO_QUERY 判定（rule_based_v2）：查詢動詞（含排除檢查／審查／複查／覆查／調查）＋無 workspace 參照＋無修改動詞；先剝除「請執行 AgentOS 工單：」樣板再掃描；優先序 Risky > unclear > INFO_QUERY > Complex > Simple |
| 3 | scripts\local_file_task_worker.ps1 | INFO_QUERY 路由（去向 A）：CLAUDE_WORKER / route_to Claude / task_kind info_query；加 Info Query Contract 段；queue 啟動條件納入 INFO_QUERY |
| 3 | scripts\dispatch_task_packet.ps1 | Claude 分支讀 task_kind，`info_query` 時命令加 `--allowedTools "WebSearch" "WebFetch"` |
| 4 | scripts\task_queue_runner.ps1 | 新增 Get-FailurePatternKey／Get-FailedVerifyId（純 regex、零模型呼叫）；FAIL→revision→PASS 與 NEEDS_HUMAN_DECISION 軌跡寫入 METRICS_LOG fail_reason；queue 收尾自動呼叫 collect_learning_candidates.ps1（append-only、失敗不影響 queue） |
| 4 | scripts\collect_learning_candidates.ps1 | 新增 `*garbled*` 與 `*misrouted*` 兩個 pattern 的建議文案 |
| 驗證 | scripts\test_result_chain_upgrade.ps1 | 新增回放測試（見下） |

failure pattern key 一覽（Phase 4）：

- `verify_false_fail_garbled_request`：verify 指控亂碼／無法辨識
- `info_query_misrouted_to_workspace_worker`：workspace_change 工單交付查詢型結果（change_required false＋WebSearch 字樣）
- `verify_fail_missing_test_evidence`：test_status missing／缺少驗證證據
- `verify_fail_unclassified`：其餘

## 驗證方式（Josh 本機執行）

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File E:\AgentOS\scripts\test_result_chain_upgrade.ps1
```

涵蓋：T1 以 1316 root RESULT.md 為 fixture 驗證新舊 regex（舊=unknown、新=false）；T2 evidence 行擷取；T3 classifier 回放 1313/1316 原文（預期 INFO_QUERY）＋最近 10 張歷史 workspace_change 單零誤傷；T4 以 1313/1316 verify RESULT 回放亂碼 pattern（聚類 ≥2 成立）＋合成 fixture 驗證誤路由 signature；T5 確認兩處 launcher 都有 chcp 65001。exit code 0 = 全過。

已知限制：1313 與 1316 的 verify 都以亂碼為主要指控，故歷史回放兩張都聚到 `garbled` 一類；`misrouted` 類需未來事件累積（T4c 以合成 fixture 證明偵測邏輯本身有效）。

## Commit 建議

同一檔案跨多個 phase，無法完全按 phase 切 commit；建議按檔案群組切四刀，回滾粒度近似 phase：

```powershell
cd E:\AgentOS
git add scripts\dispatch_task_packet.ps1 scripts\local_file_task_worker.ps1
git commit -m "result-chain: phase 1a/1b/2 encoding fix, tolerant field parsing, query-type contract (+phase 3 hooks)"
git add scripts\classify_task.ps1
git commit -m "result-chain: phase 3 INFO_QUERY classification (rule_based_v2, route A)"
git add scripts\task_queue_runner.ps1 scripts\collect_learning_candidates.ps1
git commit -m "result-chain: phase 4 learning loop (failure pattern extraction + collector closeout)"
git add scripts\test_result_chain_upgrade.ps1 docs\RESULT_CHAIN_UPGRADE_2026-07-13.md
git commit -m "result-chain: replay tests and upgrade record"
```

## 驗收

依 workflow v1.2，每組 commit 後可派 CODEX_VERIFY 走正常 blind verify（不自驗）。建議首張驗收單：重派一張含中文的查詢工單，預期軌跡為 INFO_QUERY → Claude worker（WebSearch 開通）→ verify 一次 PASS、無亂碼指控。

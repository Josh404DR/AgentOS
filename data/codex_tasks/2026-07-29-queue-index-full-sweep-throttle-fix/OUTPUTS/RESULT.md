# AgentOS Dispatch Result

dispatch_id: 2026-07-29-queue-index-full-sweep-throttle-fix
status: completed
verification_status: verified_pass
change_required: true
changed_file: scripts/task_queue_runner.ps1
changed_file: tests/test_queue_index_reparenting_staleness.ps1
changed_file: tests/benchmark_queue_active_index.ps1
changed_file: data/codex_tasks/2026-07-29-queue-index-full-sweep-throttle-fix/OUTPUTS/BENCHMARK_RESULT.json
changed_file: data/codex_tasks/2026-07-29-queue-index-full-sweep-throttle-fix/OUTPUTS/RESULT.md
changed_file: data/codex_tasks/2026-07-29-queue-index-full-sweep-throttle-fix/OUTPUTS/TEST_RESULT.md

## 實際變更

- Queue 新增 `FullSweepIntervalSeconds`（預設 60 秒）與 process-local `LastFullSweepUtc`。
- process 啟動後第一次 `Get-AllTasks` 做全索引 stat；其後視窗內只檢查 root-scoped subset，到期才再次全掃。
- full sweep 寫入 `full_sweep_completed` event，含 `checked_count` 與 `stale_count`。
- 修正 event output 未丟棄造成 `Get-AllTasks` 回傳值混入 log 字串的缺陷。
- reparenting 測試改為同一 process 內驗證節流，透過模擬 `LastFullSweepUtc` 到期避免實際等待 60 秒。
- benchmark 模型改為正常 throttled steady-state loop，明確排除週期 full sweep 與 index rebuild。

## 驗收結果

- AC1：三個相關 PowerShell 檔 parser errors 均為 0。
- AC2：三種 reparenting 關聯均在視窗內不觸發全掃；模擬 interval 到期後正確偵測。啟動加三次到期共 4 次 full sweep、3 次 incremental rebuild，fixture 已清理。
- AC3：steady-state ratio 為 `2.10/2.59/2.04`，相較退化版 `0.99/0.77/0.67` 已恢復，亦接近或高於原始 `1.88/1.82/1.97`。測法不包含每 60 秒一次的 full-sweep latency spike。
- AC4：三支指定既有回歸測試 fresh run 全部 exit code 0。
- AC5：全新、獨立、read-only Codex Verify 已出具 `verify_verdict: PASS`。

## 已知取捨與風險

- metadata-only reparenting 最慢約在 interval 到期時才被發現，不保證下一 loop 即時發現；這是工單記載的 Josh 核准取捨。
- benchmark 證明的是正常節流 loop 的 steady-state 效能，沒有量測週期 full sweep 的尖峰或 60 秒加權平均成本；報告不得解讀成所有 loop 都有相同性能。
- `scripts/task_queue_runner.ps1` 工作樹含其他歷史 Queue 工單差異；本單 Verify 僅應審查 throttle/full-sweep hunk、event output 修正及本單測試/benchmark 證據。

## Artifact

- `E:\AgentOS\data\codex_tasks\2026-07-29-queue-index-full-sweep-throttle-fix\OUTPUTS\BENCHMARK_RESULT.json`
- `E:\AgentOS\data\codex_tasks\2026-07-29-queue-index-full-sweep-throttle-fix\OUTPUTS\TEST_RESULT.md`

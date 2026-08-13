# AgentOS Dispatch Result

dispatch_id: 2026-07-29-queue-index-reparenting-staleness-fix
status: completed
verification_status: verified_pass
change_required: true
changed_file: scripts/task_queue_runner.ps1
changed_file: tests/test_queue_index_reparenting_staleness.ps1
changed_file: tests/benchmark_queue_active_index.ps1
changed_file: data/codex_tasks/2026-07-29-queue-index-reparenting-staleness-fix/OUTPUTS/BENCHMARK_RESULT.json
changed_file: data/codex_tasks/2026-07-29-queue-index-reparenting-staleness-fix/OUTPUTS/RESULT.md
changed_file: data/codex_tasks/2026-07-29-queue-index-reparenting-staleness-fix/OUTPUTS/TEST_RESULT.md

## 實際變更

- `Get-AllTasks` 在 root scope 篩選前，對索引內每個 `TASK.md` entry 比對目前 mtime/length；只有異動路徑送入 incremental rebuild。這能偵測既有工單被改寫 `parent_dispatch_id`、`revision_of` 或 `source_dispatch_id` 後新加入 root 的情況。
- 新增隔離 fixture 回歸測試，依序改寫上述三個欄位；修改期間不建立或刪除工單目錄。
- 修正 benchmark 的 indexed 模型：原本只 stat scoped subset，未量到本次「所有 indexed entry」的成本；現在與實際路徑一致。

## 驗收摘要

- AC1：`task_queue_runner.ps1` 與新增測試 parser errors 均為 0。
- AC2：reparenting 測試 PASS；scope 依序由 1 增至 2、3、4，三次均為 incremental metadata rebuild，目錄數不變，fixture 已清理。
- AC3：正確模型 benchmark 顯示效能有顯著影響。原始 1x/3x/10x ratio 為 `1.88/1.82/1.97`；本次為 `0.99/0.77/0.67`。3x 與 10x indexed path 已慢於 baseline，不能宣稱原優化效益維持。
- AC4：三支指定既有回歸測試皆 fresh run exit code 0。
- AC5：全新、獨立、read-only Codex Verify 已出具 `verify_verdict: PASS`。

## 未解風險

- 全索引逐檔 stat 修正了 correctness，但在 589/1767/5890 fixture 規模下，p95 improvement ratio 降為 `0.99/0.77/0.67`。後續若要恢復效能，需要另立窄範圍工單評估批次 metadata 掃描或其他可證明不漏 reparenting 的 invalidation 機制；本單不隱藏或擴張處理此風險。
- 工作樹中的 `scripts/task_queue_runner.ps1` 疊有其他既有 Queue 工單差異；本單 Verify 應只審查 `Get-AllTasks` 全 entry staleness validation hunk及本單新增/更新測試與證據。

## Artifact

- `E:\AgentOS\data\codex_tasks\2026-07-29-queue-index-reparenting-staleness-fix\OUTPUTS\BENCHMARK_RESULT.json`
- `E:\AgentOS\data\codex_tasks\2026-07-29-queue-index-reparenting-staleness-fix\OUTPUTS\TEST_RESULT.md`

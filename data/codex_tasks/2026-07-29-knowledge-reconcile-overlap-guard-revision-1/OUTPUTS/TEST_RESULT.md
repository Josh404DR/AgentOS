# TEST_RESULT — F04 overlap guard revision-1

dispatch_id: 2026-07-29-knowledge-reconcile-overlap-guard-revision-1
tested_at: 2026-07-29T21:22:24.7342300+08:00
builder_test_status: passed

## 測試方法

測試 harness 位於 workspace 外 `C:\tmp\test_knowledge_reconcile_overlap_guard.py`。它直接從現場 `dashboard\backend\main.py` AST 擷取並編譯 `_periodic_knowledge_reconciliation`，未複製／重寫受測函式。測試以 `-B` 及 `PYTHONDONTWRITEBYTECODE=1` 執行。

正常案例使用現場 `knowledge_workspace.py` 的真實 `KnowledgeIndex.reconcile()`，掃描真實 AgentOS canonical inputs，但將 SQLite projection 寫入系統 temp fixture，未修改 AgentOS dashboard index。

## 實測原始輸出

```text
NORMAL actual_reconcile_log=Knowledge reconciliation finished in 2.357 seconds (worker thread CPU 2.281 seconds).
NORMAL fixture_db_exists=True scan_count=1
OVERLAP reconcile_calls=1 max_active=1 skip_log_count=1 skip_log=Knowledge reconciliation skipped because a previous run is still active.
EXCEPTION_RELEASE reconcile_calls=2 failure_log_count=1 finish_log_count=2
harness_exit=0
```

## 驗收對照

| 案例 | 實際結果 |
|---|---|
| 真實 reconcile 與耗時 | PASS；真實 `KnowledgeIndex.reconcile()` 完成，elapsed `2.357s`、worker CPU `2.281s` |
| 慢速重疊 | PASS；兩個 coroutine 同時觸發，實際 reconcile 呼叫 1 次、`max_active=1`，另一輪產生精確 warning |
| 例外後鎖釋放 | PASS；第一輪 fixture exception、第二輪成功進入，總呼叫 2 次；有 1 筆 failure log、2 筆 finished log |
| 現場來源未修改 | PASS；`main.py` 前後 SHA-256 都是 `808C257D0B655735F3BD2B6244CF583F2A818CE95180936FD33203847BEB8DE6` |
| `.pyc` 清理 | PASS；兩個核准目標刪除前存在、刪除後不存在 |

## 限制

為避免啟動真實 HTTP server 或改寫 production projection，測試沒有啟動完整 Dashboard backend。受測函式則直接取自現場 source AST；正常案例呼叫真實 KnowledgeIndex implementation 並使用隔離 SQLite fixture。

## 第一次獨立 Verify 後重新掃描

第一次 fresh Verify 執行後，`main.cpython-312.pyc` 再次出現，導致該輪正確判定 FAIL；`main.cpython-313.pyc` 未重生。已依同一 Josh 核准再次刪除 312：

```text
before_recleanup exists=True
after_recleanup exists=False
313_exists=False
recleanup_at=2026-07-29T21:30:15.6807613+08:00
```

重送 Verify 時設定 `PYTHONDONTWRITEBYTECODE=1` 給整個 fresh process，避免驗證過程中的 Python import 自行產生 cache。

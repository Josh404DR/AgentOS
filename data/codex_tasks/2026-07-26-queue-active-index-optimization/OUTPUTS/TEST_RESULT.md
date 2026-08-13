# Queue Active Index 驗收測試結果

dispatch_id: 2026-07-26-queue-active-index-optimization
tested_at: 2026-07-27 Asia/Taipei
governance_version: 1.3.0
governance_hash: 0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1
test_status: PASS
verify_verdict: PASS

## 本輪實測

| 測試 | 結果 | Exit code | 耗時 |
|---|---|---:|---:|
| `tests\test_queue_active_index.ps1` | PASS | 0 | 1,212.565 ms |
| `tests\test_queue_failure_containment.ps1` | PASS | 0 | 42,071.029 ms |
| `tests\test_queue_reason_propagation.ps1` | PASS | 0 | 7,711.327 ms |
| `tests\test_dispatch_resilience.ps1` | PASS（sandbox 外精確重跑） | 0 | 26,463.350 ms |

執行格式：

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File <test-file>`

### 關鍵原始輸出

`test_queue_active_index.ps1`：

```text
queue_active_index_status=passed
missing_index_rebuild_logged=true
scan_metrics_logged=true
fixture_cleanup_confirmed=True
```

`test_queue_failure_containment.ps1`：

```text
queue_failure_containment_status=passed
claude_to_codex_fallback=true
bounded_attempts_per_route=2
independent_task_continued=true
```

`test_queue_reason_propagation.ps1`：

```text
queue_reason_propagation_status=passed
dispatcher_failure_contained=true
status=queue_scan detail=scan_ms=1760.1 directory_count=507 scoped_task_count=2 index_rebuilds=1
```

`test_dispatch_resilience.ps1`：

```text
dispatch_resilience_status=passed
case_count=6
timeout_elapsed_seconds=5
```

## 環境事件

`test_dispatch_resilience.ps1` 在 workspace sandbox 內首跑失敗，原始錯誤為：

```text
Test-Path : Access is denied
exit_code=1
elapsed_ms=33905.477
```

此為 sandbox 權限錯誤；依執行規範使用完全相同的精確測試命令在 sandbox 外重跑，結果 PASS。此事件不隱藏，亦未把首跑誤記為成功。

## Benchmark 驗收

本輪未重跑 benchmark。`OUTPUTS\BENCHMARK_RESULT.json` 已包含 1x／3x／10x 各 20 輪原始數字與 nearest-rank p95；結果分別為：

- 1x：227.880 ms → 121.144 ms（1.88x）
- 3x：665.413 ms → 366.160 ms（1.82x）
- 10x：2,210.726 ms → 1,124.007 ms（1.97x）

Benchmark fixture 的 artifact 路徑目前不存在，且 `%TEMP%\AgentOS-queue-benchmark-*` 殘留數為 0，`cleanup_executed=true`。

## 已知限制

Per-file staleness 僅涵蓋已在目前 root scope 內的檔案。無目錄新增／刪除時，若手動修改既有 `TASK.md` 的 `parent_dispatch_id`、`revision_of` 或 `source_dispatch_id`，使其跨 root 重新掛載，需等下一次全量 rebuild 才會被發現；本輪依工單要求記錄但不修正。

## Independent Verify

verdict: PASS

驗證結果：成功

全新 read-only Codex Verify session 逐條判定 AC1-5：

- AC1：達成。三處主迴圈呼叫均透過可重建索引，缺 index 重建有明確事件。
- AC2：達成。程式與實際 `task-queue.log` 均含三項 scan metrics。
- AC3：達成。Verifier 從 artifact 的各 20 輪原始數字重新計算 nearest-rank p95，與報告完全一致。
- AC4：達成。三支指定回歸測試具本輪新鮮 PASS 證據；sandbox 首次權限失敗及精確重跑已揭露。
- AC5：達成。Verifier 在全新 session 以 read-only 治理檢查完成獨立盲審。

Verifier 統計：已達成 5、未達成 0、無法驗證 0。

非阻斷 caveat：

- p95 改善為 1.82-1.97x；Acceptance Criteria 沒有設定至少 3x 的改善門檻。
- 跨-root metadata 手動重掛需等待全量 rebuild。
- 治理狀態是 `operational_review_required`，不可宣稱 production-ready。

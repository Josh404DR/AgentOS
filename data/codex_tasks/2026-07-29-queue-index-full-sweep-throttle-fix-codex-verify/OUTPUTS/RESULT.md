# AgentOS Dispatch Result

dispatch_id: 2026-07-29-queue-index-full-sweep-throttle-fix-codex-verify
route_to: Codex
codex_mode: verify
governance_version: 1.3.0
governance_hash: 0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1
status: completed
models_invoked: true
scripts_executed: true
cleanup_executed: false
dry_run: false
review_dispatch_id: not_created

## Findings

verify_verdict: PASS

發現：未發現阻斷問題，全部驗收條件成立。

證據：

- 治理雜湊吻合。
- 三個檔案獨立 parser 檢查皆為 0 errors，SHA-256 與測試證據一致。
- 節流、啟動 full sweep、三種 re-parenting 欄位及增量重建均有覆蓋。
- 1x/3x/10x p95 改善為 `2.10/2.59/2.04`，優於指定比較值。
- 三項既有 regression tests 均為 exit code 0。
- `evidence_manifest_mismatch: false`。

必要變更：無。

## Caveats

none
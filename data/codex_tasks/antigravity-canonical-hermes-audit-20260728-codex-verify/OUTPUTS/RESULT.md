# AgentOS Dispatch Result

dispatch_id: antigravity-canonical-hermes-audit-20260728-codex-verify
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

 findings：六項驗收條件均有對應實作與證據，未發現阻斷問題。

 evidence：治理雜湊一致；scoped diff 非空；離線回歸測試分別為 7/7 與 9/9 通過；成功、失敗、timeout、Builder Verify 條件、artifact diff 範圍及 Hermes 稽核皆有紀錄；`evidence_manifest_mismatch: false`。

 required changes：無。

## Caveats

none
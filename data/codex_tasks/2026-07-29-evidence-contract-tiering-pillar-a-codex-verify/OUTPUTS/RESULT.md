# AgentOS Dispatch Result

dispatch_id: 2026-07-29-evidence-contract-tiering-pillar-a-codex-verify
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

 findings:
- Evidence Contract 分級、16/7 欄位及 Phase 1 WARNING 規則符合驗收條件。
- 腳本正確採用 full 優先、衝突時不降級。
- 未發現範圍外修改證據。

evidence:
- PowerShell AST：`parser_errors=0`
- 交付測試：結構案例 10/10、端對端案例 2/2。
- 獨立抽查確認 full/lightweight、缺欄、placeholder、`unknown` 與 `not_applicable` 行為。
- Git 顯示僅兩個允許檔案為 modified。
- `evidence_manifest_mismatch: false`

required_changes:
- 無。
- 注意：`git_verified_snapshot: not_found`，且兩檔含已揭露的既有 working-tree 差異；本次判定限於 focused scoped diff。

## Caveats

none
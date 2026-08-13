# AgentOS Dispatch Result

dispatch_id: 2026-08-10-hermes-lite-phase1-rag-evidence-mvp-child-02-evidence-precedence
route_to: Codex
codex_mode: build
governance_version: 1.4.0
governance_hash: 759F5EE67C5706DD7BF9B193913DFA6B6EEF03292FC0B8FA264F40A9A9E146D2
status: completed
models_invoked: true
scripts_executed: true
cleanup_executed: false
dry_run: false
review_dispatch_id: 2026-08-10-hermes-lite-phase1-rag-evidence-mvp-child-02-evidence-precedence-codex-verify

## Findings

已完成 G1 工單證據優先序實作，狀態為 `implemented_pending_independent_verify`，未自稱 verified。

主要成果：

- 實作 `VERIFY_RESULT > TEST_RESULT > RESULT.verified` 優先序。
- 同一工單的五種 artifacts 視為同一邏輯實體。
- 輸出包含：
  - `final_status`
  - `source_of_truth`
  - `external_label`
  - 組合說明
  - `evidence_paths`
  - `field_sources`
  - `governance_status`
- `VERIFY_BUNDLE.md` 和 `DELIVERY.md` 不會被誤當成驗證結論。
- Builder self-check PASS 只會得到 `locally_verified`，不會升格為 independent verified。
- VERIFY_RESULT 欄位矛盾、解析異常或時間逆序均 fail closed，回傳 `review_required`。
- `verified_at` 只有日期時按 Asia/Taipei 日期精度比較，不臆造午夜時間；完整 timestamp 才進行秒級比較。
- `learning-candidate-dedupe-fix-20260721` 三題回歸均解析為：
  - `final_status=verified_pass`
  - `external_label=verified_by_codex`
  - `source_of_truth=OUTPUTS/VERIFY_RESULT.md`
  - 同時保留 RESULT 與 VERIFY_RESULT evidence paths。

驗證證據：

- 治理 gate：PASS。
- 標準庫確定性 self-check：`PASS cases=8`。
- Python 語法編譯：`PASS files=2`。
- `model_calls=0`、`token_actual=0`。
- pytest 尚未執行：sandbox Python shim 無法啟動；可用的 Python 3.13 未安裝 pytest。依治理未擅自安裝套件。
- 已產出 [RESULT.md](E:/AgentOS/data/codex_tasks/2026-08-10-hermes-lite-phase1-rag-evidence-mvp-child-02-evidence-precedence/OUTPUTS/RESULT.md)、[TEST_RESULT.md](E:/AgentOS/data/codex_tasks/2026-08-10-hermes-lite-phase1-rag-evidence-mvp-child-02-evidence-precedence/OUTPUTS/TEST_RESULT.md) 與 [VERIFY_BUNDLE.md](E:/AgentOS/data/codex_tasks/2026-08-10-hermes-lite-phase1-rag-evidence-mvp-child-02-evidence-precedence/OUTPUTS/VERIFY_BUNDLE.md)。
- 尚需由不同的全新、read-only Codex Verify session 執行獨立驗證。
- workspace 既有 `operational_review_required` drift 未納入或修改，亦未宣稱 production-ready。

changed_file: tools/hermes_lite_knowledge/evidence.py  
changed_file: tools/hermes_lite_knowledge/__init__.py  
changed_file: tests/hermes_lite_knowledge/test_evidence_precedence.py  
changed_file: data/codex_tasks/2026-08-10-hermes-lite-phase1-rag-evidence-mvp-child-02-evidence-precedence/OUTPUTS/RESULT.md  
changed_file: data/codex_tasks/2026-08-10-hermes-lite-phase1-rag-evidence-mvp-child-02-evidence-precedence/OUTPUTS/TEST_RESULT.md  
changed_file: data/codex_tasks/2026-08-10-hermes-lite-phase1-rag-evidence-mvp-child-02-evidence-precedence/OUTPUTS/VERIFY_BUNDLE.md  
changed_file: data/metrics/METRICS_LOG.jsonl  
change_required: true

## Caveats

none
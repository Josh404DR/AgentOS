# Learning Candidate Governance Dedupe Fix Result

dispatch_id: learning-candidate-dedupe-fix-20260721
task_status: implemented_pending_fresh_verify
builder_self_check: PASS
verified: false
verify_level: full_blind_verify(core_script, escalation index writer)
governance_version: 1.3.0
governance_hash: 0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1

## Root Cause 與選擇方案

根因位於 `scripts\collect_learning_candidates.ps1`：舊版第 186–201 行只從 `LEARNING_CANDIDATE_INDEX.jsonl` 載入 `dedupe_key`；但 governance 分支舊版第 326–333 行寫入 `ESCALATION_INDEX.jsonl` 時沒有 `dedupe_key`。因此 governance candidate 雖然當次記入記憶體 HashSet，下次 process 啟動仍無法恢復。

本單採方案 **(a)**：

- 第 202–217 行同時掃描 `$EscalationIndexPath`，載入 `task_id` 與可用的 `dedupe_key`。
- 第 359 行把 `$dedupeKey` 寫進 governance escalation index entry。
- 不向一般 `$candidateIndexPath` 寫 governance metadata，避免 canonical index 來源重疊。

## 第二層防線

第 323–333 行在寫入前檢查：

- `$existingEscalationTaskIds` 已含相同 `task_id`；或
- `$escDir` 已存在任何 `*.json` 事件。

任一成立即輸出 `skip_duplicate ... reason=existing_escalation_task_or_event`，不新增事件檔或 index 行。

## 實際變更

- `scripts\collect_learning_candidates.ps1`
- `tests\learning_collector\test_governance_dedupe.ps1`（新增）
- `scripts\agentos_ci_smoke.ps1`（只新增 `learning_governance_dedupe` gate；檔案其他既有 drift 不屬本單）
- 本目錄四份交付 artifact。

## 歷史證據未變

- 目錄：6
- JSON 事件檔：228（6×38）
- 排序後 `relative_path|SHA256` manifest SHA-256：`DA5DDB05AE83AEEA67A24DC0EB9064E651F1D4FD777FFEEA9FE98A28639D8740`
- `ESCALATION_INDEX.jsonl` SHA-256：`C29B04730045E23B82A4536A17B3E7A4BFB51D08ACE3534CD5BBCD231D5E6FFC`
- `ESCALATION_INDEX.jsonl` 長度：86804 bytes

修改前後上述數值完全一致。

## 未解狀態

- full blind Codex Verify 尚未執行，因此本單不得標記 verified 或正式 PASS。
- workspace governance 仍為 `operational_review_required`，不可宣稱 production-ready。

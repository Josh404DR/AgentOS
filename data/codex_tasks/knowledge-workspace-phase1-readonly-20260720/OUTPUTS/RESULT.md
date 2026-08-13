# Knowledge Workspace Phase 1 Delivery Result

dispatch_id: knowledge-workspace-phase1-readonly-20260720
task_status: completed
builder: Codex Builder
governance_version: 1.3.0
governance_hash: 0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1
verify_level: full_blind_verify_required
verified: true
verify_verdict: PASS
verify_thread_id: 019f7f11-6612-7792-a9b4-3a4e74eace29
models_invoked: false
external_services_invoked: false

## 實際變更

- 新增 `dashboard/backend/knowledge_workspace.py`：SQLite FTS5 trigram 衍生索引、opaque artifact refs、folder id／dispatch id 映射、schema migration、stat-only incremental check、週期性 deterministic reconciliation、stale/projection metadata。
- `dashboard/backend/main.py`：新增 `/api/v1/today`、knowledge list/search/detail/artifact 與隔離 discussion/feedback/candidate API；既有 task/workflow refresh 改讀衍生索引。
- discussion/feedback 僅 append 到 `data/knowledge_discussions/`；candidate 僅輸出到 `data/knowledge_candidates/`，不派工、不 publish、不修改 TASK／ADR／治理／Knowledge Pool。
- discussion 寫入沿用 Phase 0 loopback、Origin、owner session、CSRF 與 actor audit；既有 domain mutation flag 保持預設 off。
- 新增 Dashboard「今日」「知識」頁、繁中搜尋、節點詳情、來源檢視及討論 UI。
- Today 完整分類：browser-local persistent 未讀完成、需要 Josh、失敗可恢復、待處理 feedback、草稿 candidate、最近知識。
- Telegram knowledge feedback 新增本機 Dashboard deep link。
- CI 新增 knowledge workspace gate，並修正 Dashboard／Knowledge Pool scope 說明。
- 索引 source signature 改為只追蹤實際被 projection 消費的 canonical artifacts，不再遞迴掃描歷史工單內的圖片、log 與任意巢狀檔；無關檔案不觸發重建，canonical 輸入變更仍會觸發 reconciliation。
- 新增 `CONTEXT_HANDOFF.md`，明確記錄 Phase 1 scope、不可執行的 publish/promotion 邊界與 fresh Verify 隔離要求。

## 驗證證據

- `python -m unittest tests/test_knowledge_workspace.py tests/test_dashboard_security.py tests/test_url_knowledge_intake.py tests/test_knowledge_relations.py`: `Ran 30 tests ... OK`。
- root-cause revision focused suite：`Ran 38 tests ... OK`；含 Today contract、junction、reparse、hard-link isolation 與 canonical-only source signature。
- `npm.cmd run build`: Next.js production build、TypeScript、static generation 全部 PASS。
- `python -m py_compile`: backend、knowledge module、Hermes plugin PASS。
- CI smoke revision 2: `data/ci_health/ci-smoke-20260720-174415.md`，`fail_count=0`；`knowledge_workspace=PASS`（16 tests，含 NTFS junction 與 hard link）、`dashboard_security=PASS`、`url_knowledge_security=PASS`、`dispatch_resilience=PASS`。整體 WARN 來自既有 Hermes autostart/runtime receipt 狀態與刻意跳過外部 model CLI，不是本工單 gate failure。
- 實機 API：`ui=200`；繁中「知識庫」與兩字查詢「知識」都找到 1354；detail 包含 `knowledge_node,task,result,claude_review,source_json`；`source_url_present=true`、`notebooklm=pending_retry`、`stale=false`。
- 實機瀏覽器：deep link 直接開啟 1354；繁中搜尋後 1354 排名第一；source_json viewer 顯示 source content 與 SHA-256；「今日」頁同時列出最近知識與工單。
- refresh before/after：canonical task tree 現有 7,631 files／383 folders；舊 `/api/tasks` 每次呼叫 `_list_codex_tasks()` 掃目錄與 artifacts，現改為 SQLite read。測試連續 5 次 list/detail 後 `scan_count` 不變；實機 10 次 `/api/tasks` 平均 151 ms（min 104／max 325 ms）。
- rebuild：刪除測試 DB 後可重建且 canonical hashes 不變；實機 `reconcile={updated:false}`。
- real-tree disaster rebuild：394 tasks／29 nodes，`elapsed_seconds=1.981`；抽查 AGENTS、1354 TASK/RESULT/source/node 共 5 個 canonical SHA-256，`canonical_hashes_changed=0`。驗證 DB 僅寫入 derived index 目錄。
- NotebookLM logged out/pending 不阻擋本機搜尋、詳情或隔離 discussion。

## Artifact 路徑

- `E:\AgentOS\data\codex_tasks\knowledge-workspace-phase1-readonly-20260720\OUTPUTS\RESULT.md`
- `E:\AgentOS\data\codex_tasks\knowledge-workspace-phase1-readonly-20260720\OUTPUTS\SELF_CHECK.md`
- `E:\AgentOS\data\ci_health\ci-smoke-20260720-174415.md`
- `E:\AgentOS\data\ci_health\ci-smoke-20260720-174415.json`
- `E:\AgentOS\data\dashboard_index\knowledge_workspace.sqlite3`（derived；可重建且 gitignored）
- `E:\AgentOS\data\codex_tasks\knowledge-workspace-phase1-readonly-20260720\CONTEXT_HANDOFF.md`

## 未解風險

- fresh Verify attempt 1 找到 junction escape；attempt 2 找到 hard-link append escape；attempt 3 找到 Today 分類缺口；attempt 4 的 AC1–3、5–8 均 PASS，但真實全量重建超過 180 秒。根因為 source signature 遞迴掃描不被索引使用的檔案，現已修正並以 1.981 秒真實重建佐證；仍須 fresh Verify，因此目前不得宣稱正式 PASS／production-ready。
- CI smoke 的 Hermes autostart 與 runtime receipt 既有 WARN 不在 Phase 1 scope；model CLI 依資料邊界刻意未呼叫。
- 現階段 relation 僅顯示 `similarity_score` 與 suggested/not-confirmed 標記，未做知識升格或人工確認。

## 下一步

- Phase 1 已由全新 read-only Codex Verify 對九條 acceptance criteria 出具嚴格 PASS。後續 promotion、publish、完整 discussion lifecycle 與 NotebookLM 寫入仍屬 Phase 2/3，需另開工單授權。

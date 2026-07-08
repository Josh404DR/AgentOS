# Legacy Batch Migration Report

- generated_at: 2026-06-29 22:11 Asia/Taipei
- generated_by: antigravity (batch migration agent)
- report_type: legacy_batch_migration_report
- not_a_knowledge_node: true
- do_not_upload_to_notebooklm: true
- pilot_node_excluded: legacy-20260624-addy-osmani-agent-skills (completed in prior session)
- batch_total: 11 nodes

---

## 摘要

| 類別 | 數量 |
|---|---|
| intake 成功（fetch_status=success） | 11 / 11 |
| Codex 完成（codex_execution_status=completed） | 11 / 11 |
| Claude 審查通過（PASS 或 PASS_WITH_CAVEATS） | 9 / 11 |
| Claude 審查失敗（FAIL） | 2 / 11 |
| Knowledge Node 更新成功（migration_status=migrated） | 9 / 11 |
| Knowledge Node blocked（FAIL） | 2 / 11 |
| 重複節點 | 0 |
| NotebookLM 上傳 | 0（本次不執行） |

---

## 各節點詳細記錄

### 1. baidu-unlimited-ocr ✅ MIGRATED

| 欄位 | 值 |
|---|---|
| dispatch_id | legacy-20260624-baidu-unlimited-ocr |
| source_url | https://www.threads.net/@aimalaysia/post/DZ8g7oRAa3k |
| fetch_status | success |
| Codex status | completed |
| Claude status | PASS_WITH_CAVEATS |
| node update status | migrated |
| duplicate status | false |
| NotebookLM eligibility | ready_to_upload（本次未上傳） |
| knowledge_fingerprint | dcd16fd780ee7adebd265137122d190f63412a02f05070321f233989b6d8193a |

**evidence paths:**
- `E:\AgentOS\data\url_intake\legacy-20260624-baidu-unlimited-ocr\`
- `E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-baidu-unlimited-ocr\OUTPUTS\RESULT.md`
- `E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-baidu-unlimited-ocr\OUTPUTS\CLAUDE_REVIEW.md`
- `E:\AgentOS\data\knowledge_pool\2026-06-24-baidu-unlimited-ocr.md`

**caveats:** 相對時間戳（5 天前）未固化；介面數字無防護；圖片未分析；canonical URL 歸屬未驗證。

---

### 2. bazi-mcp-server ❌ BLOCKED

| 欄位 | 值 |
|---|---|
| dispatch_id | legacy-20260624-bazi-mcp-server |
| source_url | https://www.threads.net/@kings_man_daily/post/DZ7bSywk_Y0 |
| fetch_status | success |
| Codex status | completed |
| Claude status | **FAIL** |
| node update status | **blocked** |
| duplicate status | not applicable |
| NotebookLM eligibility | blocked_source_mismatch |
| knowledge_fingerprint | (none — blocked) |

**blocked_reason:** source_mismatch — 抓取的 URL 返回 `@wu_ryan_tw` 的 ClaudeCode 占卜網站貼文，而非 bazi-mcp 內容。Claude Inspector 判定主題根本不符（FAIL）。節點原始內容未修改。

**evidence paths:**
- `E:\AgentOS\data\url_intake\legacy-20260624-bazi-mcp-server\`
- `E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-bazi-mcp-server\OUTPUTS\RESULT.md`
- `E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-bazi-mcp-server\OUTPUTS\CLAUDE_REVIEW.md`

**建議後續行動:** 重新對 `https://github.com/openfate-ai/bazi-mcp` 發起正確來源 intake，或調查 `@kings_man_daily` 與原始 dispatch 的對應關係。

---

### 3. calesthio-cicd-tool ❌ BLOCKED

| 欄位 | 值 |
|---|---|
| dispatch_id | legacy-20260624-calesthio-cicd-tool |
| source_url | https://www.threads.net/@ien_vision/post/DZ9FXUklCdr |
| fetch_status | success |
| Codex status | completed |
| Claude status | **FAIL** |
| node update status | **blocked** |
| duplicate status | not applicable |
| NotebookLM eligibility | blocked_source_mismatch |
| knowledge_fingerprint | (none — blocked) |

**blocked_reason:** topic_mismatch — 原節點描述 Calesthio 為 CI/CD 工具，但抓取內容描述的是「World's first open-source agentic video production system」（12 pipelines、52 tools、500+ agent skills）。Star count 匹配（3592）但用途完全不同。Claude Inspector 判定 FAIL。節點原始內容未修改。

**evidence paths:**
- `E:\AgentOS\data\url_intake\legacy-20260624-calesthio-cicd-tool\`
- `E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-calesthio-cicd-tool\OUTPUTS\RESULT.md`
- `E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-calesthio-cicd-tool\OUTPUTS\CLAUDE_REVIEW.md`

**建議後續行動:** 確認 `@ien_vision/post/DZ9FXUklCdr` 是否為原始 source_url；若不正確，須更正後重新發起 intake。

---

### 4. claude-code-resume ✅ MIGRATED

| 欄位 | 值 |
|---|---|
| dispatch_id | legacy-20260624-claude-code-resume |
| source_url | https://www.threads.net/@_kylinwin/post/DZ6f9rlkiCV |
| fetch_status | success |
| Codex status | completed |
| Claude status | PASS_WITH_CAVEATS |
| node update status | migrated |
| duplicate status | false |
| NotebookLM eligibility | ready_to_upload（本次未上傳） |
| knowledge_fingerprint | c6369a1c3931a9c6cc35a4a1ee580324f3a5af3c1a0660df986d8116c4a53657 |

**evidence paths:**
- `E:\AgentOS\data\url_intake\legacy-20260624-claude-code-resume\`
- `E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-claude-code-resume\OUTPUTS\RESULT.md`
- `E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-claude-code-resume\OUTPUTS\CLAUDE_REVIEW.md`
- `E:\AgentOS\data\knowledge_pool\2026-06-24-claude-code-resume.md`

**caveats:** 功能清單來自 GitHub repo 自述未獨立驗證；「行動遠端控制」為強力聲明；圖片未分析。

---

### 5. hermes-starter-pack ✅ MIGRATED

| 欄位 | 值 |
|---|---|
| dispatch_id | legacy-20260624-hermes-starter-pack |
| source_url | https://www.threads.net/@krumjahn/post/DZ7NMWglCjV |
| fetch_status | success |
| Codex status | completed |
| Claude status | PASS_WITH_CAVEATS |
| node update status | migrated |
| duplicate status | false |
| NotebookLM eligibility | ready_to_upload（本次未上傳） |
| knowledge_fingerprint | 102a2eea5f5e95fd4d62b614abde5616f6d381cc6317ffaaecd5641e3d8a6793 |

**evidence paths:**
- `E:\AgentOS\data\url_intake\legacy-20260624-hermes-starter-pack\`
- `E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-hermes-starter-pack\OUTPUTS\RESULT.md`
- `E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-hermes-starter-pack\OUTPUTS\CLAUDE_REVIEW.md`
- `E:\AgentOS\data\knowledge_pool\2026-06-24-hermes-starter-pack.md`

**caveats:** canonical URL 為 dub.sh 短網址（目的地未知）；Hermes 指涉與 AgentOS 本地生態關係未消歧義；圖片未分析。

---

### 6. insane-search-tool ✅ MIGRATED

| 欄位 | 值 |
|---|---|
| dispatch_id | legacy-20260624-insane-search-tool |
| source_url | https://www.threads.net/@gptaku_ai/post/DZ7mN16k7Bn |
| fetch_status | success |
| Codex status | completed |
| Claude status | PASS_WITH_CAVEATS |
| node update status | migrated |
| duplicate status | false（相關但不重複：trinity 主題由 3 個不同節點覆蓋） |
| NotebookLM eligibility | ready_to_upload（本次未上傳） |
| knowledge_fingerprint | 2f9c3f6c31633bed8665b2617052511870971e9518605eb9f7e4707157202c09 |

**evidence paths:**
- `E:\AgentOS\data\url_intake\legacy-20260624-insane-search-tool\`
- `E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-insane-search-tool\OUTPUTS\RESULT.md`
- `E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-insane-search-tool\OUTPUTS\CLAUDE_REVIEW.md`
- `E:\AgentOS\data\knowledge_pool\2026-06-24-insane-search-tool.md`

**caveats:** 抓取來源為社群貼文，非 Canonical GitHub；「bypass tool」定性未捕捉（安全相關）；圖片未分析；canonical_verified: false。

---

### 7. lazycodex-research-tool ✅ MIGRATED

| 欄位 | 值 |
|---|---|
| dispatch_id | legacy-20260624-lazycodex-research-tool |
| source_url | https://www.threads.net/@yeon.gyu.kim/post/DZ6UWZHEkCH |
| fetch_status | success |
| Codex status | completed |
| Claude status | PASS_WITH_CAVEATS |
| node update status | migrated |
| duplicate status | false（相關但不重複：trinity 主題） |
| NotebookLM eligibility | ready_to_upload（本次未上傳） |
| knowledge_fingerprint | 031979041932b95c5e4ca0a1b41274e4bda253a9db0f5012e15f65b0262d5176 |

**evidence paths:**
- `E:\AgentOS\data\url_intake\legacy-20260624-lazycodex-research-tool\`
- `E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-lazycodex-research-tool\OUTPUTS\RESULT.md`
- `E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-lazycodex-research-tool\OUTPUTS\CLAUDE_REVIEW.md`
- `E:\AgentOS\data\knowledge_pool\2026-06-24-lazycodex-research-tool.md`

**caveats:** Canonical GitHub 未直接抓取；圖片未分析；功能聲明為社群評價。

---

### 8. odin-engineio-case-study ✅ MIGRATED

| 欄位 | 值 |
|---|---|
| dispatch_id | legacy-20260624-odin-engineio-case-study |
| source_url | https://www.threads.net/@killkli/post/DZ8hpWqEmkh |
| fetch_status | success |
| Codex status | completed |
| Claude status | PASS_WITH_CAVEATS |
| node update status | migrated |
| duplicate status | false |
| NotebookLM eligibility | ready_to_upload（本次未上傳） |
| knowledge_fingerprint | 5c573884fc2ad2d5632ac6ce27906942cc2bfc69b17cceb7dfecf86945faa3af |

**evidence paths:**
- `E:\AgentOS\data\url_intake\legacy-20260624-odin-engineio-case-study\`
- `E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-odin-engineio-case-study\OUTPUTS\RESULT.md`
- `E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-odin-engineio-case-study\OUTPUTS\CLAUDE_REVIEW.md`
- `E:\AgentOS\data\knowledge_pool\2026-06-24-odin-engineio-case-study.md`

**caveats:** 開發時程與 binary 大小為作者自述；圖片未分析。

---

### 9. openhands-software-agent-sdk ✅ MIGRATED

| 欄位 | 值 |
|---|---|
| dispatch_id | legacy-20260624-openhands-software-agent-sdk |
| source_url | https://www.threads.net/@dooo.sth.design/post/DZ8IZ3uDwSf |
| fetch_status | success |
| Codex status | completed |
| Claude status | PASS_WITH_CAVEATS |
| node update status | migrated |
| duplicate status | false |
| NotebookLM eligibility | ready_to_upload（本次未上傳） |
| knowledge_fingerprint | 54c3e1ab997e460defc37aed3f5d44cbbcd493de969da5916ec71af68785f4b1 |

**evidence paths:**
- `E:\AgentOS\data\url_intake\legacy-20260624-openhands-software-agent-sdk\`
- `E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-openhands-software-agent-sdk\OUTPUTS\RESULT.md`
- `E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-openhands-software-agent-sdk\OUTPUTS\CLAUDE_REVIEW.md`
- `E:\AgentOS\data\knowledge_pool\2026-06-24-openhands-software-agent-sdk.md`

**⚠️ 重要警示:** Codex 輸出中「可搭配 OpenClaw」一句被 Claude Inspector 標記為疑似幻覺（hallucination）。已在節點中明確標注，不得作為事實引用，建議人工審查後再 NotebookLM 消費。

---

### 10. slides-grab-tool ✅ MIGRATED

| 欄位 | 值 |
|---|---|
| dispatch_id | legacy-20260624-slides-grab-tool |
| source_url | https://www.threads.net/@bunniesossdev/post/DZ6UirAE3V7 |
| fetch_status | success |
| Codex status | completed |
| Claude status | PASS_WITH_CAVEATS |
| node update status | migrated |
| duplicate status | false（与 insane-search 和 lazycodex 主題相關但不同貼文） |
| NotebookLM eligibility | ready_to_upload（本次未上傳） |
| knowledge_fingerprint | bb71b189b765d944bbfb95c7d4f71bd96cdb5c85cf0f0fbe0abe07a55bb14670 |

**evidence paths:**
- `E:\AgentOS\data\url_intake\legacy-20260624-slides-grab-tool\`
- `E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-slides-grab-tool\OUTPUTS\RESULT.md`
- `E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-slides-grab-tool\OUTPUTS\CLAUDE_REVIEW.md`
- `E:\AgentOS\data\knowledge_pool\2026-06-24-slides-grab-tool.md`

**caveats:** slides-grab 工具本身特定性嚴重不足（結果以 trinity 描述為主）；Claude 建議後續補抓 GitHub README。

---

### 11. yuri-relay-shortener ✅ MIGRATED

| 欄位 | 值 |
|---|---|
| dispatch_id | legacy-20260624-yuri-relay-shortener |
| source_url | https://www.threads.net/@yuri.learns/post/DZ7CAIGifhC |
| fetch_status | success |
| Codex status | completed |
| Claude status | PASS_WITH_CAVEATS |
| node update status | migrated |
| duplicate status | false |
| NotebookLM eligibility | ready_to_upload（本次未上傳） |
| knowledge_fingerprint | 311f8de59e9510f04163470dffa7c4a822132a57211c4d7c34896a818448c0da |

**evidence paths:**
- `E:\AgentOS\data\url_intake\legacy-20260624-yuri-relay-shortener\`
- `E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-yuri-relay-shortener\OUTPUTS\RESULT.md`
- `E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-yuri-relay-shortener\OUTPUTS\CLAUDE_REVIEW.md`
- `E:\AgentOS\data\knowledge_pool\2026-06-24-yuri-relay-shortener.md`

**caveats:** canonical_url = not_available（GitHub URL 未從貼文中取得，可能在未分析的圖片中）；所有技術聲明均為作者自述。

---

## 去重分析

### trinity 節點（lazycodex / insane-search / slides-grab）

這三個節點的 Codex RESULT 均提及「三位一體」組合，但：

| 節點 | source_url | 貼文作者 | canonical_url |
|---|---|---|---|
| lazycodex | threads.net/@yeon.gyu.kim/... | yeon.gyu.kim | github.com/code-yeongyu/lazycodex |
| insane-search | threads.net/@gptaku_ai/... | gptaku_ai | github.com/fivetaku/insane-search |
| slides-grab | threads.net/@bunniesossdev/... | bunniesossdev | github.com/NomaDamas/slides-grab |

三者 source URL 不同、canonical URL 不同、knowledge_fingerprint 不同 → **不構成重複**。已在各節點的 Duplicate Relationship 章節互相引用說明。

### 其他節點

無任何兩個節點共享相同 canonical_url 或 knowledge_fingerprint。

---

## 邊界聲明

- 本批次未執行 NotebookLM Live upload。
- 本批次未刪除 any 原始檔案。
- 所有 blocked 節點的原始 Knowledge Pool 內容完整保留。
- 未捏造 any Codex 分析 or Claude Review.
- 未修改非 Knowledge Pool 相關檔案。
- 所有檔案均以 UTF-8 NoBOM 寫入。

---

## 後續建議

| 優先級 | 項目 |
|---|---|
| 🔴 HIGH | bazi-mcp-server：重新對正確 URL 發起 intake |
| 🔴 HIGH | calesthio-cicd-tool：確認正確 source_url 後重新 intake |
| 🟡 MEDIUM | insane-search：「bypass tool」安全定性需 GitHub 核實 |
| 🟡 MEDIUM | openhands：「OpenClaw」幻覺需人工確認後再 NotebookLM 消費 |
| 🟡 MEDIUM | yuri：從 image_01.jpg 視覺分析嘗試取得 GitHub URL |
| 🟢 LOW | slides-grab / lazycodex / insane-search：補抓 Canonical GitHub README |
| 🟢 LOW | 所有節點：補做圖片視覺分析（11 個節點有 visual_analysis: pending） |

---

## Post-Verification Addendum

- reconciled_at: 2026-06-29 22:31 Asia/Taipei
- description: Re-evaluated all Knowledge Nodes under strict 12-point NotebookLM Upload Eligibility policies, and performed the approved live sync for eligible nodes.
- pilot_node_included: `legacy-20260624-addy-osmani-agent-skills` has been validated, corrected, and fully migrated into the pool (bringing the total Knowledge Nodes count to 13).
- sync_execution: Successfully uploaded all 5 eligible nodes (`addy-osmani-agent-skills`, `baidu-unlimited-ocr`, `claude-code-resume`, `lazycodex-research-tool`, `odin-engineio-case-study`) to NotebookLM (Notebook ID: `79ef4683-f7d2-43da-b8d3-7298858949e5`). Status values updated to `uploaded` on disk.
- key_adjustments: 5 nodes containing high-risk caveats or hallucinations (such as OpenClaw in `openhands`, unverified short URL in `hermes`, block bypass in `insane-search`, general trinity focus in `slides-grab`, and missing canonical link in `yuri`) have been isolated to `review_required` and excluded from sync.
- reference_document: Detailed assessment and metrics are recorded in `NOTEBOOKLM_ELIGIBILITY_REPORT.md`.

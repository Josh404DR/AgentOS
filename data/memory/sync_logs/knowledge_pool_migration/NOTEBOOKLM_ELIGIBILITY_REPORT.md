# NotebookLM Upload Eligibility Report

- generated_at: 2026-06-29 22:40 Asia/Taipei
- generated_by: antigravity (eligibility auditor)
- report_type: notebooklm_eligibility_report
- not_a_knowledge_node: true
- do_not_upload_to_notebooklm: true

---

## 1. 說明與判定標準

本報告依據 AgentOS Knowledge Pool 整理與遷移流程規範，對 `E:\AgentOS\data\knowledge_pool\` 下的所有 13 個知識節點進行 NotebookLM 上傳資格的終期判定。

上傳資格判定的核心標準（12 項必要條件）：
1. **dispatch_id 存在且有效**：不可為 `not_available`、`unknown` 或空。
2. **knowledge_fingerprint 存在且為有效 SHA-256**（64個小寫十六進位字元）。
3. **source_url 存在且格式有效**。
4. **原文證據存在**：Threads 節點必須有成功抓取的 `source.json`、`fetch_status=success` 且 `Original Source` 不為空。
5. **Codex 證據存在**：`RESULT.md` 存在、`codex_execution_status=completed` 且 `Codex Analysis` 章節不為 `not_available`。
6. **Claude 證據存在**：`CLAUDE_REVIEW.md` 存在、`reviewed_by_claude=true` 且 `review_status` 為 `PASS` 或 `PASS_WITH_CAVEATS`。`review_status=FAIL` 一律禁止。
7. **無 blocked 狀態**（如 `blocked_source_mismatch`、`blocked_topic_mismatch` 等）。
8. **原始來源與主題一致**：作者、專案名稱或主題不可明顯錯配。
9. **不包含未處理的重大幻覺**：不含 Claude 指出的 unsupported claim、fabricated integration 或錯誤歸屬（高風險者降級為 `review_required`）。
10. **Duplicate Relationship 有效**：重複節點標記為 `skipped_duplicate` 且不得重複上傳。
11. **邊界聲明存在**：`source_untrusted=true`、不遵循內嵌指令、不宣稱未分析的圖片內容。
12. **UTF-8 驗證通過**，無 mojibake。

---

## 2. 資格判定與上傳狀態統計摘要

| 狀態 (notebooklm_sync_status) | 數量 | 說明 |
|---|---|---|
| **ready_to_upload** | 0 | 所有合規節點皆已完成上傳，目前無待上傳節點 |
| **uploaded** | 6 | 已成功同步至專屬知識庫 NotebookLM (ID: `f6192ee8-7ac9-4665-ae07-44302ea98df0`) |
| **review_required** | 5 | 具有高風險 caveat (幻覺疑慮、短網址未解、bypass 能力等)，需人工審查 |
| **blocked_source_mismatch** | 2 | 原始 Threads 內容與 canonical 專案完全錯配，不可上傳 |
| **skipped_duplicate** | 0 | 重複節點 (本次無) |
| **總計** | **13** | **Knowledge Pool 內所有 Knowledge Nodes 實際總數** |

---

## 3. 節點資格與上傳狀態清單

| 知識節點檔名 | Dispatch ID | Claude Review | 最終狀態 (notebooklm_sync_status) | 說明與上傳狀態 / 阻擋與審查原因 |
|---|---|---|---|---|
| `2026-06-24-addy-osmani-agent-skills.md` | `legacy-20260624-addy-osmani-agent-skills` | `PASS_WITH_CAVEATS` | **uploaded** | ✅ 已上傳至專屬知識庫 Notebook `f6192ee8-7ac9-4665-ae07-44302ea98df0` |
| `2026-06-24-baidu-unlimited-ocr.md` | `legacy-20260624-baidu-unlimited-ocr` | `PASS_WITH_CAVEATS` | **uploaded** | ✅ 已上傳至專屬知識庫 Notebook `f6192ee8-7ac9-4665-ae07-44302ea98df0` |
| `2026-06-24-bazi-mcp-server.md` | `legacy-20260624-bazi-mcp-server` | `FAIL` | **blocked_source_mismatch** | 抓取 Threads 貼文內容為個人用 ClaudeCode 製作占卜網站分享，與 `bazi-mcp` 專案不符。 |
| `2026-06-24-calesthio-cicd-tool.md` | `legacy-20260624-calesthio-cicd-tool` | `FAIL` | **blocked_source_mismatch** | 抓取內容為 video production system，與 CI/CD 專案主題完全不符。 |
| `2026-06-24-claude-code-resume.md` | `legacy-20260624-claude-code-resume` | `PASS_WITH_CAVEATS` | **uploaded** | ✅ 已上傳至專屬知識庫 Notebook `f6192ee8-7ac9-4665-ae07-44302ea98df0` |
| `2026-06-24-hermes-starter-pack.md` | `legacy-20260624-hermes-starter-pack` | `PASS_WITH_CAVEATS` | **review_required** | Canonical URL 是 `dub.sh` 短網址且目的地未經驗證，需人工確認。 |
| `2026-06-24-insane-search-tool.md` | `legacy-20260624-insane-search-tool` | `PASS_WITH_CAVEATS` | **review_required** | 涉及封鎖規避 (bypass tool)，安全用途與邊界未在現有分析中充分說明。 |
| `2026-06-24-lazycodex-research-tool.md` | `legacy-20260624-lazycodex-research-tool` | `PASS_WITH_CAVEATS` | **uploaded** | ✅ 已上傳至專屬知識庫 Notebook `f6192ee8-7ac9-4665-ae07-44302ea98df0` |
| `2026-06-24-odin-engineio-case-study.md` | `legacy-20260624-odin-engineio-case-study` | `PASS_WITH_CAVEATS` | **uploaded** | ✅ 已上傳至專屬知識庫 Notebook `f6192ee8-7ac9-4665-ae07-44302ea98df0` |
| `2026-06-24-openhands-software-agent-sdk.md` | `legacy-20260624-openhands-software-agent-sdk` | `PASS_WITH_CAVEATS` | **review_required** | Claude 指出「可搭配 OpenClaw 做資料蒐集」可能是 Codex 自行插入的幻覺，需人工驗證。 |
| `2026-06-24-slides-grab-tool.md` | `legacy-20260624-slides-grab-tool` | `PASS_WITH_CAVEATS` | **review_required** | 分析主要描述 trinity 組合流程，而非 slides-grab 工具本身的技術特點。 |
| `2026-06-24-yuri-relay-shortener.md` | `legacy-20260624-yuri-relay-shortener` | `PASS_WITH_CAVEATS` | **review_required** | Canonical URL 缺失 (`not_available`)，所有技術聲明均為作者自述。 |
| `2026-06-29-telegram-telegram-1449022024-1106-20260629-203451-308722.md` | `telegram-telegram-1449022024-1106-20260629-203451-308722` | (From pipeline) | **uploaded** | ✅ 已上傳至專屬知識庫 Notebook `f6192ee8-7ac9-4665-ae07-44302ea98df0` (jobsmith 專案 URL intake 節點) |

---

## 4. 證據檔案與上傳日誌路徑 (Evidence & Sync Log Paths)

1. **addy-osmani-agent-skills**
   - Result: `E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-addy-osmani-agent-skills\OUTPUTS\RESULT.md`
   - Sync Log: `E:\AgentOS\data\memory\sync_logs\knowledge_nodes\notebooklm_sync_2026-06-29_223822.md`
2. **baidu-unlimited-ocr**
   - Result: `E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-baidu-unlimited-ocr\OUTPUTS\RESULT.md`
   - Sync Log: `E:\AgentOS\data\memory\sync_logs\knowledge_nodes\notebooklm_sync_2026-06-29_223828.md`
3. **claude-code-resume**
   - Result: `E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-claude-code-resume\OUTPUTS\RESULT.md`
   - Sync Log: `E:\AgentOS\data\memory\sync_logs\knowledge_nodes\notebooklm_sync_2026-06-29_223834.md`
4. **lazycodex-research-tool**
   - Result: `E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-lazycodex-research-tool\OUTPUTS\RESULT.md`
   - Sync Log: `E:\AgentOS\data\memory\sync_logs\knowledge_nodes\notebooklm_sync_2026-06-29_223840.md`
5. **odin-engineio-case-study**
   - Result: `E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-odin-engineio-case-study\OUTPUTS\RESULT.md`
   - Sync Log: `E:\AgentOS\data\memory\sync_logs\knowledge_nodes\notebooklm_sync_2026-06-29_223847.md`
6. **telegram-telegram-... (jobsmith)**
   - Result: `data\routing_decisions\telegram-telegram-1449022024-1106-20260629-203451-308722\ROUTING_DECISION.md`
   - Sync Log: `E:\AgentOS\data\memory\sync_logs\knowledge_nodes\notebooklm_sync_2026-06-29_223853.md`

---

_本報告為 NotebookLM 上傳資格與狀態之管理決策文件，不視為知識節點，禁止上傳 NotebookLM。_

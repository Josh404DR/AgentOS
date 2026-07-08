# Knowledge Pool Audit Report

- generated_at: 2026-06-29 21:00 Asia/Taipei
- generated_by: antigravity (migration agent)
- report_type: read_only_audit
- not_a_knowledge_node: true
- do_not_upload_to_notebooklm: true
- source_path: E:\AgentOS\data\knowledge_pool\

---

## 1. 全部檔案清單（13 個）

| # | 檔名 | 大小 (bytes) | 格式狀態 | dispatch_id | migration_status |
|---|---|---|---|---|---|
| 1 | 2026-06-24-addy-osmani-agent-skills.md | 1505 | ❌ legacy | not_available | legacy_unlinked |
| 2 | 2026-06-24-baidu-unlimited-ocr.md | 1600 | ❌ legacy | not_available | legacy_unlinked |
| 3 | 2026-06-24-bazi-mcp-server.md | 1354 | ❌ legacy | not_available | legacy_unlinked |
| 4 | 2026-06-24-calesthio-cicd-tool.md | 966 | ❌ legacy | not_available | legacy_unlinked |
| 5 | 2026-06-24-claude-code-resume.md | 1321 | ❌ legacy | not_available | legacy_unlinked |
| 6 | 2026-06-24-hermes-starter-pack.md | 992 | ❌ legacy | not_available | legacy_unlinked |
| 7 | 2026-06-24-insane-search-tool.md | 1277 | ❌ legacy | not_available | legacy_unlinked |
| 8 | 2026-06-24-lazycodex-research-tool.md | 1444 | ❌ legacy | not_available | legacy_unlinked |
| 9 | 2026-06-24-odin-engineio-case-study.md | 1313 | ❌ legacy | not_available | legacy_unlinked |
| 10 | 2026-06-24-openhands-software-agent-sdk.md | 1402 | ❌ legacy | not_available | legacy_unlinked |
| 11 | 2026-06-24-slides-grab-tool.md | 1376 | ❌ legacy | not_available | legacy_unlinked |
| 12 | 2026-06-24-yuri-relay-shortener.md | 1340 | ❌ legacy | not_available | legacy_unlinked |
| 13 | 2026-06-29-telegram-telegram-1449022024-1106-20260629-203451-308722.md | 3914 | ⚠️ near-standard | telegram-telegram-1449022024-1106-20260629-203451-308722 | — (has dispatch_id) |

---

## 2. 格式狀態詳細

### 2a. Legacy 節點缺失欄位（12 個，共同問題）

所有 12 個舊格式節點均缺少以下標準欄位：

| 缺少欄位 | 備註 |
|---|---|
| dispatch_id | 無法從現有內容推導，標記 not_available |
| knowledge_fingerprint | 無法計算（需 canonical_url + source text hash），標記 not_available |
| canonical_url | 可從 Source 欄位取得，整理時補入 |
| source_url | 可從 Source 欄位取得 |
| duplicate | 整理後補入 false |
| duplicate_of | 整理後補入空白 |
| codex_result_path | 無對應 Codex 任務，標記 not_available |
| claude_review_path | 無對應 Claude review，標記 not_available |
| reviewed_by_claude | 標記 false |
| notebooklm_sync_status | 標記 blocked_pending_codex_claude |
| created_date | 可從檔名日期取得 (2026-06-24) |
| created_at | 無精確時間，標記 not_verified |
| category | 已有，可從原始 Category 欄位取得 |
| tags | 已有，可從原始 Category 欄位取得 |
| migration_status | 需補入 legacy_unlinked |

缺少章節：

| 缺少章節 | 處置 |
|---|---|
| ## Metadata | 補入所有標準欄位 |
| ## Original Source | 將原始正文內容移入 |
| ## Codex Analysis | 補入 not_available |
| ## Claude Review | 補入 not_available |
| ## Duplicate Relationship | 補入（無重複） |
| ## NotebookLM Status | 補入 blocked_pending_codex_claude |

### 2b. Near-Standard 節點缺失欄位（1 個）

`2026-06-29-telegram-telegram-1449022024-1106-20260629-203451-308722.md`

| 缺少或不完整欄位 | 備註 |
|---|---|
| created_date | 需補入 2026-06-29（從檔名） |
| created_at | 標記 not_verified（無精確時間戳） |
| category | 需補入（從 Codex 分析內容推導：url-intake, github-repo） |
| tags | 需補入（not_verified） |

缺少章節：

| 缺少章節 | 處置 |
|---|---|
| ## Duplicate Relationship | 需補入 |
| ## NotebookLM Status | 需補入（已有 notebooklm_sync_status: uploaded 欄位） |

---

## 3. dispatch_id 關聯

| 節點 | dispatch_id | 狀態 |
|---|---|---|
| 2026-06-24-addy-osmani-agent-skills.md | not_available | legacy_unlinked |
| 2026-06-24-baidu-unlimited-ocr.md | not_available | legacy_unlinked |
| 2026-06-24-bazi-mcp-server.md | not_available | legacy_unlinked |
| 2026-06-24-calesthio-cicd-tool.md | not_available | legacy_unlinked |
| 2026-06-24-claude-code-resume.md | not_available | legacy_unlinked |
| 2026-06-24-hermes-starter-pack.md | not_available | legacy_unlinked |
| 2026-06-24-insane-search-tool.md | not_available | legacy_unlinked |
| 2026-06-24-lazycodex-research-tool.md | not_available | legacy_unlinked |
| 2026-06-24-odin-engineio-case-study.md | not_available | legacy_unlinked |
| 2026-06-24-openhands-software-agent-sdk.md | not_available | legacy_unlinked |
| 2026-06-24-slides-grab-tool.md | not_available | legacy_unlinked |
| 2026-06-24-yuri-relay-shortener.md | not_available | legacy_unlinked |
| 2026-06-29-telegram-telegram-...md | telegram-telegram-1449022024-1106-20260629-203451-308722 | ✅ 有效 dispatch_id |

---

## 4. 重複群組分析

| 判斷依據 | 結果 |
|---|---|
| canonical_url 唯一性 | 所有 13 個節點的 source URL 各不相同，無重複 |
| 內容指紋 | legacy 節點無法計算指紋（無 canonical_url + source text hash pipeline），標記 not_available |
| lazycodex vs insane-search vs slides-grab | 三者共享關聯敘述，但各有獨立 source URL，不構成重複 |
| 結論 | 無重複節點 |

---

## 5. 缺少欄位摘要

| 節點類型 | 數量 | 主要缺失 |
|---|---|---|
| legacy（無 dispatch_id） | 12 | dispatch_id、fingerprint、所有標準章節 |
| near-standard（有 dispatch_id） | 1 | created_at、category、tags、2 個章節 |

---

## 6. 建議的檔名

所有 legacy 節點保留現有檔名（無 dispatch_id 可替換）：

| 現有檔名 | 建議檔名 | 說明 |
|---|---|---|
| 2026-06-24-addy-osmani-agent-skills.md | （不變） | slug 作識別符，無 dispatch_id |
| 2026-06-24-baidu-unlimited-ocr.md | （不變） | 同上 |
| 2026-06-24-bazi-mcp-server.md | （不變） | 同上 |
| 2026-06-24-calesthio-cicd-tool.md | （不變） | 同上 |
| 2026-06-24-claude-code-resume.md | （不變） | 同上 |
| 2026-06-24-hermes-starter-pack.md | （不變） | 同上 |
| 2026-06-24-insane-search-tool.md | （不變） | 同上 |
| 2026-06-24-lazycodex-research-tool.md | （不變） | 同上 |
| 2026-06-24-odin-engineio-case-study.md | （不變） | 同上 |
| 2026-06-24-openhands-software-agent-sdk.md | （不變） | 同上 |
| 2026-06-24-slides-grab-tool.md | （不變） | 同上 |
| 2026-06-24-yuri-relay-shortener.md | （不變） | 同上 |
| 2026-06-29-telegram-telegram-1449022024-1106-20260629-203451-308722.md | （不變） | 已含 dispatch_id |

---

## 7. 腳本影響分析

| 檔案 | 需要的修改 |
|---|---|
| scripts/export_notebooklm_sources.ps1 | 移除 KNOWLEDGE_POOL bundle（lines 128–131） |
| scripts/notebooklm_conveyor.ps1 | 將 line 69 的 `bundle_count: 6` 改為 `bundle_count: 5` |
| docs/NOTEBOOKLM_CONVEYOR.md | 更新 bundle 數量描述（six → five）及 bundle 清單 |
| data/memory/sync_logs/conveyor/*.md | 歷史記錄，**不修改**（保留原始證據） |
| exports/notebooklm_v1/KNOWLEDGE_POOL.md | 下次執行 export_notebooklm_sources.ps1 時自動重建，無需手動修改 |

---

_本報告為管理報告，不視為 Knowledge Node，不得上傳至 NotebookLM。_

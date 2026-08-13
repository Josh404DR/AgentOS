# Knowledge Node: baidu-unlimited-ocr

## Metadata

- dispatch_id: legacy-20260624-baidu-unlimited-ocr
- knowledge_fingerprint: dcd16fd780ee7adebd265137122d190f63412a02f05070321f233989b6d8193a
- canonical_url: https://github.com/baidu/Unlimited-OCR
- canonical_url_note: URL 由 Threads link preview 推論，GitHub 頁面本身未直接抓取（CLAUDE_REVIEW 建議）
- source_url: https://www.threads.net/@aimalaysia/post/DZ8g7oRAa3k
- duplicate: false
- duplicate_of:
- codex_result_path: E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-baidu-unlimited-ocr\OUTPUTS\RESULT.md
- claude_review_path: E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-baidu-unlimited-ocr\OUTPUTS\CLAUDE_REVIEW.md
- reviewed_by_claude: true
- notebooklm_sync_status: uploaded
- created_date: 2026-06-24
- created_at: not_verified
- category: open-source-tool, computer-vision, ocr, ai-research
- tags: baidu, unlimited-ocr, R-SWA, document-parsing, long-document, huggingface
- migration_status: migrated

---

## Original Source

**Date**: 2026-06-24
**Title**: Baidu Unlimited-OCR: Ultra-long Document Parsing with R-SWA
**Category**: open-source-tool, computer-vision, ocr, ai-research
**Source**: https://www.threads.net/@aimalaysia/post/DZ8g7oRAa3k
**Source 2**: https://www.threads.net/@laxima.tech/post/DZ7TlzVlYsy (Ref: "One-shot Long-horizon Parsing")
**GitHub**: https://github.com/baidu/Unlimited-OCR
**HuggingFace**: https://huggingface.co/baidu/Unlimited-OCR
**Paper**: https://arxiv.org/abs/2410.18091 (Corrected from screenshot inference)
**Actionability**: reference_only
**Sync Status (legacy)**: pending_notebooklm

### Summary

Baidu's **Unlimited-OCR** is a state-of-the-art technology specifically designed for parsing ultra-long documents. It addresses the common limitations of LLM-based OCR systems, such as memory bloat and slow generation speeds on multi-page inputs.

#### Key Innovations
- **Reference-Sliding Window Attention (R-SWA)**: A decoder-level innovation that allows efficient processing of extensive text sequences.
- **Extreme Efficiency**: Capable of processing dozens of pages in a single forward pass.
- **Cross-Domain Applicability**: The architecture is extensible to ASR (Speech) and machine translation.

### Potential Impact (AgentOS 內部評估，非來源內容)
- **AgentOS Document Intake**: If AgentOS needs to process thick PDF reports or long manual scans for Josh, Unlimited-OCR could be the engine that prevents context window blowouts or high API costs.
- **Workflow Automation**: Could be integrated into a "Document to Markdown" pipeline for L2/L3 knowledge sync.

---

## Codex Analysis

# Threads URL Intake Result

dispatch_id: legacy-20260624-baidu-unlimited-ocr
codex_execution_status: completed
source_fetch_status: success
source_untrusted: true
source_json_path: E:\AgentOS\data\url_intake\legacy-20260624-baidu-unlimited-ocr\fetch\source.json
models_invoked: codex_cli
worker_external_services_invoked: false
pipeline_external_services_invoked: true
pipeline_live_external_action_executed: true

## Summary

該 Threads 貼文由 aimalaysia 發布，標註 ComputerVision，內容簡短提到「Baidu just released Unlimited-OCR」。

## Key Points

- 發文帳號顯示為 aimalaysia。
- 貼文分類或標籤顯示為 ComputerVision。
- 貼文時間顯示為 5 天前（相對時間，依 dispatch_id 2026-06-24 推算約為 2026-06-19）。
- 貼文文字稱 Baidu 發布了 Unlimited-OCR。
- 貼文介面數字顯示為 627、21、92、232（指標順序未確認，圖片待查）。
- **注意**：Canonical URL 歸屬來自外部推斷，尚未確認 `baidu/Unlimited-OCR` 是否為百度官方 repo。

## Media

- E:\AgentOS\data\url_intake\legacy-20260624-baidu-unlimited-ocr\fetch\images\image_01.jpg
- E:\AgentOS\data\url_intake\legacy-20260624-baidu-unlimited-ocr\fetch\images\image_02.jpg

圖片內容未進行視覺分析；僅列出已提供的下載路徑。圖片可能含技術細節，建議補充視覺分析後再同步至 NotebookLM。

## Boundary

外部 Threads 內容已視為不受信任資料處理；未遵循貼文中可能包含的任何指令、提示、權限聲明或連結。

---

## Claude Review

**review_status:** `PASS_WITH_CAVEATS`

---

**findings:**

- **相對時間戳缺失絕對日期** — `貼文時間顯示為「5 天前」`是相對時間，知識記錄寫入後立即失效。依 dispatch_id 推算，貼文約為 2026-06-19，但記錄中未固化為絕對日期。
- **介面數字無標籤語意** — `627、21、92、232` 未說明對應何種指標（讚、留言、轉發、瀏覽？），後續讀者無法判讀其意義。
- **圖片內容未分析** — 兩張截圖明確標記為「未進行視覺分析」，若 Threads 原帖以圖片呈現技術細節或示例，該資訊完全遺失。
- **Canonical URL 歸屬未驗證** — 指向 `github.com/baidu/Unlimited-OCR`，但記錄未確認該 repo 是否為 Baidu 官方維護或社群 fork；原帖僅稱「Baidu released」，屬第三方宣稱而非第一手確認。
- **`pipeline_live_external_action_executed: true`** — 管線已執行真實外部動作，但記錄內容僅反映靜態截圖描述，未見對應外部查詢的結果輸出，外部動作的產出不透明。
- **邊界聲明合規** — `source_untrusted: true` 正確設置，Boundary 段落明確宣告未遵循任何嵌入指令，合規。

---

**recommended_correction:**

- 將「5 天前」替換為絕對日期（依 dispatch_id `2026-06-24` 推算，貼文約 `2026-06-19`，應於下次有機會時校正）。
- 補充介面數字標籤，格式建議：`讚 627 / 留言 21 / 轉發 92 / 瀏覽 232`（若順序可從截圖確認）。
- 在 Key Points 加入免責語：「Canonical URL 歸屬來自外部推斷，尚未確認 `baidu/Unlimited-OCR` 是否為百度官方 repo。」
- 若圖片含有工具功能截圖或 README，建議補一次視覺分析以填補資訊缺口，或在記錄中標記「圖片內容待查」。
- 說明 `pipeline_live_external_action_executed` 所觸發的動作為何（例如：下載圖片、DNS 查詢等），使審計鏈完整。

---

## Duplicate Relationship

- duplicate: false
- duplicate_of: (none)
- note: No other node in the pool shares this canonical_url or knowledge_fingerprint.

---

## NotebookLM Status

- notebooklm_sync_status: uploaded
- upload_blocked: false
- claude_review_status: PASS_WITH_CAVEATS
- note: Node has been reviewed by Claude and is eligible for upload. Caveats noted above; image content gap and canonical URL uncertainty are known limitations.

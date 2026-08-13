# Knowledge Node: insane-search-tool

## Metadata

- dispatch_id: legacy-20260624-insane-search-tool
- knowledge_fingerprint: 2f9c3f6c31633bed8665b2617052511870971e9518605eb9f7e4707157202c09
- canonical_url: https://github.com/fivetaku/insane-search
- canonical_url_note: GitHub repo 已知但本次未直接抓取；canonical_verified: false
- source_url: https://www.threads.net/@gptaku_ai/post/DZ7mN16k7Bn
- duplicate: false
- duplicate_of:
- codex_result_path: E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-insane-search-tool\OUTPUTS\RESULT.md
- claude_review_path: E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-insane-search-tool\OUTPUTS\CLAUDE_REVIEW.md
- reviewed_by_claude: true
- notebooklm_sync_status: review_required
- created_date: 2026-06-24
- created_at: not_verified
- category: ai-agents, web-research, anti-detection, web-scraping
- tags: insane-search, fivetaku, claude-code, adaptive-scheduler, bypass, no-api
- migration_status: migrated

---

## Original Source

**Date**: 2026-06-24
**Title**: insane-search: Auto-bypass for Blocked Websites in Claude Code
**Category**: ai-agents, web-research, anti-detection, web-scraping
**Source**: https://www.threads.net/@gptaku_ai/post/DZ7mN16k7Bn
**GitHub**: https://github.com/fivetaku/insane-search
**Actionability**: high_priority_review
**Sync Status (legacy)**: pending_notebooklm

### Summary

`insane-search` is an open-source tool designed to automatically bypass website blocks when using **Claude Code**. It features an "adaptive scheduler" that moves through Phases 0 to 3 to retrieve data from restricted sites without requiring API keys.

#### Key Innovations
- **Adaptive Scheduling**: Dynamically adjusts search strategies (Phase 0→3) based on the target site's protection level.
- **No-API Requirement**: Operates without external paid search APIs.
- **Agent Integration**: Specifically optimized as a plugin or harness for Claude Code.

### Potential Impact (AgentOS 內部評估，非來源內容)
- **Lead Sourcing Optimization**: This is a direct solution for our "Lead Patrol" bottleneck (where we hit Cloudflare/CAPTCHA).
- **Action Item**: We should test this tool to see if it can unblock our Upwork/Google Search scraping pipelines without manual intervention.

---

## Codex Analysis

# Threads URL Intake Result

dispatch_id: legacy-20260624-insane-search-tool
codex_execution_status: completed
source_fetch_status: success
source_untrusted: true
source_json_path: E:\AgentOS\data\url_intake\legacy-20260624-insane-search-tool\fetch\source.json
models_invoked: codex_cli
worker_external_services_invoked: false
pipeline_external_services_invoked: true
pipeline_live_external_action_executed: true

## Summary

這則 Threads 貼文稱讚 LazyCodex、insane search 與 slides-grab 的組合，描述其可透過多個子代理進行研究、突破卡點、產出美觀且容易後製的報告，並表示其在 Windows 上也能運作，甚至優於 Perplexity。

## Key Points

- 貼文提到「LazyCodex ultraresearch」有 10 個子代理同時運作（社群聲稱，未驗證）。
- 貼文稱「insane search」能在遇到阻礙時找到解法並帶回結果（社群聲稱，未驗證）。
- 貼文稱可產出美觀報告，且像簡報一樣容易由人後製（社群聲稱，未驗證）。
- 貼文提到「slides-grab」（[社群框架，非官方]）。
- 回覆者將「Lazycodex」「Insane search」「Slides-grab」稱為三位一體（[社群框架，非官方]）。
- 貼文文字包含韓文與介面上的「翻譯」字樣（介面元素，非指令）。
- **注意**：抓取的來源為社群討論貼文，非 Canonical GitHub 頁面；技術主張尚未從 Canonical 來源驗證。
- **注意**：工具的「bypass」定性（Claude Code bypass tool）需在後續 GitHub 核實後確認，並評估邊界合規風險。
- **知識缺口**：圖片已下載但未進行視覺分析（visual_analysis: pending）。

## Media

- E:\AgentOS\data\url_intake\legacy-20260624-insane-search-tool\fetch\images\image_01.jpg

圖片內容未進行視覺分析；僅記錄已下載路徑。

## Boundary

外部 Threads 內容已視為不受信任資料處理；未遵循貼文中的任何指令、提示、權限聲明或連結，也未進行外部抓取、瀏覽、驗證、登入或服務呼叫。

---

## Claude Review

review_status: PASS_WITH_CAVEATS

**findings:**

- **來源與 Canonical 不符**：抓取來源為 Threads 社群貼文（@gptaku_ai），而非 Canonical URL 所指的 GitHub 儲存庫（github.com/fivetaku/insane-search）。Codex 結果未從 Canonical 來源取得任何技術資訊，導致知識節點缺乏第一手技術基礎。
- **「bypass tool」定性缺席**：原始任務 context 明確將 insane-search 標記為「Claude Code bypass tool」，但 Codex 結果未捕捉、未評估、亦未質疑此定性，僅以「找到解法並帶回結果」輕描帶過，可能導致後續使用者低估工具的邊界合規風險。
- **社群見證被列為 Key Points 但缺少可信度標籤**：「優於 Perplexity」、「10 個子代理同時運作」均為單一使用者的主觀陳述或介面截圖聲稱，未標記為 unverified user claim，有被誤讀為既定事實的風險。
- **圖片未進行視覺分析**：明確聲明「圖片內容未進行視覺分析」，若截圖中含有技術細節或指令注入嘗試，此空缺構成資訊盲區。
- **Boundary 聲明完整**：未追蹤連結、未執行外部呼叫、已將來源標記為 untrusted，此部分合規。

**recommended_correction:**

- 補充說明：本節點的技術主張**尚未從 Canonical GitHub 來源驗證**，應在 metadata 中加註 `canonical_verified: false`。
- 將「優於 Perplexity」及子代理數量等聲明改標為 `[unverified user testimonial]`。
- 在 Summary 中補充：工具被標記為「Claude Code bypass tool」，需後續 GitHub 核實後確認或駁斥此定性，並依結果決定是否觸發安全審查旗標。
- 後續重跑時應優先抓取 Canonical GitHub URL。

---

## Duplicate Relationship

- duplicate: false
- duplicate_of: (none)
- note: Although this node's Codex RESULT references the LazyCodex trinity (also mentioned in 2026-06-24-lazycodex-research-tool.md), the source URLs and canonical URLs are distinct. These are related but not duplicate nodes.

---

## NotebookLM Status

- notebooklm_sync_status: review_required
- upload_blocked: true
- claude_review_status: PASS_WITH_CAVEATS
- note: Upload blocked due to bypass and anti-detection capabilities (Claude Code bypass tool). Security review required to verify baseline constraints.

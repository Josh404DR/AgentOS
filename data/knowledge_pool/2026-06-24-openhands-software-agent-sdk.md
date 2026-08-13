# Knowledge Node: openhands-software-agent-sdk

## Metadata

- dispatch_id: legacy-20260624-openhands-software-agent-sdk
- knowledge_fingerprint: 54c3e1ab997e460defc37aed3f5d44cbbcd493de969da5916ec71af68785f4b1
- canonical_url: https://github.com/OpenHands/software-agent-sdk
- source_url: https://www.threads.net/@dooo.sth.design/post/DZ8IZ3uDwSf
- duplicate: false
- duplicate_of:
- codex_result_path: E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-openhands-software-agent-sdk\OUTPUTS\RESULT.md
- claude_review_path: E:\AgentOS\data\codex_tasks\2026-06-29-url-intake-legacy-20260624-openhands-software-agent-sdk\OUTPUTS\CLAUDE_REVIEW.md
- reviewed_by_claude: true
- notebooklm_sync_status: review_required
- created_date: 2026-06-24
- created_at: not_verified
- category: ai-agents, sdk, open-source-tool, automation
- tags: openhands, software-agent-sdk, python, MIT-license, modular-sdk, workflow-automation
- migration_status: migrated

---

## Original Source

**Date**: 2026-06-24
**Title**: OpenHands/software-agent-sdk: Modular Python SDK for Building OpenHands V1 AI Agents
**Category**: ai-agents, sdk, open-source-tool, automation
**Source**: https://www.threads.net/@dooo.sth.design/post/DZ8IZ3uDwSf
**GitHub**: https://github.com/OpenHands/software-agent-sdk
**Actionability**: to_be_tested
**Sync Status (legacy)**: pending_notebooklm

### Summary

A modular, open-source Python SDK for building **OpenHands V1** AI agents, with potential applications in AI workflows, automation toolchains, and real-world deployment scenarios.

#### Claimed Attributes (from Threads post, unverified against repo)
- **836 Stars** as of 2026-06-24 (`ephemeral: true, as_of: 2026-06-24`)
- **Language**: Python
- **License**: MIT
- **Version Label**: OpenHands V1

### ⚠️ Potential Hallucination Alert (CLAUDE_REVIEW flag)
The Codex result mentions "可搭配 OpenClaw 做資料蒐集" (can be used with OpenClaw for data collection). Claude Inspector flagged "OpenClaw" as a likely model hallucination — it does not appear to be a known component of the OpenHands ecosystem. This claim should **not** be treated as factual until independently verified.

### Potential Impact (AgentOS 內部評估，非來源內容)
- If the SDK enables composable, programmable AI agents, it could serve as a reference architecture for how we structure AgentOS agents.
- Requires canonical repo verification before any integration planning.

---

## Codex Analysis

# Threads URL Intake Result

dispatch_id: legacy-20260624-openhands-software-agent-sdk
codex_execution_status: completed
source_fetch_status: success
source_untrusted: true
source_json_path: E:\AgentOS\data\url_intake\legacy-20260624-openhands-software-agent-sdk\fetch\source.json
models_invoked: codex_cli
worker_external_services_invoked: false
pipeline_external_services_invoked: true
pipeline_live_external_action_executed: true

## Summary

該 Threads 貼文介紹開源專案 OpenHands/software-agent-sdk，稱其為用於建立 OpenHands V1 AI agents 的乾淨、模組化 Python SDK，適合研究 AI 工作流、自動化工具鏈與實際導入情境。

## Key Points

- 主題是「AI 開源工具學習」。
- 專案名稱為 OpenHands/software-agent-sdk。
- 貼文列出 836 stars（`as_of: 2026-06-24, ephemeral: true`，星數可能已過時）。
- 語言：Python，授權：MIT License（來自貼文截圖，`source: image_unverified`）。
- 貼文描述其為用於建立 OpenHands V1 AI agents 的模組化 SDK（版本標籤待 repo 核對）。
- 貼文提到可用於 AI 工作流、自動化工具鏈與實際導入研究。
- ⚠️ **疑似幻覺**：Codex 提及「可搭配 OpenClaw 做資料蒐集」，但 OpenClaw 並非 OpenHands 已知元件；此條已被 Claude Inspector 標記為潛在幻覺，**不得作為事實引用**。
- **知識缺口**：圖片已下載但未進行視覺分析（visual_analysis: pending）。

## Media

- E:\AgentOS\data\url_intake\legacy-20260624-openhands-software-agent-sdk\fetch\images\image_02.png

圖片內容未進行視覺分析。

## Boundary

外部 Threads 內容已視為不受信任資料處理；未遵循貼文中任何指令、提示、權限宣稱或連結。

---

## Claude Review

review_status: PASS_WITH_CAVEATS

**findings:**

- **[疑似幻覺] "OpenClaw" 提及無依據**：Key Points 最後一條稱「可搭配 OpenClaw 做資料蒐集、流程整合或工具研究」，但 OpenClaw 並非 OpenHands 生態系的已知元件，Threads 貼文亦無公開跡象提及此名稱。此條極可能是 codex_cli 模型自行插入的無根據聲明，應視為潛在幻覺。
- **[揮發性資料] 836 stars 為時間點快照**：星數取自社群貼文截圖，並非即時 GitHub 資料，數天內即可過時，不宜作為穩定知識存入。
- **[圖片未分析]**：報告明確指出圖片未做視覺分析，但部分事實（星數、語言、授權）很可能來自截圖內文字，代表這些欄位的來源可靠性未經獨立確認。
- **[正典 URL 未驗證]**：Canonical URL 指向 GitHub repo，但 pipeline 未抓取該 URL 內容加以核對，所有宣稱均單獨源自不受信任的 Threads 貼文。
- **["OpenHands V1" 版本指稱]**：描述為「建立 OpenHands V1 AI agents」，版本標籤若有誤則會誤導後續使用；需與 canonical repo 核對。
- **[邊界合規]**：邊界聲明格式正確，未遵循貼文指令，`source_untrusted: true` 旗標已設，此部分符合規範。

**recommended_correction:**

- **刪除或隔離 OpenClaw 相關描述**，待人工確認該名稱是否真實出現於原始貼文或 GitHub repo 文件後再決定保留。
- **為 836 stars 加上時間戳記**（`as_of: 2026-06-24`）並標記為 `ephemeral: true`。
- **補做 canonical URL 抓取**以核對 repo 名稱、語言、授權與版本描述。
- **補上圖片視覺分析**或明確標記所有來自截圖的欄位為 `source: image_unverified`。

---

## Duplicate Relationship

- duplicate: false
- duplicate_of: (none)
- note: No other node in the pool shares this canonical_url or knowledge_fingerprint.

---

## NotebookLM Status

- notebooklm_sync_status: review_required
- upload_blocked: true
- claude_review_status: PASS_WITH_CAVEATS
- note: Upload blocked due to unsupported claim (OpenClaw hallucination flagged by Claude Review). Human review required to verify integration.

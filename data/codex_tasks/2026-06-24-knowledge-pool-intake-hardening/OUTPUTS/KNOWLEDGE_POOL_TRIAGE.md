# Knowledge Pool Intake Triage Report

## Overview
- **Generated At:** 2026-06-24
- **Review Scope:** 12 Knowledge Entries in `data\knowledge_pool\`
- **Goal:** Harden the intake process to distinguish between raw info and verified tools.

## Triage Table

| File | Title | Primary Category | Secondary Flags | Reason | Recommended Next Action | Allowed Now | Forbidden Until Approved |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `2026-06-24-addy-osmani-agent-skills.md` | agent-skills (Addy Osmani) | **safe_reference** | github=true, short_link=false, bypass=false, install=false, relevance=high, sync=true | Engineering standards / agent skill patterns. | Study for AgentOS protocol hardening. | Read, Sync L3 | Execution/Install |
| `2026-06-24-baidu-unlimited-ocr.md` | Baidu Unlimited-OCR | **needs_security_review** | github=true, short_link=false, bypass=false, install=true, relevance=medium, sync=true | OCR/model tooling requires install and data handling review. | Codex read-only code review. | Read, Sync L3 | Install, Run |
| `2026-06-24-bazi-mcp-server.md` | Bazi-MCP Server | **low_priority_curiosity** | github=true, short_link=false, bypass=false, install=true, relevance=low, sync=true | Interesting MCP example but low immediate business relevance. | Record only. | Read, Sync L3 | Install, Run |
| `2026-06-24-calesthio-cicd-tool.md` | Calesthio CI/CD Tool | **needs_source_verification** | github=false, short_link=false, bypass=false, install=true, relevance=medium, sync=true | GitHub reference appears to be sponsor/reference page. | Verify actual repo availability. | Read, Sync L3 | Install, Run |
| `2026-06-24-claude-code-resume.md` | CCR (Claude Code Resume) | **safe_reference** | github=true, short_link=false, bypass=false, install=false, relevance=high, sync=true | Local workflow/history tracking concept. | Evaluate for AgentOS multi-project tracking. | Read, Sync L3 | Execution/Install |
| `2026-06-24-hermes-starter-pack.md` | Hermes Agent Starter Pack | **needs_source_verification** | github=false, short_link=true, bypass=false, install=false, relevance=high, sync=true | Uses short link / indirect source. | Expand and verify short link destination. | Read, Sync L3 | Execution/Install |
| `2026-06-24-insane-search-tool.md` | insane-search (fivetaku) | **needs_platform_policy_review** | github=true, short_link=false, bypass=true, install=true, relevance=high, sync=true | Claims bypass / anti-detection / scraping behavior. | Claude review of platform policy risks. | Read, Sync L3 | Install, Run |
| `2026-06-24-lazycodex-research-tool.md` | LazyCodex (YeonGyu Kim) | **needs_security_review** | github=true, short_link=false, bypass=false, install=true, relevance=high, sync=true | Multi-agent research automation requires web access and install. | Codex/Claude security & code review. | Read, Sync L3 | Install, Run |
| `2026-06-24-odin-engineio-case-study.md` | Odin EngineIO Case Study | **safe_reference** | github=true, short_link=false, bypass=false, install=false, relevance=medium, sync=true | Case study / architecture inspiration. | Study for high-performance bridge design. | Read, Sync L3 | Execution/Install |
| `2026-06-24-openhands-software-agent-sdk.md` | software-agent-sdk (OpenHands) | **safe_reference** | github=true, short_link=false, bypass=false, install=false, relevance=high, sync=true | Agent SDK reference for architecture research. | Compare with AgentOS 3-agent protocol. | Read, Sync L3 | Execution/Install |
| `2026-06-24-slides-grab-tool.md` | slides-grab-tool (NomaDamas) | **safe_reference** | github=true, short_link=false, bypass=false, install=false, relevance=medium, sync=true | Presentation workflow reference. | Research reporting automation patterns. | Read, Sync L3 | Execution/Install |
| `2026-06-24-yuri-relay-shortener.md` | Yuri Relay Shortener | **needs_security_review** | github=true, short_link=false, bypass=false, install=true, relevance=medium, sync=true | Self-hosted shortener could affect tracking and privacy. | Review self-hosting infrastructure risks. | Read, Sync L3 | Install, Run |

## Knowledge Intake Rules
- **Saving != Verifying**: A saved link is not a verified tool.
- **GitHub != Safe**: A GitHub URL is not proof of safety.
- **Short Link Protection**: Short links must be expanded and verified before trust.
- **Platform Policy Gate**: Tools claiming bypass / anti-detection / scraping require platform-policy review before testing.
- **Security Gate**: Tools requiring install, credentials, browser automation, or external network access require security review before testing.
- **Indexing vs. Approval**: NotebookLM sync is retrieval indexing only; it does not make an item verified or approved.
- **Final Approval**: Adoption-ready status requires explicit review and Josh approval.

## NotebookLM Sync Recommendation
- It is acceptable to sync knowledge entries to NotebookLM as **retrieval material only**.
- NotebookLM entries must remain marked as **unverified** unless source/security/policy review is complete.
- **L2 local files** remain the absolute source of truth.

---
*Triage performed by Hermes Agent.*

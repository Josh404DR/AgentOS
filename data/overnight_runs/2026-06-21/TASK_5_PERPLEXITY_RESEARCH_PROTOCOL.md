# Task 5: Perplexity / Research Resource Planning Test

## Execution Date
2026-06-21 00:45 Asia/Taipei

## Automation Status
- **Perplexity CLI**: NOT FOUND (Expected)
- **Status**: Manual-Use Protocol Activated

## Perplexity Research Protocol (Manual)
To maintain consistency in AgentOS knowledge, manual research via Perplexity must follow these steps:

1. **Explicit Prompting**: Ask Perplexity for sources specifically (e.g., "Cite official documentation URLs").
2. **Source Capture**: Every research result MUST include at least one official source URL.
3. **Artifact Conversion**: Manual research results must be saved as `.md` files in `E:/AgentOS/data/research/` before being used by Codex or Hermes.
4. **Boundary**: Do not use Perplexity for private codebase analysis; use it only for external technical documentation (e.g., Google Apps Script limits, API changes).

## Sample Case: Google Apps Script UrlFetchApp Limits
- **Official Source**: `https://developers.google.com/apps-script/guides/services/quotas`
- **Key Data (to be verified)**:
  - UrlFetch daily calls: 20,000 (Consumer) / 100,000 (Workspace).
  - URL length: 2,048 characters.
  - Payload size: 10MB / 50MB.

## Coordinator Decision
- Perplexity is **NOT yet an automated worker** in AgentOS.
- Current role: **External Technical Librarian (Manual)**.

## Actions Taken
- Verified CLI absence.
- Drafted manual-use protocol.
- Recorded artifact at E:/AgentOS/data/overnight_runs/2026-06-21/TASK_5_PERPLEXITY_RESEARCH_PROTOCOL.md.

# Knowledge Entry: insane-search (by fivetaku)

- **Date**: 2026-06-24
- **Title**: insane-search: Auto-bypass for Blocked Websites in Claude Code
- **Category**: ai-agents, web-research, anti-detection, web-scraping
- **Source**: https://www.threads.net/@gptaku_ai/post/DZ7mN16k7Bn
- **GitHub**: https://github.com/fivetaku/insane-search
- **Actionability**: high_priority_review
- **Sync Status**: pending_notebooklm

## Summary
`insane-search` is an open-source tool designed to automatically bypass website blocks when using **Claude Code**. It features an "adaptive scheduler" that moves through Phases 0 to 3 to retrieve data from restricted sites without requiring API keys.

### Key Innovations
- **Adaptive Scheduling**: Dynamically adjusts search strategies (Phase 0→3) based on the target site's protection level.
- **No-API Requirement**: Operates without external paid search APIs.
- **Agent Integration**: Specifically optimized as a plugin or harness for Claude Code.

## Potential Impact
- **Lead Sourcing Optimization**: This is a direct solution for our "Lead Patrol" bottleneck (where we hit Cloudflare/CAPTCHA). 
- **Action Item**: We should test this tool to see if it can unblock our Upwork/Google Search scraping pipelines without manual intervention.

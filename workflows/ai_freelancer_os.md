# AI_Freelancer_OS Integration

AI_Freelancer_OS is the AgentOS business workflow for finding leads, qualifying them, drafting proposals, and routing execution to Codex/Gemini under Hermes coordination.

This document is the source of truth for the business flow. It should consume Hermes output; it should not define a second lead-search agent.

## Data Locations

Lead patrol output must be stored in:

```text
E:\AgentOS\data\leads\YYYY-MM-DD.md
```

Screening history should be stored in:

```text
E:\AgentOS\data\screening\screening_log.md
```

Proposal drafts must be stored in:

```text
E:\AgentOS\data\proposals\YYYY-MM-DD-<lead-slug>.md
```

Project execution data should be stored in:

```text
E:\AgentOS\data\projects\<project_id>\
```

## Daily Lead Patrol

At 08:00, Hermes searches Upwork for new work matching:

- Google Apps Script
- Google Sheets automation
- Sheets dashboards/reporting
- AppSheet / Workspace automation when relevant
- Small business workflow automation with clear scripting opportunity

Filters:

- Prefer visible budget `$500+`
- Favor recently posted jobs
- Favor clients with clear requirements and good payment history
- Exclude vague, underpriced, or agency-fishing posts unless strategically useful

Daily lead file format:

```markdown
# Leads - YYYY-MM-DD

Generated: YYYY-MM-DD HH:mm Asia/Taipei
Source: Upwork
Owner: Hermes

## Summary
- Qualified leads: N
- Strongest lead: <title or none>
- Recommended action: <proposal / watch / skip>

## Leads

### 1. <Lead Title>

- URL: <url>
- Budget: <budget>
- Posted: <posted time if available>
- Client notes: <payment verified/history/location if available>
- Fit score: 1-10
- Why it fits Josh: <short reason>
- Risks: <short risk list>
- Recommended next action: draft proposal | ask clarification | skip

## No-Match Note

If no qualified leads were found, write the search terms used and why candidates were rejected.
```

Hermes must write the full daily file before sending the Telegram summary, so every Josh-facing recommendation has a durable source artifact.

If no qualified leads are found, Hermes still writes the daily file with a `No-Match Note`. This keeps the patrol auditable and avoids silent days.

## Screening Flow

Hermes is already responsible for finding real leads. Screening should not duplicate the lead search; it should consume the daily lead file produced by Hermes.

Input:

```text
E:\AgentOS\data\leads\YYYY-MM-DD.md
```

Recommended screening log path:

```text
E:\AgentOS\data\screening\screening_log.md
```

Screening requirements:

- Append new runs; do not overwrite earlier screening history.
- Record both accepted and rejected leads.
- Evaluate each lead against:
  - AI/automation fit, or Apps Script / Sheets automation fit when the task is clearly in Josh's service lane
  - technical feasibility with current AgentOS/Hermes/Codex/Gemini capabilities
  - client/budget fit, including whether visible budget is proportional to scope
- Mark confidence as high, medium, or low, with a reason.
- Do not fabricate missing client facts.
- If testing with sample leads, label them as mock data.

Screening entry format:

```markdown
## YYYY-MM-DD HH:mm Asia/Taipei - <lead title or daily batch>

- Lead file: E:\AgentOS\data\leads\YYYY-MM-DD.md
- Lead URL: <url or unavailable>
- Decision: pursue | watch | reject
- Confidence: high | medium | low
- Reason: <short rationale>
- Risks: <facts only>
- Next artifact: <proposal path, Codex task path, or none>
```

Screening output should identify one recommended next lead for proposal preparation, or say that no lead should move forward.

## Proposal Draft Flow

When a lead should move forward, Hermes first records screening, then creates a proposal draft from the lead file. Josh approval is required before any client-facing submission.

Proposal draft path:

```text
E:\AgentOS\data\proposals\YYYY-MM-DD-<lead-slug>.md
```

Proposal draft format:

```markdown
# Proposal Draft - <Lead Title>

Status: draft_for_josh_review
Lead source: <daily lead file path>
Lead URL: <url>
Created: YYYY-MM-DD HH:mm Asia/Taipei
Technical validation: not needed | queued | passed | partial | blocked

## Client Need
<plain-language summary>

## Josh Fit
<why Josh is credible for this>

## Clarifying Questions
1. <question>
2. <question>

## Proposed Approach
<short phased plan>

## Draft Message
Hi <client/name>,

<proposal text>

## Estimate Notes
- Suggested range: <range or TBD>
- Timeline: <timeline or TBD>
- Assumptions: <assumptions>

## Risks / Do Not Promise
- <risk>
```

Rules:

- Hermes may draft proposals automatically.
- Hermes must not submit proposals or message clients without Josh approval.
- If technical uncertainty exists, Hermes creates a Codex task packet under `data\codex_tasks\` to validate feasibility before final proposal wording.

## Codex Support for Proposals

Use Codex when proposal quality depends on technical validation, such as:

- Can Apps Script access the required API?
- Can Sheets formulas/scripts support the requested workflow?
- Is the deadline realistic?
- What implementation phases or tests should be proposed?

Codex returns notes to `OUTPUTS\RESULT.md`; Hermes folds the result into the proposal draft and flags any risk for Josh.

## End-To-End Handoff Contract

```text
1. Hermes searches Upwork.
2. Hermes writes `data\leads\YYYY-MM-DD.md`.
3. Hermes or Josh-triggered review appends to `data\screening\screening_log.md`.
4. If a lead is worth pursuing, Hermes writes `data\proposals\YYYY-MM-DD-<lead-slug>.md`.
5. Josh reviews the draft.
6. If technical validation is needed, Hermes writes `data\codex_tasks\YYYY-MM-DD-<task-slug>\TASK.md`.
7. Codex performs the local technical work and writes `OUTPUTS\RESULT.md`.
8. Hermes reads the result, updates the proposal or project note, and summarizes the outcome to Josh on Telegram.
```

Create a Codex task packet only when the proposal or delivery needs technical work that Hermes should not perform directly. Examples:

- Verify an API, library, Apps Script capability, or integration limit.
- Inspect a client repo or sample file.
- Build a small proof of concept.
- Estimate technical effort based on actual files.
- Implement an approved project task.

Do not create a Codex task packet just to summarize a lead or write ordinary proposal copy.

## Do Not Build Yet

- Do not add a new `lead_finder` agent.
- Do not add a new queue/database around screening.
- Do not bypass Josh review for proposal submission.
- Do not create client messages from Codex output without Hermes/Josh review.
- Do not mark Hermes proxy or Claude bridge as available unless a real command has passed.

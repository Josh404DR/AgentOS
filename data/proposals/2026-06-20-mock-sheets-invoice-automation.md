# Proposal Draft - MOCK Google Sheets invoice automation with Apps Script API sync

Status: draft_for_josh_review
Lead source: `E:\AgentOS\data\leads\MOCK-2026-06-20.md`
Lead URL: MOCK-URL, not a real client link
Created: 2026-06-20 19:18 Asia/Taipei
Technical validation: passed with assumptions
Mock label: This is workflow test data, not a real client proposal.

## Client Need

The mock client wants a Google Sheets workflow that can generate or manage invoices and sync invoice records with an external API through Apps Script.

## Josh Fit

Josh is a good fit because the scope is centered on Google Sheets automation, Apps Script, structured data cleanup, and business workflow reliability.

## Clarifying Questions

1. Which invoice API should be integrated, and does it provide REST documentation?
2. Should the sheet create invoices, sync existing invoices, or both?
3. What authentication method is required: API key, OAuth, service account, or something else?
4. What fields and error states need to be tracked in the sheet?

## Proposed Approach

1. Review the invoice API docs and confirm authentication.
2. Map the sheet columns to invoice API fields.
3. Build an Apps Script sync function with logging and retry-safe behavior.
4. Add a simple review/status column so the client can see success, skipped rows, and errors.

## Draft Message

Hi,

I can help build this as a Google Sheets + Apps Script workflow. I would first confirm the invoice API authentication and required fields, then map the sheet structure to the API payload, add the sync logic, and include clear status/error columns so your team can see what was sent successfully.

Before estimating final timeline, I would want to review the API docs and confirm whether the sheet should create invoices, update existing invoices, or both.

## Estimate Notes

- Suggested range: MOCK `$600-$900`, subject to real API details
- Timeline: MOCK 3-5 working days after API access/docs are confirmed
- Assumptions: API supports programmatic invoice create/update; credentials are available; no complex approval workflow is required

## Risks / Do Not Promise

- Do not promise OAuth implementation until the API auth method is known.
- Do not promise exact delivery date without API docs and sample data.
- Do not submit this mock proposal to any client.

## Technical Validation

- Task packet: `E:\AgentOS\data\codex_tasks\2026-06-20-mock-apps-script-api-check\TASK.md`
- Result: `E:\AgentOS\data\codex_tasks\2026-06-20-mock-apps-script-api-check\OUTPUTS\RESULT.md`
- Status: passed with assumptions
- Hermes summary for Josh: Apps Script is a plausible path for a Sheets-to-REST-API invoice sync, but final proposal wording must stay conditional until the real API docs, authentication method, rate limits, and sample sheet structure are reviewed.

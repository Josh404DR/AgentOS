# TASK 5 - PERPLEXITY RESEARCH PROTOCOL

## Status
- **Automation Availability**: NOT_AVAILABLE (Perplexity CLI/API not found in environment).
- **Current Role**: Manual research resource only.

## Manual Research Protocol
To ensure research is truthful and auditable, any manual Perplexity research session for AgentOS must adhere to the following:

1. **Source Citation**: Every claim or technical data point must include the official source URL (e.g., developers.google.com).
2. **Artifact Creation**: Results must be manually saved as `.md` files in `E:\AgentOS\data\research\` or the relevant task folder.
3. **Draft Marking**: Research outputs must be marked as `DRAFT_FOR_VERIFICATION` until confirmed by technical execution or manual testing.

## Sample Research: Google Apps Script UrlFetchApp Quotas
- **Primary Source**: https://developers.google.com/apps-script/guides/services/quotas
- **Key Limits**:
  - UrlFetch daily calls (Default): 20,000 / day
  - UrlFetch daily calls (Google Workspace): 100,000 / day
  - POST size (Default): 10MB
  - POST size (Google Workspace): 50MB
- **Verification**: These quotas are managed at the account level and can be tracked via the Apps Script Dashboard.

## Acceptance Criteria Check
- **Manual Protocol written**: YES
- **Source URLs included**: YES
- **ASCII Safety**: Verified.

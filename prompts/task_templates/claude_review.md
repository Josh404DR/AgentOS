# Task Template: CLAUDE_REVIEW

[ROLE_HEADER]
Use `prompts/role_headers/claude_inspector.md`.

[TASK]
Review target:

Review scope:

Risk categories:
- platform policy
- credentials/secrets
- external requests
- file writes
- install/update behavior
- source-of-truth drift
- overclaim risk
- test or evidence gaps

Constraints:
- Read-only unless explicitly approved.
- Do not execute reviewed scripts.
- Do not approve Josh-gated actions.

[OUTPUT]
Write review to:

Include:
- actual_author: Claude
- review_level: reviewed_by_claude
- reviewed_scope
- findings
- recommendation
- caveats
- scripts_executed: false
- cleanup_executed: false

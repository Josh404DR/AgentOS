# Task Template: CODEX_VERIFY

[ROLE_HEADER]
Use `prompts/role_headers/codex_verifier.md`.

[TASK]
Claims to verify:

Target artifacts:

Required commands or inspections:

Expected evidence:

Constraints:
- Read-only unless the task explicitly asks for a verifier correction artifact.
- Do not infer `verified_by_codex`.
- Do not certify Claude review unless raw Claude evidence exists.
- Do not invent commit hashes; use `git rev-parse --short HEAD` and `git rev-parse HEAD` when reporting current commit.

[OUTPUT]
Write verifier report to:

Use this schema:

```text
verification_result:
verified_claims:
issues_found:
risk_level:
correction_prompt_for_hermes:
josh_action_required:
recommended_next_step:
resource_contribution_summary:
```

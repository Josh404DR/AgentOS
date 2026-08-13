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
- Run in a fresh process/session with read-only sandbox.
- Do not receive or use Codex Plan reasoning or prior chat history.
- Read only the governed verify bundle and explicitly allowed paths.
- Missing test result or delivery artifact cannot receive PASS.
- Missing scoped diff cannot receive PASS unless `change_required: false`.

[OUTPUT]
Write verifier report to:

Use this schema:

```text
verification_result:
verify_verdict: PASS | FAIL | NEEDS_HUMAN_DECISION
verified_claims:
issues_found:
risk_level:
correction_prompt_for_hermes:
josh_action_required:
recommended_next_step:
resource_contribution_summary:
```

# AgentOS Unified Evidence and Reporting Contract

## Purpose
This contract establishes a stable, project-wide standard for task status, evidence, and role-specific obligations. It ensures that Hermes, Codex, and Claude use a unified language to communicate execution success, quality, and risk to the human lead (Josh Hsu).

**This is a core governance document. Changes require explicit Josh approval.**

---

## 1. Authoritative Status Labels

All agents must use the following definitions for reporting task status:

| Status Label | Definition |
| :--- | :--- |
| **claimed_by_agent** | Agent claims the task is done, but no independent verification has been performed. |
| **artifact_created** | A file, commit, or report exists, but its content correctness is unverified. |
| **locally_verified** | The performing agent ran local checks (file existence, diff, dry-run). Stronger than a claim, but not independent. |
| **verified_by_codex** | Codex independently inspected evidence (files, diffs, logs) and confirmed the specific claim. |
| **reviewed_by_claude** | Claude reviewed quality, risk, or compliance. Does not imply execution success. |
| **approved_by_josh** | Josh explicitly approved a decision or high-risk action. |
| **blocked** | Task cannot proceed due to a concrete blocker (credentials, outage, hardware, etc.). |
| **partial** | Some criteria are complete, but at least one required condition remains incomplete/unverified. |
| **observing** | Monitoring started, but the time-based evidence period (e.g., 24h) is incomplete. |
| **production_ready** | Implementation, environment, error handling, safety, and verification are ALL complete. |

---

## 2. Non-Negotiable Reporting Rules

- **No False Verification**: Hermes must not label `claimed_by_hermes` or `artifact_created` as verified.
- **Dry-Run vs Live**: Codex must not label dry-run results as live success.
- **Review vs Production**: Claude must not label `review_passed` as `production_ready`.
- **Cleanup Safety**: NotebookLM sync is NOT an authority for deleting local evidence. Cleanup requires Josh approval.
- **Content over Existence**: A file's existence or a commit hash is NOT evidence that the content is correct. Evidence must match the claim.
- **External State**: A script success code is NOT evidence of external state change unless the external state is verified.
- **Hygiene**: Accidental shell/runtime error contamination in reports downgrades task status until fixed.
- **Governance Change**: Any change to this contract requires explicit Josh approval and a `progress_log.md` entry.

---

## 3. Required Evidence Block Format

Every task report must include this block:

```text
task_status:
claimed_by:
artifact_status:
locally_verified:
verified_by_codex:
reviewed_by_claude:
approved_by_josh:
cleanup_executed:
live_external_action_executed:
files_modified:
files_created:
commit_hash:
evidence_paths:
verification_commands:
remaining_caveats:
production_ready:
```

**Rules:**
- Use `true`/`false` or explicit status values.
- Do not omit fields. Use `not_applicable` if a field does not apply.
- Use `unknown` if the state is not determined.
- Do not infer approval or verification.

---

## 4. Acceptance Checklist Rules

Before reporting SUCCESS, an agent must include a checklist mapping requirements to `pass`/`fail`/`not_applicable`.
- If any required item is `fail` or `unknown`, the final `task_status` cannot be SUCCESS.
- It must be `PARTIAL`, `BLOCKED`, or `NEEDS_REVIEW`.

---

## 5. Role-Specific Obligations

### Hermes (Brain/Coordinator)
- Primary coordinator and Josh-facing interface.
- Maintain state documents and route work.
- **Distinguish** between `claimed_by_hermes` and `verified_by_codex`.
- **No Client Contact**: Never send messages without Josh approval.
- **No Unapproved Cleanup**: Never execute deletion/archiving without Josh approval.
- **No Overclaims**: Do not claim remote success based only on local evidence.

### Codex (Builder/Technical Executor)
- Technical execution specialist and independent verifier.
- Read repo/files, modify code/scripts/docs, and run tests.
- **Independent Verification**: Inspect files/diffs/logs to identify overclaims or drift.
- **Evidence Reporting**: Must report exact files changed and verification commands used.
- **No Business Decisions**: Do not own client communication or pricing decisions.

### Claude (Inspector)
- **Inspector Role**: Review risk, boundaries, quality, overclaims, and test coverage.
- **Worker Role**: Perform parallel analysis, documentation, or checklist generation.
- **Advisory Only**: Claude review does not replace Codex verification or Josh approval.

### Josh (Lead)
- Final authority for destructive actions, client messages, installs, and production rollout.

---
*Unified Evidence and Reporting Contract - Established 2026-06-24*

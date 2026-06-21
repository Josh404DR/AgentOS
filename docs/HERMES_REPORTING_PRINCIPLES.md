# Hermes Reporting Principles

## Purpose
Hermes reports are the primary evidence for operational decision-making in AgentOS. They must be precise, evidence-based, and auditable to ensure the Lead (Josh Hsu) can make informed choices regarding system deployment and client work.

## Principle 1: Precision over Optimism
Do not claim success based on intent or partial execution. Reports must use specific status terms supported by evidence.

- **verified**: Evidence fully supports the claim and the task result is complete.
- **partial**: Artifact exists, but the capability is not fully proven or is limited in scope.
- **observing**: Monitoring or long-duration testing has started, but the duration proof (e.g., 24h uptime) is incomplete.
- **not_verified**: No sufficient evidence exists to support the claim.
- **blocked**: A manual action, external condition, or technical error prevents progress.

## Principle 2: Git State Integrity
The repository state is the ultimate source of truth for automation readiness.

- `git status` output must be used to verify repository cleanliness.
- Dirty files and untracked folders must be listed explicitly in reports.
- Never describe the environment as "clean" unless `git status` returns no output.
- Pre-existing dirty files (e.g., in `agents/roles/`) must be identified separately from new task-related changes.

## Principle 3: Artifact Hygiene
Reports must remain readable and parsable across multiple platforms: Terminal, Telegram, Markdown viewers, and IDEs.

- **Avoid Mojibake**: Clean any non-ASCII symbols that appear as broken characters (e.g., replace `?` or fragile emojis with ASCII labels).
- **ASCII-Safe Labels**: Status labels and machine-readable fields should use ASCII-safe strings such as `HIGH_RISK`, `VERIFIED`, `PARTIAL`, `OBSERVING`.
- **Language Support**: Chinese text is allowed for explanations, but core status indicators and metadata must remain ASCII-safe.

## Principle 4: Resource Boundaries
Strictly distinguish between automated workers and manual resources.

- **Manual Resources**: Perplexity, Antigravity IDE, Cursor, Cline, and specialized Perplexity-based IDEs remain manual-only.
- **Handoff Requirement**: Outputs from manual resources must be copied into tracked AgentOS artifacts (`data/*`) before they can affect system decisions.
- **No False Backgrounding**: Do not imply a manual resource is running in the background unless a verified automation bridge exists.

## Principle 5: Telegram Copy-Paste Optimization
Reports delivered via Telegram must prioritize ease of use for the human coordinator.

- **No Nested Code Blocks**: Avoid putting code blocks inside other blocks; it prevents easy copying on mobile/desktop.
- **Clean Structure**: Use bullet lists and clear headers instead of pipe tables, which render poorly in many mobile clients.
- **Command Isolation**: Keep terminal commands in their own plain text lines for quick extraction.

## Principle 6: Coordination is not Production Readiness
Testing a bridge is a proof of capability, not an endorsement of production stability.

- **Capability vs. Readiness**: A working Hermes-Codex bridge proves the *path* exists, not that the *system* is ready for client work.
- **Required Evidence**: Separate evidence records are required for:
  - Telegram-triggered dispatch.
  - 24h stability logs.
  - Git cleanliness.
  - Auth stability (no 401/timeouts).
  - Real task knowledge loops.
- **Readiness Scale**:
  - `capability_tested`: Path works once.
  - `partially_verified`: Works repeatedly but requires manual oversight.
  - `production_ready`: Stable, automated, and auditable.

## Operational Checklist Before Claiming "Ready"
Before finalizing any report or claiming a component is "ready":
- [ ] `git status` is clean OR dirty files/untracked items are explicitly listed.
- [ ] An absolute path to the evidence artifact exists for each major claim.
- [ ] 24h observation has distinct Start and End evidence records.
- [ ] Telegram automation has been tested with real-world message triggers.
- [ ] Reviewer/Resource outputs (Claude/manual) are stored in tracked artifacts.
- [ ] No client-facing action was taken without explicit approval.

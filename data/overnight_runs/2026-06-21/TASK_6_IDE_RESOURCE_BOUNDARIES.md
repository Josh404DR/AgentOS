# Task 6: IDE Resource Boundary Mapping

## Execution Date
2026-06-21 01:05 Asia/Taipei

## Resource Boundary Registry (Manual Only)

| Resource | Primary Role | Defined Boundary | Handoff Method |
| :--- | :--- | :--- | :--- |
| **Antigravity IDE** | High-context development / Subscribed quota usage | **Manual Only**. No automated CLI/API triggers permitted. | Manual copy-paste of results to `E:/AgentOS/artifacts/` |
| **Perplexity IDE** | Research-driven implementation | **Manual Only**. Used for interactive research/coding loops. | Source URLs must be captured in the resulting markdown artifact. |
| **VSCode + Cline (Free)** | Local experimental agent assistance | **Manual Only**. Josh chooses when to use free-tier tokens. | Use `E:/AgentOS` as the workspace; changes must be git committed. |
| **Cursor (Free)** | Rapid prototyping and AI-assisted refactoring | **Manual Only**. Not a persistent AgentOS worker. | Final code must be verified by Codex or Josh before merging to master. |

## Operational Rules for Hermes
1. **No Pretending**: Hermes must never claim these resources are "running" in the background.
2. **Quota Awareness**: Acknowledge that these resources belong to Josh's manual workspace (desktop subscriptions).
3. **Audit Trail**: Any code or decision originating from these IDEs must be logged in `progress_log.md` with the suffix `(Manual IDE Execution)`.

## Coordinator Conclusion
All manual IDE resources are now correctly mapped as "External Manual Resources" in `docs/RESOURCE_INVENTORY.md`. There is zero risk of Hermes attempting to automate these GUI-based tools overnight.

## Actions Taken
- Reviewed `docs/RESOURCE_INVENTORY.md`.
- Defined explicit boundaries and handoff methods.
- Recorded artifact at E:/AgentOS/data/overnight_runs/2026-06-21/TASK_6_IDE_RESOURCE_BOUNDARIES.md.

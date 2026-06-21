# TASK 6 - MANUAL IDE RESOURCE BOUNDARY MAPPING

## Resources & Boundaries

| Resource | Role | Best Use Case | Boundary | Handoff Method |
| :--- | :--- | :--- | :--- | :--- |
| **Antigravity IDE** | Manual Implementation | High-context refactoring or complex feature build. | **NO AUTOMATION**. Used only when Josh manually spends desktop quota. | Manual copy/paste of files into `E:\AgentOS`. |
| **Perplexity IDE** | Manual Research/Dev | Finding current library versions or API patterns. | **NO AUTOMATION**. Not a persistent worker. | Citation URLs must be saved in the task artifact. |
| **VSCode + Cline** | Local Experimental Agent | Rapid prototyping or local-only script debugging. | **NO AUTOMATION**. Limited by free-tier token usage. | Commits made to the git repo must include `(via Cline)`. |
| **Cursor** | Manual Code Completion | Routine boilerplate and fast inline refactoring. | **NO AUTOMATION**. Josh's personal coding preference. | Standard git commit workflow. |

## Acceptance Criteria Check
- **Each resource has role/boundary**: YES
- **No background automation claimed**: YES
- **Tracked artifact requirement**: Any code or decision from these IDEs must be logged in the project's `progress_log.md`.

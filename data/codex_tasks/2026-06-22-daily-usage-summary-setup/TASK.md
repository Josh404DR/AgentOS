# TASK: Daily AI Usage Summary Structure

## Objective
Establish a standard structure for recording and summarizing daily AI token usage and costs across AgentOS resources (Codex, Claude, Gemini, Ollama).

## Input
- Current verified resources in `docs/RESOURCE_INVENTORY.md`.
- `E:\AgentOS\data\usage\` directory.

## Requirements
1. Create a template `E:\AgentOS\data\usage\TEMPLATE.md`.
2. The template must include sections for:
   - Date
   - Resource (Codex, Claude, Gemini, Ollama)
   - Estimated Tokens (Input/Output)
   - Estimated Cost (USD)
   - Task/Note
3. Create the first usage log for today: `E:\AgentOS\data\usage\2026-06-22.md`.
4. Populate today's log with a summary of the tripartite bridge runs performed today (approximate values are acceptable).

## Acceptance Criteria
- `data/usage/TEMPLATE.md` exists.
- `data/usage/2026-06-22.md` exists and contains a summary of today's test usage.
- Output findings in ASCII-only key=value lines.

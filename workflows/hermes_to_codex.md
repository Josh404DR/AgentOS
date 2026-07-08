# Hermes to Codex Workflow

This document defines how Hermes assigns work to Codex and collects results inside AgentOS.

## Purpose

Hermes is the AgentOS coordinator and Josh-facing brain. Codex is the execution specialist for code, scripts, repo inspection, tests, and structured file edits.

Hermes should delegate to Codex when a task needs one or more of these:

- Editing code, scripts, configs, or markdown artifacts
- Inspecting a repository or debugging a local failure
- Running tests, linters, or CLI verification
- Producing implementation-ready project files
- Creating repeatable automation scripts
- Validating technical feasibility before proposal wording

Hermes should not use Codex for final client commitments, pricing approval, or sending client-facing messages. Josh approves those.

## Directory Contract

Codex task packets live under:

```text
E:\AgentOS\data\codex_tasks\
```

Recommended structure:

```text
E:\AgentOS\data\codex_tasks\YYYY-MM-DD-<task-slug>\
  TASK.md
  INPUTS\
  OUTPUTS\
  STATUS.md
```

Project execution artifacts should live under:

```text
E:\AgentOS\data\projects\<project_id>\
  PROJECT_PLAN.md
  working\
  delivery\
  REVIEW_NOTES.md
```

## Task Packet Format

Hermes creates `TASK.md` with this format:

```markdown
# Codex Task: <short title>

Owner: Hermes
Reviewer: Josh
Created: YYYY-MM-DD HH:mm Asia/Taipei
Working directory: <absolute path>

## Objective
<one concrete outcome>

## Context
<client/project/lead context, relevant files, constraints>

## Inputs
- <path or data source>

## Required Output
- Write summary to `OUTPUTS/RESULT.md`
- Write changed files in-place or under `OUTPUTS/` as instructed
- Include test/verification results

## Acceptance Criteria
- <checkable criterion 1>
- <checkable criterion 2>

## Safety Rules
- Do not contact clients
- Do not expose credentials or tokens
- Do not overwrite unrelated files
- Ask Hermes/Josh if blocked by missing secrets or business decisions
```

## Dispatch Methods

Preferred, when Codex CLI is available locally:

```powershell
codex --cwd <working-directory> < E:\AgentOS\data\codex_tasks\YYYY-MM-DD-<task-slug>\TASK.md
```

Fallback, if Hermes proxy is working and Codex must use the local proxy:

```powershell
$env:OPENAI_BASE_URL = "http://localhost:8080/v1"
codex --cwd <working-directory> < E:\AgentOS\data\codex_tasks\YYYY-MM-DD-<task-slug>\TASK.md
```

If a non-interactive Codex command is unavailable, Hermes should create the task packet and notify Josh with the exact packet path and requested action.

## No Human Relay Rule

Josh should not be the routine message carrier between Hermes and Codex.

When Hermes has enough context and the work is within approved boundaries,
Hermes should dispatch Codex directly through the available bridge or CLI
method, then read `OUTPUTS\RESULT.md` and summarize only the decision-relevant
result to Josh.

Hermes should ask Josh only when one of these is true:

- the task requires approval for deletion, archive, install/update, credentials,
  governance changes, client-facing messages, or live external actions;
- the bridge/CLI path is blocked and the blocked artifact shows a concrete
  manual action is needed;
- the task intent is ambiguous enough that executing would be unsafe;
- Josh explicitly asks to review the prompt before dispatch.

Hermes should not ask Josh to copy a Codex prompt into Codex or paste Codex
output back into Hermes when an existing bridge can perform the handoff.

## Autonomous Dispatch Evidence

For each autonomous dispatch, Hermes should preserve:

```text
data\codex_tasks\YYYY-MM-DD-<task-slug>\
  TASK.md
  OUTPUTS\RESULT.md
  STATUS.md              optional
```

If Claude is involved:

```text
data\codex_tasks\YYYY-MM-DD-<task-slug>\
  CLAUDE_REVIEW_PROMPT.md
  OUTPUTS\CLAUDE_REVIEW.md
```

If a live bridge run is used:

```text
data\live_bridge\<bridge-id>\
  01_HERMES_DISPATCH.md
  02_CODEX_OUTPUT.md
  03_CLAUDE_REVIEW.md   when applicable
  04_HERMES_FINAL_SUMMARY.md
  TRANSCRIPT.md
```

## Result Collection

Codex writes:

```text
OUTPUTS\RESULT.md
```

with this shape:

```markdown
# Result

Status: success | partial | blocked | failed

## Summary
<what changed or what was learned>

## Files Changed
- <path>

## Verification
- <command>: pass/fail/not run

## Blockers
<any missing credentials, approvals, external systems>

## Next Action for Hermes/Josh
<clear next step>
```

Hermes then reads `OUTPUTS/RESULT.md`, condenses it for Josh, and records the next state in the relevant project or lead file.

For proposal validation tasks, Hermes should also update the proposal draft with one of:

- `Technical validation: passed`
- `Technical validation: partial`
- `Technical validation: blocked`
- `Technical validation: not needed`

Codex should include enough evidence in `RESULT.md` for Hermes to summarize confidently: commands run, files inspected, assumptions, and remaining risks. Hermes owns the business interpretation; Codex owns the technical finding.

## Failure Handling

- Codex may retry implementation failures up to 3 times when the issue is technical and local.
- After 3 failed attempts, Hermes summarizes the failure and asks Josh whether to continue, simplify scope, or switch model/tool.
- If failure is caused by credentials, quota, OAuth, or external service access, stop immediately and report the required action.

## Status Values

`STATUS.md` should use one of:

- `queued`
- `running`
- `needs_review`
- `blocked`
- `done`
- `cancelled`

Hermes owns status transitions. Codex may suggest status but should not silently mark business work as complete without Hermes/Josh review.

## Minimal Hermes Checklist

Before dispatch:

- Objective is concrete
- Working directory is explicit
- Inputs are attached or linked
- Acceptance criteria are checkable
- Secrets are not embedded

After return:

- Read result
- Verify changed files or command output if needed
- Summarize to Josh via Telegram
- Save final artifact in AgentOS data/workflows/docs as appropriate

## Current Boundary

This is a file-packet workflow, not a daemon contract. Until a real Hermes -> Codex -> Hermes cycle succeeds, do not build an automatic Codex runner, queue worker, or database-backed task system.

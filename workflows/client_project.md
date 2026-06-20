# Client Project Workflow

This workflow starts after Josh approves a proposal or asks AgentOS to prepare a delivery plan.

## Project Directory

```text
E:\AgentOS\data\projects\<project_id>\
  PROJECT_PLAN.md
  working\
  delivery\
  REVIEW_NOTES.md
```

## Flow

1. Hermes creates or updates `PROJECT_PLAN.md` from the approved scope.
2. Hermes creates Codex task packets for implementation work.
3. Codex edits files, runs verification, and writes each task result to `OUTPUTS\RESULT.md`.
4. Hermes summarizes progress to Josh and records review notes.
5. Josh approves any client-facing delivery message.

## Boundaries

- Do not start project execution from an unscreened lead.
- Do not let Codex send client messages directly.
- Do not create a project database until file-based project records are insufficient.

# AgentOS CI Smoke Gate

`scripts\agentos_ci_smoke.ps1` is the deterministic pre-flight gate for AgentOS workflow, runner, and governance changes.

It is designed to catch the failures that repeatedly break task execution:

- governance drift blocking queue execution
- PowerShell syntax errors in core scripts
- verify prompt / escalation fixture regressions
- classifier routing regressions
- `start_task_queue.ps1` `Path` / `PATH` duplicate handling
- Antigravity `outputs_only` and `workspace-write fallback` runner contracts
- Python syntax regressions in key local services
- optional dashboard `/api/health` availability

The smoke gate must not call models, contact external services, approve baseline, rerun queue, or process real work.

## Required Command

Run this before and after workflow, runner, or governance changes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\agentos_ci_smoke.ps1 -AgentOSRoot E:\AgentOS -NoDashboard
```

Use dashboard health as a warning-only check:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\agentos_ci_smoke.ps1 -AgentOSRoot E:\AgentOS
```

Require dashboard health only when the task explicitly changes dashboard runtime behavior:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\agentos_ci_smoke.ps1 -AgentOSRoot E:\AgentOS -RequireDashboard
```

## Result Artifacts

Every run writes:

- `data\ci_health\latest.json`
- `data\ci_health\latest.md`
- `data\ci_health\ci-smoke-<timestamp>.json`
- `data\ci_health\ci-smoke-<timestamp>.md`

## Status Meaning

- `PASS`: the baseline smoke checks passed.
- `WARN`: no blocking workflow issue was found, but an optional service or environment check needs attention.
- `FAIL`: stop before running real queue, dispatcher, worker, or governance approval flows.

If `governance_gate` fails because the current task intentionally changed governed files, review the changed files, get Josh approval when appropriate, run `sync_shared_governance.ps1 -ApproveBaseline`, then rerun the smoke gate.

## CI Fixture Safety

The script creates stable dry-run fixtures under `data\codex_tasks\ci-smoke-*`.

These fixtures use `dispatch_status: ci_smoke_only` and must not be processed as real queue tasks.

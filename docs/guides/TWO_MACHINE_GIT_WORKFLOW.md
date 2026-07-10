# Two-Machine Git Workflow

Each computer keeps its own ignored runtime state, credentials, virtual environments, and build output. Source changes travel through task branches and pull requests.

## Start Work

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\entrypoints\agentos-work-start.ps1 -TaskName <short-name>
```

The command requires a clean worktree and aligned governance, fetches `origin`, updates `master` using `--ff-only`, and creates `codex/<short-name>`. It never stashes, resets, resolves conflicts, or force pushes.

## Check Work

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\entrypoints\agentos-check.ps1
```

This runs deterministic AgentOS smoke, repository hygiene, frontend lint, and the production frontend build. Missing frontend dependencies are a local warning; GitHub CI remains mandatory.

## Finish Work

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\entrypoints\agentos-work-finish.ps1 `
  -Files scripts/example.ps1,tests/example.ps1 `
  -Message "fix: example" `
  -Push
```

Files must be listed explicitly. The command refuses `master`, refuses `.`, runs checks before commit, and pushes only when `-Push` is present.

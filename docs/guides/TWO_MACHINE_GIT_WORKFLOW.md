# Two-Machine Git Workflow

Each computer keeps its own ignored runtime state, credentials, virtual environments, and build output. Source changes travel through task branches and pull requests.

## Machine Acceptance Drill

On each computer, preview the isolated fresh-clone drill first:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\entrypoints\agentos-machine-acceptance.ps1 -MachineId machine-2
```

Run it only when the previewed target is correct. The explicit execution clones into a new directory, installs locked Dashboard dependencies, creates a fixture-only branch, runs the full local gate, explicitly commits that fixture, pushes the branch, and opens a PR. It never overwrites or deletes the clone.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\entrypoints\agentos-machine-acceptance.ps1 -MachineId machine-2 -ExecuteExternalDrill
```

Machine-local evidence is written to `data\machine_acceptance\machine-2.json` inside the acceptance clone and remains excluded from Git.

## Bootstrap A Fresh Clone

Run `scripts\entrypoints\agentos-bootstrap-check.ps1` first. It reports required tools and missing machine-local state without installing anything. When Dashboard dependencies are missing, explicitly run `dashboard\start.ps1 -Install`; this creates `dashboard\backend\.venv`, installs locked frontend dependencies, and builds the production frontend. Credentials remain machine-local and must be configured separately from `.env.example`.

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

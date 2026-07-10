# AgentOS Clean Repository, Control Center, CI/CD, and Observability Roadmap

date: 2026-07-11 Asia/Taipei
status: proposed roadmap; implementation requires phase-by-phase approval
source_inventory: `docs\reports\2026-07-11_AGENTOS_REPOSITORY_AND_RUNTIME_INVENTORY.md`

## Target outcome

Two computers can work against one canonical GitHub repository without copying runtime debris or overwriting each other. Every supported AgentOS runtime has one discoverable start/stop/status entry in a central control application. Every change passes the same local and GitHub checks. The dashboard reports evidence-backed runtime and task state and degrades gracefully when one service is down.

## Delivery tracks

The roadmap is split into two releases so stability work cannot silently expand into a desktop application and full frontend rewrite.

### Release A - Stability baseline

- Phase 0: preserve and reconcile repository history.
- Phase 1: define the clean source/runtime boundary.
- Phase 2: add the script registry and migrate paths with compatibility wrappers.
- Phase 3: archive approved historical material.
- Phase 5: establish the guarded two-computer local Git workflow.
- Phase 6: add GitHub Actions and branch protection.
- Phase 7: repair Dashboard availability.
- Phase 8A only: minimum deterministic observability required to support runtime health, failure evidence, and degraded states.

Release A ends with a formal stop-and-evaluate gate. Phase 4 and Phase 8B do not become authorized merely because Release A was approved or completed.

### Release B - Operator experience

- Phase 4: optional standalone Control Center executable.
- Phase 8B: optional RAG task assistant, information-architecture rewrite, and complete decision-path visualization.

Release B starts only if Release A evidence shows that the remaining usability cost justifies another application or a broad Dashboard redesign.

## Non-negotiable design rules

1. Git tracks source, configuration templates, schemas, tests, and curated documentation. It does not track secrets, live queues, logs, generated exports, local databases, worker output, or machine-specific state.
2. `master` is protected. Work occurs on task branches; GitHub Actions runs after a branch push; only passing pull requests merge to `master`.
3. A local preflight/pre-push gate runs before a push. GitHub CI cannot run before a push reaches GitHub, so local hooks provide the early guard and Actions provides the independent guard.
4. Pulling is allowed only into a clean worktree and uses fast-forward-only behavior. Divergence or local edits stop with a readable instruction; no automatic reset or stash.
5. Scheduled-task paths remain stable until compatibility wrappers and migration receipts exist.
6. Observability is deterministic and fail-open. Governance remains fail-closed.
7. Archive precedes deletion. Every archive batch has a manifest and restore path.

## Phase 0 - Preserve and choose the canonical history

Goal: establish a recoverable baseline before cleanup.

Work:

- Record hashes and sizes for the local tree, current export ZIP files, and Git metadata.
- Preserve the current local branch and the GitHub `master` commit as named recovery refs.
- Compare local source against GitHub export by content, not by assumed shared history.
- Josh chooses one reconciliation method:
  - Recommended: create a new cleanup branch from the GitHub export, import selected current local source, then merge through a reviewed pull request.
  - Alternative: replace GitHub `master` with a cleaned local history after a separately approved force-update plan.
- Configure `origin` only after the chosen method and exact target are recorded.

Acceptance:

- Both current states have immutable commit or archive references.
- A dry-run comparison lists added, changed, excluded, and conflict files.
- No force push, deletion, or baseline approval occurred implicitly.

Josh approval gate: choose the reconciliation method.

## Phase 1 - Define the clean repository boundary

Goal: make a fresh clone reproducible and keep runtime state local.

Source candidates to track:

- `AGENTS.md`, `README.md`, `agents\`, `config\` templates, `dashboard\` source, `docs\`, `integrations\`, `prompts\`, `scripts\`, `tests\`, `tools\`, `workflows\`.
- Curated fixtures and schemas under `data\`, but not live task/event/output data.

Local/runtime candidates to ignore or externalize:

- `.env`, credentials, local databases, `.venv`, `node_modules`, `.next`, logs, live bridges, queue runs, routing decisions, generated exports, CI reports, task outputs, escalation decisions, usage state, ZIP exports, scratch, and personal folders.

Work:

- Replace the current narrow `.gitignore` with explicit source/runtime rules.
- Add `.env.example` and machine bootstrap documentation without secrets.
- Create `data\README.md` describing which subtrees are generated and which fixtures are tracked.
- Add a clean-clone bootstrap check that reports missing local dependencies without installing them automatically.

Acceptance:

- Fresh clone contains no secret or personal/runtime artifact.
- `git status` remains clean after one CI smoke run and one normal dashboard read cycle.
- Secret scan, large-file scan, and generated-file scan pass.

Josh approval gate: exact include/exclude manifest.

## Phase 2 - Script registry and safe directory structure

Goal: make scripts understandable without breaking callers.

Proposed internal layout:

```text
scripts/
  entrypoints/       # stable human/scheduler commands
  governance/        # gate and baseline tools
  workflow/          # classify, dispatch, queue, supervisor, escalation
  runtimes/          # Hermes and dashboard lifecycle helpers
  workers/           # Claude/Codex/Antigravity/free-provider bridges
  intake/            # Telegram, URL, Threads, publishing
  knowledge/         # NotebookLM, Obsidian, learning collection
  observability/     # health, usage, runtime collector
  maintenance/       # setup, environment, migration, evaluation
  standalone/        # fan control and unrelated utilities
```

Work:

- Add `config\script_registry.json` as the single machine-readable inventory. Each entry contains id, display name, category, implementation path, start mode, stop strategy, health check, logs, expected identity, risk, dependencies, and whether it is enabled.
- Keep root-compatible wrapper scripts for all scheduled or documented entrypoints during migration.
- Migrate one category per change set and update static callers, scheduled tasks, tests, docs, and governance hashes together.
- Add a static test that every registry path exists and every scheduled entrypoint resolves.

Acceptance:

- All 52 executable files are represented exactly once in the registry or in an approved archive manifest.
- Existing scheduled tasks still start the same runtime during the compatibility period.
- Repository-wide reference scan finds no stale old path after each category migration.
- CI smoke and syntax checks pass after every batch.

Josh approval gate: directory map, first migration batch, and each archive manifest.

## Phase 3 - Archive documents and retired scripts

Goal: keep active documentation small while preserving evidence.

Work:

- Move backup copies and dated one-off reports out of active governance/document directories according to an approved manifest.
- Add an archive index with original path, current path, SHA-256, reason, dependencies checked, restore command, and approval.
- Rebuild `docs\INDEX.md` from active categories and clearly label canonical, operational, roadmap, report, and historical status.
- Mark superseded documents before archival when another document replaces them.
- Do not delete archived material in this phase.

Acceptance:

- Active docs have one clear owner/category and no `.bak-*` files.
- All moved paths are covered by reference tests or compatibility links where needed.
- Governance scan is aligned after Josh approves the governed-file changes.

Josh approval gate: exact archive manifest and governance baseline update.

## Phase 4 - AgentOS Control Center executable

Goal: provide one safe place to start, stop, restart, and inspect supported runtimes.

Recommendation: build a Windows single-file `.NET` desktop executable named `AgentOS Control Center.exe`, backed by `config\script_registry.json`. A Streamlit/PyInstaller shell is possible, but it would add another Python/web runtime and is a weaker fit for managing crashed processes. The final technology choice remains Josh's decision.

Required functions:

- Runtime list grouped by startup, on-demand workflow, maintenance, and retired/disabled.
- Start, stop, restart, and open-log actions with confirmation for disruptive operations.
- Actual status based on PID, command line, port, heartbeat, and last log timestamp; never only a green button state.
- Display expected versus actual Windows identity.
- Show scheduled-task state and last result.
- One-click CI health check and links to the latest report.
- Read-only by default; no baseline approval, task deletion, force kill outside registered process identity, commit, or push.
- A concise generated `README.md` listing every registry item and its purpose.

Safety boundary:

- Stop actions must match registered process path/command line and known port before termination.
- Scheduled-task edits, governance baseline approval, and archive/delete operations stay outside the executable unless separately approved later.
- Secrets never appear in command previews or logs.

Acceptance:

- Start/stop/status works for Dashboard, Hermes main, Hermes Lite, and one on-demand queue fixture.
- A deliberately unrelated process on the same executable name is not terminated.
- The executable works from a fresh clone after documented bootstrap.
- Registry README generation is deterministic and CI-tested.

Josh approval gate: `.NET` desktop versus packaged Streamlit implementation and the allowed action set.

## Phase 5 - Local Git workflow for two computers

Goal: make every work session begin and end predictably.

Commands to implement as guarded entrypoints:

- `agentos-work-start`: verify identity, repository, clean status, governance alignment, fetch origin, and fast-forward-only pull of `master`; then create/switch to a task branch.
- `agentos-check`: run governance gate, syntax checks, unit/regression tests, frontend lint/build, backend compile/import, secret scan, and repository hygiene checks.
- `agentos-work-finish`: show scoped diff, require explicit file staging, commit to the task branch, run pre-push checks, and push that branch.

Rules:

- Never use `git add .`.
- Never edit directly on `master`.
- Never auto-stash, reset, resolve conflicts, or force push.
- Each computer uses its own machine-local environment and credentials; these are not synced by Git.

Acceptance:

- Both computers can clone/bootstrap, start a branch, make a fixture-only change, pass checks, push, and open a PR.
- A dirty worktree, divergent branch, stale master, missing governance binding, or failed smoke check stops safely with a clear message.

Josh approval gate: branch naming and whether all changes require PR review.

## Phase 6 - GitHub Actions and branch protection

Goal: independently verify every proposed merge.

Proposed workflows:

- `ci-core.yml`: PowerShell syntax, Python compile/import, deterministic fixture tests, governance consistency, registry/path validation, and repository hygiene.
- `ci-dashboard.yml`: frontend install/lint/build and backend dependency/import tests.
- `ci-security.yml`: secret scan, dependency review, and oversized/generated artifact guard.
- Optional Windows smoke job for PowerShell 5.1 and path/case behavior; Linux jobs must not claim Windows runtime verification.

Branch protection for `master`:

- Pull request required.
- Required checks must pass.
- Branch must be current before merge.
- No force pushes or deletion.
- Prefer squash merge for task branches unless history preservation is needed.

Acceptance:

- A known-bad fixture fails locally and in Actions.
- A valid fixture passes on both.
- A direct unverified update to `master` is rejected.

Josh approval gate: enable branch protection and required checks on GitHub.

## Phase 7 - Dashboard availability repair

Goal: make the dashboard dependable before adding more panels.

Priority repairs:

- Remove development `--reload` from the scheduled dashboard runtime; keep a separate explicit development command.
- Add PID/health lifecycle receipts and ensure scheduled launch verifies ports after child startup.
- Add zero-dependency `/api/health` and frontend degraded states with last-success timestamps.
- Add CI tests for production startup and graceful shutdown with WebSockets connected.

Acceptance:

- Dashboard survives source-file timestamp changes in production mode.
- Scheduled task reports failure when child services fail to bind.
- Frontend indicates backend-down state instead of appearing empty or frozen.

## Phase 8 - Runtime observability and dashboard redesign

Goal: turn the dashboard into a factual operating console.

Use the existing `agentos_runtime_observability_roadmap_2026-07-10.md` as design input, with a fresh verification against current governance and runtime evidence.

Product changes:

Phase 8A, stability scope:

- Add a deterministic runtime registry, zero-dependency health evidence, failure taxonomy, and degraded states.
- Split usage into factual sources: Hermes recorded tokens/cost, current session context estimate, and provider quota status. Unknown provider quota must display `unknown`, never a guessed percentage.
- Provide a minimal event trail sufficient to answer which runtime failed, when, with which artifact and exit code.

Phase 8B, experience scope:

- Replace duplicated task views with one task workspace containing list, status, dependency, outputs, escalation, and event trail tabs.
- Replace the decorative terminal with a complete dispatch event timeline: actor, script, process, input artifact, output artifact, result, duration, and next step.
- Replace the no-tool Groq chat with a read-only task-status assistant that retrieves from structured local APIs/artifacts and cites its source paths and timestamps. Model use is optional for phrasing; factual retrieval remains deterministic.
- Add complete Runtime Map, Failure Path, and Decision Path views from the observability roadmap.

Acceptance:

- Asking a task-status question returns the correct status, last event, blocker, and artifact links for sampled dispatches.
- Every displayed runtime state is traceable to process/port/heartbeat/log evidence.
- Stopping backend, gateway, or a worker produces a deterministic degraded/down state without breaking unrelated panels.
- Dashboard reads do not mutate queue, governance, or task state.

Josh approval gate: final information architecture and whether the current `DecisionMap`, `TaskBoard`, `TaskUniverse`, `LiveLogs`, and `HermesChat` components are replaced or retained.

## Recommended execution order

1. Phase 0 history decision.
2. Phase 1 clean source/runtime boundary.
3. Phase 7 dashboard lifecycle repair, because the current control surface is down.
4. Phase 2 script registry and compatibility migration.
5. Phase 3 approved archival.
6. Phase 5 and Phase 6 two-computer Git/CI workflow.
7. Phase 8A minimum deterministic observability.
8. Stop and evaluate Release A against measured stability outcomes.
9. Consider Phase 4 and Phase 8B only as a separately approved Release B.

This order deliberately builds the registry before any executable, cleans the repository before GitHub branch protection, and repairs Dashboard availability before asking it to become an observability console. It does not assume that Release B will be built.

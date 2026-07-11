# AgentOS Live Tree Cutover Plan (Proposed)

date: 2026-07-11 Asia/Taipei
status: proposed; requires Josh approval before any step executes
depends_on: PR #1 merged to `master`; machine-2 acceptance drill passed
gap_addressed: the Phase 0-8 roadmap defines the clean repository but not how the
live `E:\AgentOS` tree (scheduled tasks, runtime state, credentials) switches to it.

## Design rules

1. Runtime state never migrates through Git. Queues, logs, escalations, metrics,
   `.env`, and databases stay in place on each machine.
2. Scheduled-task action paths change only after compatibility wrappers are verified
   and a migration receipt exists (roadmap rule 5).
3. Every step is reversible; the pre-cutover tree is preserved until Josh approves
   its archival. No deletion during cutover.
4. Governance stays fail-closed: `assert_governance_ready.ps1` must report `aligned`
   in the new tree before any worker dispatch runs there.

## Recommended approach: in-place adoption (no path move)

Keep `E:\AgentOS` as the canonical path so all scheduled tasks, wrappers, and
documentation remain valid. Adopt the merged history into the live tree instead of
moving the live tree onto the clone.

### Step 0 - Preconditions (evidence required)

- PR #1 merged; `origin/master` head recorded.
- Machine-2 drill artifact retained.
- Full pre-cutover snapshot: record tree hash listing and sizes for `E:\AgentOS`
  (excluding `.venv`/`node_modules`) to a dated manifest under `scratch\`.

### Step 1 - Bind the live tree to the canonical repository

- In `E:\AgentOS`: initialize/point Git at `origin` = GitHub AgentOS, fetch, and
  check out `master` WITHOUT overwriting untracked runtime state (`git checkout`
  guarded; the Phase 1 `.gitignore` already excludes runtime paths).
- Resolve any tracked-file conflicts by diff review, never by reset or stash.
- Acceptance: `git status` clean; runtime directories untouched (spot-check queue,
  escalations, metrics, `.env` mtimes unchanged).

### Step 2 - Verify runtimes on the adopted tree

- Run `agentos-check` and the CI smoke locally.
- Start/stop Dashboard and Hermes Lite via compatibility entrypoints; verify
  scheduled tasks still resolve (read-only `schtasks` query, no edits).
- Acceptance: smoke PASS; governance `aligned`; dashboard health endpoint OK.

### Step 3 - Retire the working clone

- `scratch\release-a-cleanup` becomes historical evidence; archive manifest with
  SHA-256 and restore path per Phase 3 rules, then removal only on Josh approval.

### Step 4 - Machine 2 bootstrap

- Fresh clone + documented bootstrap; own `.env` and credentials; run the
  acceptance drill; never sync runtime state between machines.

## Rollback

Any failed acceptance stops the cutover. The live tree's pre-cutover state is
recoverable from the Step 0 manifest plus untouched runtime directories; Git
binding can be removed by deleting only the newly created `.git` binding (requires
Josh approval, listed here for completeness).

## Josh approval gates

1. Approve this plan and the in-place adoption approach (versus moving to a fresh
   clone directory and repointing scheduled tasks).
2. Approve Step 1 execution window (no queue runs during cutover).
3. Approve clone archival after Step 3.

# Phase 1 Source and Runtime Boundary Result

date: 2026-07-11 Asia/Taipei
status: boundary implemented in isolated cleanup branch; tracked removals waiting for approval
branch: `codex/release-a-cleanup`
base: `ca497ec6fa5bcc1e5f3e7a3a5542b9618aa9ac0c`
live_workspace_modified: false
github_write_performed: false

## Result

Phase 1 has a working source/runtime policy and deterministic hygiene checker in
the isolated clone at `E:\AgentOS\scratch\release-a-cleanup`. Current AgentOS
governance and the explicitly selected post-export source files were imported.
No tracked runtime file has been removed yet.

## Added boundary files

- `.gitattributes`: explicit CRLF for Windows PowerShell/batch and LF for cross-platform text.
- `.gitignore`: secrets, dependencies, build output, runtime data, exports, projects, logs, and machine-local state.
- `.env.example` and `dashboard/frontend/.env.example`: names only, no credentials.
- `config/repository_boundary.json`: machine-readable source/runtime policy.
- `config/source_import_manifest.json`: exact files imported from the live workspace.
- `data/README.md`: explains what may be tracked under `data`.
- `scripts/repository_hygiene_check.ps1`: required file, tracked path, data allowlist, size, and possible literal-secret checks.

## Imported current source

- All 81 files in the Josh-approved governance baseline were copied from the
  aligned live workspace. The clone then passed governance without running
  `-ApproveBaseline`.
- Eighteen explicitly listed post-export source files were imported, including
  CI smoke, draft promotion, Hermes Lite registration, Antigravity role/runtime,
  Fable5/observability reports, cleanup reports, Threads tools, Upwork tools, and
  the verification fixture.
- The verification fixture was moved from the live runtime path
  `data/tasks/fixtures/` to source path `tests/fixtures/`; cleanup CI now uses the
  source path.
- `.env.local`, TypeScript build metadata, and fan-control logs were excluded.

## Portability fixes discovered by clean-clone CI

1. `invoke_antigravity_subagent.ps1` hard-coded `E:\AgentOS`, causing a cleanup
   clone dry-run to touch the live governance gate. The cleanup version now
   accepts `-AgentOSRoot` and otherwise resolves the root from its script path.
2. Python compile discovery could land on a broken Windows Store alias. Cleanup
   CI now checks the dashboard runtime, Codex bundled runtime, Hermes runtime,
   and ordinary PATH candidates in a deterministic order and skips WindowsApps
   aliases.

These fixes exist only in the cleanup branch and have not changed the live
runtime.

## Verification

- Governance gate: PASS, aligned, version 1.2.0, canonical hash
  `A29DDC3DE4701A07BECCCB95E9A7DA9A3B897D2C1C60FAD61416C6C85EED666F`.
- CI smoke: PASS, 0 failures, 0 warnings.
- CI artifact: `data/ci_health/ci-smoke-20260711-015847.md` (ignored runtime output).
- Backend direct import using the working Dashboard Python runtime: PASS.
- Frontend production build with Next.js webpack builder: PASS.
- Frontend lint: FAIL with 7 existing React `set-state-in-effect` errors and 4
  warnings. These are current Dashboard source issues and belong to Phase 7;
  they were not silently disabled or fixed during repository cleanup.
- Default Turbopack build with an external `node_modules` junction: not a valid
  test because Turbopack rejects dependencies outside the project filesystem
  root. The webpack build proves the imported TypeScript source compiles.

## Tracked runtime migration manifest

Artifact:
`docs/reports/2026-07-11_PHASE1_TRACKED_RUNTIME_MIGRATION_MANIFEST.json`

- Tracked files inspected: 839.
- Proposed untrack paths: 651.
- Total bytes: 9,174,387.
- `FORBIDDEN_PATH_TRACKED`: 403.
- `RUNTIME_DATA_TRACKED`: 248.
- Possible literal secrets: 0 from the deterministic scanner.

Each entry includes path, finding code, byte size, SHA-256, proposed action,
live-workspace effect, and a restore command. The proposed action is always
`untrack_from_cleanup_branch_only`; it never deletes the live file.

Top groups:

| Group | Paths | Bytes |
|---|---:|---:|
| `data` runtime/history | 248 | 591,494 |
| generated `exports` | 167 | 587,057 |
| embedded `projects` copies | 166 | 7,748,071 |
| `assets/github-ready` duplicate candidates | 65 | 241,189 |
| `docs/.obsidian` machine state | 5 | 6,576 |

## Dependency boundary

The runtime source scan found no code dependency on `projects/` or
`assets/github-ready/`. Export scripts intentionally write to `exports/`; that
directory remains available locally but is ignored by Git.

Independent project repositories confirmed:

- `data-quality-audit-toolkit`
- `ecommerce-market-intelligence-dashboard`
- `ecommerce-operations-automation-pipeline`
- `josh-resume`
- `josh-resume-release-candidate`

Hold before untracking:

- `projects/josh-resume-portfolio-update/**`: 24 paths; no independent Git repo.
- `projects/staging_site/**`: 1 path; no independent Git repo.
- `assets/github-ready/**`: retain in the manifest until duplicate/content
  comparison is independently reviewed.

Untracking is reversible from GitHub commit `ca497ec...`, but these hold groups
should not be included in the first approved migration batch.

## Next approval

Approve a first migration batch limited to:

- `data/**` paths listed in the manifest, except the approved baseline and schemas.
- `exports/**` paths listed in the manifest.
- `docs/.obsidian/**` paths listed in the manifest.
- project paths that have an independently confirmed repository.

Do not yet approve `josh-resume-portfolio-update`, `staging_site`, or
`assets/github-ready` removals.

Approval authorizes `git rm --cached` only inside the isolated cleanup branch.
It does not delete files from `E:\AgentOS`, push a branch, open a PR, modify
GitHub settings, archive files, or approve a governance baseline.

## Claude review prompt

```text
請以獨立 reviewer 身份覆核 AgentOS Phase 1 source/runtime boundary，只讀，不修復、不執行 git rm、不 commit、不 push。

工作目錄：E:\AgentOS\scratch\release-a-cleanup
基底 commit：ca497ec6fa5bcc1e5f3e7a3a5542b9618aa9ac0c
分支：codex/release-a-cleanup

必讀：
1. AGENTS.md
2. config/repository_boundary.json
3. config/source_import_manifest.json
4. docs/reports/2026-07-11_PHASE0_GIT_ALIGNMENT_DECISION_PACKET.md
5. docs/reports/2026-07-11_PHASE1_SOURCE_RUNTIME_BOUNDARY_RESULT.md
6. docs/reports/2026-07-11_PHASE1_TRACKED_RUNTIME_MIGRATION_MANIFEST.json
7. scripts/repository_hygiene_check.ps1

逐項驗證：
1. 651 筆 proposed untrack 是否都符合 boundary，是否誤含核心 source、治理正本、schema 或測試 fixture。
2. data allowlist 是否過窄或過寬；fresh clone 是否仍能建立必要 runtime 目錄。
3. projects、assets/github-ready、exports 的相依性判斷是否成立；特別標出沒有獨立 repo 或無法重建的內容。
4. .gitignore 與 .gitattributes 是否適合 Windows PowerShell 5.1、Python、Next.js 與雙機協作。
5. hygiene checker 是否存在 fail-open、漏掃 untracked source、洩漏 secret 值或錯誤 restore command。
6. 確認本次沒有修改 E:\AgentOS live source、沒有 baseline approval、沒有 GitHub write。

回報格式：
verdict: PASS | FAIL | NEEDS_HUMAN_DECISION
blocking_findings: 依嚴重度列出 path/line/evidence
safe_first_batch: 可安全 git rm --cached 的精確群組
hold_groups: 必須保留或先補證的群組
tests_checked: 實際執行命令與結果
change_required: true | false
```

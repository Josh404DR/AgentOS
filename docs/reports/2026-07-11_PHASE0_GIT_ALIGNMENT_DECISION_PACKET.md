# Phase 0 Git Alignment Decision Packet

date: 2026-07-11 Asia/Taipei
status: resolved; Josh approved Option A and the isolated cleanup branch was created without force push
governance_version: 1.2.0
governance_hash: A29DDC3DE4701A07BECCCB95E9A7DA9A3B897D2C1C60FAD61416C6C85EED666F

resolution: `codex/release-a-cleanup` was created from GitHub `master` in `E:\AgentOS\scratch\release-a-cleanup`; source was imported through explicit commits and PR #1. The original decision evidence below remains the pre-mutation record.

## Verdict

Do not attach the current `E:\AgentOS` checkout directly to GitHub and do not use the `.git` directory embedded in `AgentOS_export_with_git.zip` as the new baseline.

Recommended path: use a fresh clone of GitHub `master` as an isolated cleanup workspace, import only approved current source files from `E:\AgentOS`, validate the result, and push a new branch for review. Keep `E:\AgentOS` running unchanged until the clean clone passes Release A checks. This avoids force push and avoids merging runtime debris or an unrelated 131-commit local history into the one-commit export history.

## Execution boundary

Completed in this phase:

- Read governance, CI, local Git metadata, ZIP metadata, and GitHub repository metadata.
- Extracted both existing ZIP files to a timestamped directory under `C:\tmp`.
- Cloned the public GitHub repository to `C:\tmp\agentos-phase0-remote-20260711-0130` for read-only comparison.
- Calculated hashes and content differences.

Not performed:

- No `origin` was added to `E:\AgentOS`.
- No branch, tag, recovery ref, commit, merge, stash, reset, checkout, push, pull, or force push was performed in `E:\AgentOS`.
- No GitHub file, setting, branch protection rule, issue, or pull request was changed.
- No source, runtime data, archive item, or evidence was deleted or moved.

## Baseline evidence

### Runtime identity and checks

- Actual execution identity: `LAPTOP-IMPR60B8\CodexSandboxOffline`.
- Governance: aligned, gate passed.
- CI smoke: PASS, zero failures and zero warnings.
- CI artifact: `data\ci_health\ci-smoke-20260711-012658.md`.

Because the active identity is not `brian`, this session must not be used for final credentialed GitHub writes or as proof that the normal operator identity can push.

### Local repository

- Path: `E:\AgentOS`.
- Branch: `master`.
- HEAD: `52873d68cb1e58f8a786aa1985a4262ddd0e4e95`.
- Root commit: `43201ee2ab4d63751008e28acd5d6265204929f2`.
- Commit count: 131.
- Remote: none.
- Working tree: heavily dirty, with both user changes and runtime/generated material.

### GitHub repository

- Repository: `Josh404DR/AgentOS`.
- Default branch: `master`.
- HEAD/root commit: `ca497ec6fa5bcc1e5f3e7a3a5542b9618aa9ac0c`.
- Commit count: 1.
- Tracked files: 839.
- Fresh clone status: clean and tracking `origin/master`.

The GitHub history is a standalone initial export, not a continuation of the local 131-commit history.

### Existing export files

| File | Bytes | SHA-256 |
|---|---:|---|
| `AgentOS_export.zip` | 3,231,736 | `401666FE29FDFB1992AD7E1DAC8383A128AB64F56C3B348137453B304FFBDFCE` |
| `AgentOS_export_with_git.zip` | 6,026,446 | `9B6C5CB9090FDFFBA35299DEE105BDCF6DF9A7B9A2DB5D196F374B5BC6C86C1F` |

The two exports contain 863 common non-Git files and all 863 are byte-identical. The with-Git archive adds only `push_github.bat` plus `.git` metadata.

The embedded Git checkout is not clean after extraction. Its index reports nearly every tracked file as modified with zero-line numstat and produces LF/CRLF warnings. It has `core.filemode=true`, no repository `.gitattributes`, and the machine Git installation has `core.autocrlf=true`. This archive is evidence, not a reusable clean checkout.

## Content comparison

### Export versus GitHub

- Export files: 864.
- GitHub tracked files: 839.
- All 839 GitHub paths exist in the export.
- 404 files are byte-identical.
- Most of the remaining byte differences are CRLF/LF conversion; after text normalization, 816 of 839 match.
- The 23 remaining anomalies are a legacy shell file, empty `.gitkeep` placeholders, and `.fuse_hidden*` artifacts. They do not justify using the ZIP Git metadata.
- The export has 25 files not committed to GitHub. These include raw/generated sample datasets, `dashboard\frontend\.env.local`, Next.js generated metadata, and a backup HTML file.

### Current local source since the export

Within the proposed source roots, 27 files exist locally but not in GitHub. The meaningful additions include:

- `scripts\agentos_ci_smoke.ps1`
- `scripts\promote_draft.ps1`
- `scripts\register_hermes_lite_autostart.ps1`
- `docs\claude_ops\*`
- the two new cleanup/roadmap reports
- the Fable5 ecosystem and runtime observability reports
- `prompts\context_packs\hermes_intake_menu.md`
- several `tools\threads` and `tools\upwork` files

Files in that same set that should not be imported blindly:

- `dashboard\frontend\.env.local`
- `dashboard\frontend\next-env.d.ts` unless the frontend policy explicitly tracks generated declarations
- `scripts\fan_control\fan_control.log`

Current local files with real post-export changes include governance, Hermes plugin, Dashboard backend, dispatch/queue scripts, Antigravity integration, escalation/metrics state, and documentation. They must be selected by scope; bulk copy is not acceptable.

## Repository weight and boundary evidence

Current directory sizes include:

- `dashboard`: about 832 MB and 65,210 files, dominated by local Node/build dependencies.
- `data`: about 215 MB and 7,760 files, dominated by runtime history and generated artifacts.
- `.git`: about 91 MB and 35,003 files.
- actual `scripts`: about 403 KB.
- actual `docs`: about 399 KB.

The repository is therefore not large because of core AgentOS source. It is large because source and local/runtime material share one directory tree.

No `.gitattributes` exists. A line-ending policy must be added before the first clean import so CRLF warnings cannot manufacture a repository-wide false diff again.

## Credential and secret boundary

- The export correctly omitted `.env` and the GitHub commit omitted `dashboard\frontend\.env.local`.
- `config\free_model_providers.json` names environment variables; the inspected key fields are environment-variable names, not printed credentials.
- Upwork authentication utilities and provider bridge scripts contain credential-handling code. They require an actual secret scanner before import; simple keyword matching is not sufficient evidence of safety.
- No credential value was printed into this report.

## Options at the approval gate

### Option A - Fresh-clone cleanup branch (recommended)

1. Keep `E:\AgentOS` as the running system.
2. Use a fresh clone based on GitHub commit `ca497ec...` in a separate clean workspace owned by `brian`.
3. Add `.gitattributes`, the source/runtime boundary, and import an explicit source manifest from current `E:\AgentOS`.
4. Run governance, CI, frontend/backend, secret, and repository-hygiene checks.
5. Push a new task branch and open a pull request only after local checks pass.

Properties: no force push, no unrelated-history merge, rollback by deleting the separate clone, and the live system remains untouched.

### Option B - Merge unrelated local history into GitHub history

Not recommended. It would combine 131 local commits, a heavily dirty worktree, and a one-commit export through an unrelated-history merge. Conflict and accidental-runtime inclusion risk are high, while the old history does not make the resulting clean source easier to reproduce.

### Option C - Replace GitHub history with cleaned local history

Not recommended and not authorized. It would require a separately reviewed force-update plan and would invalidate the current public baseline.

## Requested decision

Approve or reject Option A only. Approval of Option A authorizes creation of an isolated local cleanup workspace and Phase 1 source-boundary implementation. It does not authorize push, pull-request creation, branch protection changes, archival, deletion, or modification of the live `E:\AgentOS` runtime.

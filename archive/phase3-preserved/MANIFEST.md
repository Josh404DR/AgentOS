# Phase 3 Preserved Differences

date: 2026-07-11 Asia/Taipei
source_commit: `ca497ec6fa5bcc1e5f3e7a3a5542b9618aa9ac0c`
scope: cleanup branch only
live_workspace_deletion: none

This archive preserves the only content from the final 90 cleanup candidates
that was not byte-identical to an independently versioned project peer.

## GitHub-ready copies

Every non-archived file under these three `assets/github-ready` packages has an
identical relative-path peer under `projects/`, and each project has an
independent Git repository. Five differing packaging files are preserved here:

- `assets/github-ready/data-quality-audit-toolkit/.gitignore`
- `assets/github-ready/data-quality-audit-toolkit/README.md`
- `assets/github-ready/ecommerce-market-intelligence-dashboard/.gitignore`
- `assets/github-ready/ecommerce-operations-automation-pipeline/.gitignore`
- `assets/github-ready/ecommerce-operations-automation-pipeline/README.md`

Restore by copying the archived relative path back to the repository root, or
by checking the original path out of commit `ca497ec...`.

## Portfolio update

Seven non-hidden implementation files in `josh-resume-portfolio-update` are
byte-identical to both `josh-resume` and `josh-resume-release-candidate`.
`NOTES.md` is the only unmatched normal file and is preserved here. Sixteen
`.fuse_hidden*` entries are transient filesystem artifacts and are not copied.

## Staging placeholder

`projects/staging_site/README.md` is the only file in the placeholder directory
and is preserved here.

No live file was deleted or moved while creating this archive.

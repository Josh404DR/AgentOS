# Antigravity CLI Multi-Worker Scheduled Task Setup

governance_parent: E:\AgentOS\AGENTS.md
status: NEEDS_JOSH_EXECUTION (Claude cannot run Windows Task Scheduler commands remotely)
created: 2026-07-06

## Context

`config\antigravity_subagents.json` now has `free-a`, `free-b`, `free-c`, and
`pro` all `enabled: true`. `scripts\poll_antigravity_worker.ps1` is the
per-account satellite poller: it only picks up tasks whose resolved worker
alias matches the alias it was started with, and it hard-refuses to run under
the wrong Windows account.

`pro` maps to Josh's main login (`pkg0530hsu`) — since that account is
already logged in during normal use, no scheduled task is required for it;
`scripts\dispatch_task_packet.ps1` / `task_queue_runner.ps1` running in that
same session already reach it directly.

`free-a` / `free-b` / `free-c` are separate Windows accounts. Because Josh
keeps all three logged in concurrently (per his own report), the safest setup
is a per-account Scheduled Task with **"Run only when user is logged on"** —
this does NOT require storing that account's password anywhere, unlike "Run
whether user is logged on or not".

## One-time setup (repeat inside each of the 3 accounts' own session)

Log into the target Windows account (e.g. the session for `free-a`), open a
normal (non-elevated) PowerShell or Command Prompt **as that user**, and run:

```
schtasks /Create /TN "AgentOS_Antigravity_free-a" ^
  /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\AgentOS\scripts\poll_antigravity_worker.ps1 -WorkerAlias free-a -Once" ^
  /SC MINUTE /MO 5 /RL LIMITED /F
```

Repeat with `free-b` and `free-c` (swap every `free-a` above for the matching
alias) inside each of those two accounts' own sessions.

Notes:
- `/RL LIMITED` avoids requesting admin rights.
- No `/RU` / `/RP` flags are used, so the task runs as whoever creates it
  (the account you are logged into at the time) — no credentials are stored.
- `-Once` makes each invocation do a single scan-and-dispatch pass; the
  5-minute schedule provides the polling cadence instead of a long-running
  loop, so a crashed/logged-off session cannot leave an orphaned infinite
  loop behind.
- If E:\AgentOS is not reachable as the same drive letter from a given
  account's session (e.g. it's a mapped network drive under Josh's main
  account only), the `/TR` path needs to be adjusted per account before
  running the command — verify `Test-Path E:\AgentOS\AGENTS.md` succeeds
  under that account first.

## Verifying it's working

From within each account's session, after a few minutes:

```
Get-Content E:\AgentOS\logs\antigravity_poll_free-a.log -Tail 20
```

Expected lines: `cycle_complete processed=0` when idle, or
`dispatching id=<dispatch_id>` / `result id=<dispatch_id> exit=0 ...` when a
matching task was picked up.

## Removing a scheduled task later

```
schtasks /Delete /TN "AgentOS_Antigravity_free-a" /F
```

## Still open

- Governance baseline is currently `review_required` (drift in
  `current_state.md`, `scripts\dispatch_task_packet.ps1`,
  `scripts\task_queue_runner.ps1`). `invoke_antigravity_subagent.ps1` and
  `poll_antigravity_worker.ps1` both call `assert_governance_ready.ps1` and
  fail-closed until Josh runs `sync_shared_governance.ps1 -ApproveBaseline`.
- `pro` worker's `windows_user` was set to `pkg0530hsu` based on Josh's chat
  statement; not independently verified against the actual Windows account
  name (sandbox had no way to run `whoami` this session). Confirm it matches
  exactly, or `invoke_antigravity_subagent.ps1` / the poller will refuse to
  run under that account.
- `scripts\poll_antigravity_worker.ps1` is new and not yet added to the
  governed-file list in `scripts\sync_shared_governance.ps1`. Left out
  deliberately for this round; add it to that list (and re-approve baseline)
  once Josh has tested it, if he wants it hash-tracked going forward.

# AgentOS Dispatch Result

dispatch_id: telegram-telegram-1449022024-1203-20260704-124308-798485-child-01-hermes-gateway-autostart-audit
route_to: Claude
codex_mode: n/a
governance_version: 1.2.0
governance_hash: F442C94F00D21340DC70B56B2D08B017BE51AA5B1908D8ECD7E7F38DFF56C747
status: completed
models_invoked: true
scripts_executed: true
cleanup_executed: false
dry_run: false
review_dispatch_id: telegram-telegram-1449022024-1203-20260704-124308-798485-child-01-hermes-gateway-autostart-audit-codex-verify

## Findings

Audit report written to `OUTPUTS\AUDIT_REPORT.md`. Here is the full audit output:

---

## Hermes Gateway Autostart Audit
**dispatch_id:** `telegram-telegram-1449022024-1203-20260704-124308-798485-child-01-hermes-gateway-autostart-audit`

---

### Governance Gate

```
governance_gate=passed
governance_status=aligned
governance_version=1.2.0
governance_hash=F442C94F00D21340DC70B56B2D08B017BE51AA5B1908D8ECD7E7F38DFF56C747
governance_checked_at=2026-07-04T13:00:24.9406079+08:00
drift_count=0
task_execution_allowed=true
```
Source: `data\governance\governance_status.json` — read directly, no model calls.

---

### Sandbox Constraint

All shell executions (`Get-ScheduledTask`, `Get-ScheduledTaskInfo`, `Get-CimInstance`, `schtasks /query`) were blocked by the Claude Code sandbox permission system. No destructive retry was attempted. Evidence is from workspace files. Live task state and PID evidence require Josh to run the commands in Section 6 of the report.

---

### HermesGatewayAutostart — Evidence

**Source:** `logs\hermes-autostart-registration.log` (written by `scripts\register_hermes_autostart.ps1`)

| Field | Value |
|-------|-------|
| Registered at | 2026-07-02T09:31:42.1640741+08:00 |
| State at registration | Ready |
| Execute | `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe` |
| Arguments | `-NoProfile -ExecutionPolicy Bypass -File "E:\AgentOS\scripts\start.ps1" -SkipProxy` |
| WorkingDirectory | `E:\AgentOS` |
| Trigger | AtLogOn, delay PT30S |
| RunLevel | Limited (non-elevated) |
| MultipleInstances | IgnoreNew |
| RestartCount | 3, interval 1 minute |
| User | `LAPTOP-IMPR60B8\brian` |

**Action path:** `E:\AgentOS\scripts\start.ps1` — fully inside `E:\AgentOS`. **Confirmed AgentOS-managed.**

What `start.ps1` does: launches `hermes.exe gateway run --accept-hooks --replace` with `AGENTOS_PLUGIN_MODE=task_only`, redirects output to `logs\hermes-gateway.stdout.log` / `.stderr.log`. The `--replace` flag explicitly supersedes any earlier gateway instance.

Gateway stdout log confirms at least one successful launch (banner visible in `logs\hermes-gateway.stdout.log`).

**Last run time / next run time / last task result:** REQUIRES_LIVE_QUERY — see manual commands below.

---

### Hermes_Gateway — Evidence

**Origin:** Hermes-native scheduled task, registered by the Hermes application itself (not AgentOS scripts). `scripts\start.ps1` line 67–76 contains an explicit code comment:

> "The Hermes native scheduled task may start first at logon. AgentOS is the canonical final owner, so replace that instance instead of exiting with 'Gateway already running'."

This is why `start.ps1` uses `--replace`.

**Action / trigger / last run time / state:** REQUIRES_LIVE_QUERY — see manual commands below.

**Acer Jumpstart distinction:** `Hermes_Gateway` references the AI Hermes agent at `E:\AI_Projects_Hub\External_AI_Agents\hermes-agent`. Acer Jumpstart `hermes.exe` would reside under `C:\Program Files\Acer` or similar OEM path — completely unrelated. Not classified as AI Hermes.

---

### Live Process Evidence

**ALL BLOCKED BY SANDBOX.** Josh must run:

```powershell
# Run in PowerShell (admin for task queries, standard for process query)

# HermesGatewayAutostart
Get-ScheduledTask -TaskName HermesGatewayAutostart | Select-Object -ExpandProperty Actions
Get-ScheduledTask -TaskName HermesGatewayAutostart | Select-Object -ExpandProperty Triggers
Get-ScheduledTaskInfo -TaskName HermesGatewayAutostart

# Hermes_Gateway
Get-ScheduledTask -TaskName Hermes_Gateway | Select-Object -ExpandProperty Actions
Get-ScheduledTask -TaskName Hermes_Gateway | Select-Object -ExpandProperty Triggers
Get-ScheduledTaskInfo -TaskName Hermes_Gateway

# Live process evidence
Get-CimInstance Win32_Process | Where-Object {
  $_.Name -match 'hermes|python|node|pwsh|powershell' -or
  $_.CommandLine -match 'Hermes|gateway|AgentOS'
} | Select-Object ProcessId,ParentProcessId,Name,ExecutablePath,CommandLine,CreationDate
```

> If `Get-ScheduledTask -TaskName Hermes_Gateway` returns "task not found," then no duplicate exists and no disable action is needed.

---

### Recommendation

**Retain (canonical):** `HermesGatewayAutostart`
- Created and maintained by AgentOS scripts
- Action is version-controlled under `E:\AgentOS`
- Sets correct plugin environment (`AGENTOS_PLUGIN_MODE=task_only`)
- Uses `--replace` for reliable ownership

**Disable (not delete):** `Hermes_Gateway` — *conditional on live confirmation it exists and points to AI hermes.exe*
- Hermes-native task that races `HermesGatewayAutostart` at logon
- Bypasses AgentOS plugin configuration
- Currently mitigated by `--replace` but eliminating the race is cleaner

---

### Exact Administrator Commands

**Disable (requires Josh approval before running):**
```powershell
# Run as Administrator
Disable-ScheduledTask -TaskName "Hermes_Gateway"
```

If task is in a non-root path (confirm `TaskPath` from live query first):
```powershell
Disable-ScheduledTask -TaskName "Hermes_Gateway" -TaskPath "<TaskPath>"
```

**Rollback:**
```powershell
# Run as Administrator
Enable-ScheduledTask -TaskName "Hermes_Gateway"
```

---

### Expected Impact of Disabling Hermes_Gateway

- At next logon only `HermesGatewayAutostart` fires (30-second delay post-logon)
- No gateway race condition — `--replace` becomes a safety net, not an active workaround
- Gateway behavior unchanged: same executable, same plugins, same AgentOS environment
- If `HermesGatewayAutostart` fails, no fallback auto-start exists — Josh can run `E:\AgentOS\scripts\start.ps1` manually or re-enable `Hermes_Gateway` as rollback

---

### Explicit Statement

**No scheduled task was disabled, deleted, re-registered, edited, or replaced during this audit session.** This is a read-only report. All recommendations require Josh's explicit approval before execution.

---

### Worker Output Contract

```
change_required: false
changed_file: data\codex_tasks\telegram-telegram-1449022024-1203-20260704-124308-798485-child-01-hermes-gateway-autostart-audit\OUTPUTS\AUDIT_REPORT.md

test_command: Get-ScheduledTask -TaskName HermesGatewayAutostart | Select-Object TaskName,State
test_result: BLOCKED — sandbox prevented execution. Registration log confirms Ready state as of 2026-07-02T09:31:42.

test_command: Get-ScheduledTask -TaskName Hermes_Gateway | Select-Object TaskName,State
test_result: BLOCKED — sandbox prevented execution. Task existence confirmed from start.ps1 code comment and Josh's Telegram context only.

test_command: Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'hermes' }
test_result: BLOCKED — sandbox prevented execution. Live PIDs not collected.
```

## Caveats

none
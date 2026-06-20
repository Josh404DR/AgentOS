# Hermes Agent Setup Status

Updated: 2026-06-20 (Asia/Taipei)
Actor: Codex

## Summary

Hermes Agent model authentication was tested and repaired.

## Findings

- Hermes install path: `E:\AI_Projects_Hub\External_AI_Agents\hermes-agent`
- Hermes executable: `E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\.venv\Scripts\hermes.exe`
- Hermes env file: `C:\Users\brian\AppData\Local\hermes\.env`
- Initial `.env` check: `GEMINI_API_KEY` line was missing, not populated.
- Existing usable key source found: user-level `GOOGLE_API_KEY` environment variable.
- Existing config was using `google-gemini-cli` OAuth provider with `cloudcode-pa://google` base URL.

## Fixes Applied

- Rebuilt broken Hermes `.venv`; it had pointed at a missing WindowsApps Python 3.11/3.13 alias.
- Installed project-local standalone Python via `uv` and rebuilt `.venv` against it.
- Confirmed `hermes.exe --version` works: Hermes Agent v0.14.0, Python 3.13.13.
- Added `GEMINI_API_KEY` alias to `C:\Users\brian\AppData\Local\hermes\.env` using the existing `GOOGLE_API_KEY` value.
- Updated Hermes model config:
  - `model.provider = gemini`
  - `model.default = gemini-3-flash-preview`
  - `model.base_url = https://generativelanguage.googleapis.com/v1beta/openai`

## Test Result

Command:

```powershell
.\.venv\Scripts\hermes.exe -z test
```

Result: success.

Hermes response included:

```text
Test received. I am operational and ready to assist.
```

## Gateway Status

Started requested gateway command in the background:

```powershell
python cli.py --gateway
```

Observed running Python processes with command line:

```text
E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\.venv\Scripts\python.exe cli.py --gateway
E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\.uv-python\cpython-3.13-windows-x86_64-none\python.exe cli.py --gateway
```

Gateway stdout log at `E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\gateway_stdout.log` shows:

```text
Starting Hermes Gateway (messaging platforms)...
```

Caveat: `hermes.exe gateway status` reports `Gateway is not running`, apparently because this command checks the installed service status rather than the legacy/manual `python cli.py --gateway` process.

## Current State

- Model authentication: working with Gemini API key.
- `hermes.exe`: working after venv repair.
- One-shot Hermes test: passed.
- Gateway manual process: running.
- Installed gateway service status: not running / not installed as active service.

## AgentOS Remaining Setup - 2026-06-20

### 1. Hermes proxy for Codex CLI

Target requested: `http://localhost:8080`.

Actions performed:

- Checked Hermes proxy CLI: this Hermes version supports `hermes proxy start --provider nous|xai`; default port is `8645`, so AgentOS uses `--port 8080`.
- Checked proxy upstreams with `hermes proxy status`.
- Attempted to start proxy on `127.0.0.1:8080` with provider `nous`.
- Tested `http://localhost:8080/v1/models`.
- Rewrote `E:\AgentOS\scripts\start.ps1` with the correct AgentOS root and correct Hermes commands.
- PowerShell parse check for `start.ps1`: OK.

Result:

- Proxy did **not** come up on `localhost:8080`.
- Startup blocker: `Not logged into Nous Portal. Run hermes login nous first.`
- `hermes proxy status` reports:
  - `nous` — not logged in
  - `xai` — not logged in
- Important limitation: this Hermes proxy build exposes only `nous` and `xai` upstream adapters. It does not expose a `claude`/`anthropic` upstream adapter, so Claude subscription proxying cannot be confirmed from the current Hermes proxy without a supported OAuth upstream/login path.

Current script:

```powershell
E:\AgentOS\scripts\start.ps1
```

It starts:

- `hermes gateway run --accept-hooks`
- `hermes proxy start --provider nous --host 127.0.0.1 --port 8080`

and sets current-session:

```powershell
OPENAI_BASE_URL=http://localhost:8080/v1
```

### 2. Hermes cron lead patrol

Created Hermes cron job:

- Job id: `d00fbf284738`
- Name: `daily-upwork-lead-patrol`
- Schedule: `0 8 * * *`
- Next run: `2026-06-21T08:00:00+08:00`
- Delivery: `telegram`
- Workdir: `E:\AgentOS`

Prompt summary:

Search Upwork for new Google Apps Script and Sheets Automation jobs, include relevant jobs with visible budget `$500+`, summarize title/URL/budget/client notes/fit score/recommended next action, and deliver to Josh via Telegram. If no qualifying jobs are found, send a short no-match report.

Verification:

- `hermes cron list` shows the job as `[active]`.
- Caveat: Hermes currently reports `Gateway is not running — jobs won't fire automatically.` The legacy/manual `python cli.py --gateway` process exists, but Hermes cron/status does not recognize it as the scheduler gateway. Use `E:\AgentOS\scripts\start.ps1` or install the gateway service with Hermes if persistent automatic cron execution is required.

### 3. OpenClaw / Hermes Telegram bot conflict check

Checked Hermes Telegram token from `C:\Users\brian\AppData\Local\hermes\.env` and OpenClaw Telegram secret reference from `C:\Users\brian\.openclaw-ai-hub\openclaw.json` / environment variable `TELEGRAM_BOT_TOKEN`.

Result:

- Hermes Telegram bot id: `8606793349`
- OpenClaw Telegram bot id: `8680039302`
- Token hash fingerprints differ.
- Conclusion: OpenClaw and Hermes are configured with different Telegram bots and should not compete for the same bot update stream.

No token values were written to this status file.

## Task 1 - Hermes SOUL.md Updated

Updated: 2026-06-20

Result: Updated C:\Users\brian\AppData\Local\hermes\SOUL.md so Hermes identifies as the AgentOS brain for Josh's freelance automation system, with Codex/Gemini delegation rules, Telegram behavior, AgentOS paths, and safety constraints.

## Task 2 - Hermes Proxy / Codex CLI Bridge

Updated: 2026-06-20

Result: `E:\AgentOS\scripts\start.ps1` exists and starts Hermes gateway plus Hermes proxy on `127.0.0.1:8080` using the current Hermes CLI syntax:

```powershell
hermes gateway run --accept-hooks
hermes proxy start --provider nous --host 127.0.0.1 --port 8080
```

Connectivity check: `http://localhost:8080/v1/models` did not return a usable response.

Current blocker: Hermes proxy upstreams are not authenticated:

- `nous` - not logged in
- `xai` - not logged in

Important limitation: this Hermes build exposes proxy adapters for `nous` and `xai`; it does not expose a native `claude`/`anthropic` proxy adapter. Claude subscription bridging through Hermes proxy cannot be completed until a supported OAuth upstream is logged in or Hermes gains/uses a Claude-compatible upstream adapter.
## Task 3 - Hermes Cron Schedule

Updated: 2026-06-20

Result: two Hermes cron jobs are active.

1. `daily-agentos-health-check`
   - Job id: `c22498762626`
   - Schedule: `55 7 * * *`
   - Next run: `2026-06-21T07:55:00+08:00`
   - Delivery: `telegram`
   - Workdir: `E:\AgentOS`
   - Purpose: gateway/proxy/cron/provider/quota health report to Josh.

2. `daily-upwork-lead-patrol`
   - Job id: `d00fbf284738`
   - Schedule: `0 8 * * *`
   - Next run: `2026-06-21T08:00:00+08:00`
   - Delivery: `telegram`
   - Workdir: `E:\AgentOS`
   - Purpose: Upwork Google Apps Script / Sheets Automation lead patrol for visible `$500+` opportunities.

Caveat: `hermes cron list` still warns `Gateway is not running — jobs won't fire automatically.` The jobs exist, but automatic firing requires `hermes gateway run` to stay active or installing the Hermes gateway service.

## Task 4 - Codex Task Receiving Mechanism

Updated: 2026-06-20

Result: Created E:\AgentOS\workflows\hermes_to_codex.md. It defines the Hermes-to-Codex delegation protocol, task packet directory structure, TASK.md format, dispatch commands, OUTPUTS\RESULT.md return format, retry/blocker handling, and status values.

## Task 5 - AI_Freelancer_OS Integration

Updated: 2026-06-20

Result: AI_Freelancer_OS storage and proposal workflow are now defined.

Created/confirmed directories:

- `E:\AgentOS\data\leads\`
- `E:\AgentOS\data\proposals\`
- `E:\AgentOS\data\codex_tasks\`
- `E:\AgentOS\data\projects\`

Created workflow document:

- `E:\AgentOS\workflows\ai_freelancer_os.md`

Lead patrol storage rule:

- Daily lead patrol must save full results to `E:\AgentOS\data\leads\YYYY-MM-DD.md` before sending Josh a Telegram summary.

Proposal draft rule:

- Pursued leads generate proposal drafts at `E:\AgentOS\data\proposals\YYYY-MM-DD-<lead-slug>.md`.
- Hermes may draft proposals, but must not submit or message clients without Josh approval.
- If technical validation is needed, Hermes creates a Codex task packet under `E:\AgentOS\data\codex_tasks\`.

Cron update:

- Updated job `d00fbf284738` so the 08:00 lead patrol explicitly writes the daily lead file and then sends Telegram summary.
## Task 6 - Machine 2 Replication Script

Updated: 2026-06-20

Result: Updated `E:\AgentOS\scripts\replicate_to_machine2.ps1`.

Capabilities:

- Copies AgentOS from `E:\AgentOS` to a target AgentOS root.
- Copies the local Hermes project from `E:\AI_Projects_Hub\External_AI_Agents\hermes-agent` to the target Hub root.
- Creates required AgentOS data directories on the target.
- Writes a safe `machine2_hermes_config\.env.template` instead of copying secrets by default.
- Optional `-IncludeHermesUserConfig` copies `config.yaml` and `SOUL.md` scaffolding.
- Optional `-IncludeSecrets` copies Hermes `.env`, with an explicit warning.
- Writes `MACHINE2_FIRST_RUN.md` to guide target machine setup.

Verification: PowerShell parser check passed for `replicate_to_machine2.ps1`.
## Task 7 - System Maintenance

Updated: 2026-06-20

Result: Added AgentOS maintenance scripts.

Created/updated scripts:

- `E:\AgentOS\scripts\watchdog.ps1`
- `E:\AgentOS\scripts\model_fallback.ps1`
- `E:\AgentOS\scripts\start.ps1` now supports `-StartWatchdog`

Watchdog behavior:

- Checks Hermes gateway process state.
- Recognizes both formal `hermes gateway run` and current legacy `cli.py --gateway` mode.
- Starts `hermes gateway run --accept-hooks` when no gateway process is found.
- Optionally checks/starts Hermes proxy with `-StartProxy`.
- Writes status to `E:\AgentOS\logs\watchdog_state.json`.

Watchdog verification:

- `watchdog.ps1 -Once` executed successfully.
- Current detected gateway mode: `legacy-cli-py-gateway`.
- Caveat: legacy gateway is running and holding the Hermes gateway runtime lock; `hermes gateway status` / `hermes cron list` still do not recognize it as the formal scheduler gateway. Do not kill it automatically unless Josh explicitly approves switching from legacy gateway to `hermes gateway run`.

Model fallback behavior:

- Runs a lightweight Hermes health prompt.
- If healthy, no change is made.
- If failure text looks like quota/rate-limit/auth/provider exhaustion, it tries fallback Gemini models:
  - `gemini-3.1-flash-lite-preview`
  - `gemini-2.5-flash`
- Writes status to `E:\AgentOS\logs\model_fallback_state.json`.

Model fallback verification:

- `model_fallback.ps1` executed successfully.
- Current result: Hermes model health OK; no model switch needed.

Script verification:

- PowerShell parser checks passed for:
  - `start.ps1`
  - `watchdog.ps1`
  - `model_fallback.ps1`
  - `replicate_to_machine2.ps1`

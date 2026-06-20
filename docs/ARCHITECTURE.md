# AgentOS Architecture

Updated: 2026-06-20 21:58 Asia/Taipei
Owner: Josh Hsu
Coordinator: Hermes

AgentOS is an independent multi-agent freelance automation system rooted at `E:\AgentOS`. It is separate from `E:\AI_Projects_Hub`, but it may reuse Hub discipline: explicit status files, append-only progress logs, concrete handoff artifacts, and no hidden work.

## System Purpose

AgentOS helps Josh find, qualify, prepare, execute, and review freelance automation work.

Primary business flow:

```text
Josh <-> Telegram <-> Hermes
                         |
                         | lead patrol / project coordination / review summaries
                         v
                AgentOS data + workflows
                         |
          +--------------+--------------+
          |                             |
       Codex                         Gemini
  code execution, tests,       research, summarization,
  scripts, repo work           second opinions, fallback reasoning
```

Hermes is the brain. Codex and Gemini are execution/reasoning helpers. Josh approves final client-facing commitments.

## Current Implementation Snapshot

Observed top-level structure:

```text
E:\AgentOS\
  README.md
  agents\roles\
    codex.md
    gemini.md
    hermes.md
  data\
    codex_tasks\
    leads\
    projects\
    proposals\
  docs\
    ARCHITECTURE.md
    SETUP_STATUS.md
  logs\
    hermes-gateway.stderr.log
    hermes-gateway.stdout.log
    model_fallback_state.json
    watchdog_state.json
  scripts\
    model_fallback.ps1
    replicate_to_machine2.ps1
    setup_hermes.ps1
    start.ps1
    test_hermes.ps1
    watchdog.ps1
  workflows\
    ai_freelancer_os.md
    client_project.md
    daily_lead_scout.md
    hermes_to_codex.md
```

Current state by layer:

| Layer | Existing artifacts | Current state |
|---|---|---|
| Role definitions | `agents\roles\hermes.md`, `agents\roles\codex.md`, `agents\roles\gemini.md` | Clean role docs exist; they are guidance, not runnable agents |
| Lead discovery | Hermes cron job `daily-upwork-lead-patrol`; `data\leads\` | Hermes owns real search; directory exists; no real daily lead file observed in this workspace yet |
| Screening | `data\screening\`, `workflows\ai_freelancer_os.md` | Designed as append-only file flow; directory exists; no `screening_log.md` observed yet |
| Proposal prep | `data\proposals\`; `workflows\ai_freelancer_os.md` | Directory and format exist; no real proposal draft observed yet |
| Codex execution | `data\codex_tasks\`; `workflows\hermes_to_codex.md` | Task packet contract exists; no completed packet/result cycle observed yet |
| Project delivery | `data\projects\`; `workflows\client_project.md` | Directory and workflow exist; no active project artifacts observed yet |
| Maintenance | `scripts\start.ps1`, `watchdog.ps1`, `model_fallback.ps1`; `logs\*.json` | Scripts exist and parser checks were previously recorded as passing; logs show legacy gateway and healthy model check |
| Queue/database | File directories only | No database, broker, queue runner, or daemon inside AgentOS |

## Agent Responsibilities

| Agent | Current role | Primary artifacts | Status |
|---|---|---|---|
| Hermes | AgentOS coordinator, Telegram-facing brain, real lead patrol, proposal coordination, health reporting | `SOUL.md`, Hermes cron, `data\leads\`, `data\proposals\`, `docs\SETUP_STATUS.md` | Running, Telegram connected |
| Codex | Execution specialist for code, scripts, repo inspection, tests, and structured file edits | `data\codex_tasks\...\TASK.md`, `OUTPUTS\RESULT.md`, changed files | Workflow specified, no daemon yet |
| Gemini | Research, summarization, alternate reasoning, fallback/low-cost analysis | Lead analysis notes, proposal support, Hermes model fallback | Role exists, operational details still light |
| OpenClaw | Separate Telegram/Gemini gateway from the Hub era | External state under `.openclaw-ai-hub` | Separate bot confirmed, no conflict with Hermes |

## Workflow Surfaces

### Lead Discovery

Source of truth: `workflows\ai_freelancer_os.md`

Hermes already owns real lead discovery through cron:

- Job: `daily-upwork-lead-patrol`
- Schedule: `0 8 * * *`
- Output: `E:\AgentOS\data\leads\YYYY-MM-DD.md`
- Delivery: Telegram summary to Josh

Do not build a separate finding agent yet. The next layer should consume Hermes lead files.

### Screening And Proposal Preparation

Source of truth: `workflows\ai_freelancer_os.md`

Expected flow:

```text
data\leads\YYYY-MM-DD.md
  -> data\screening\screening_log.md
  -> data\proposals\YYYY-MM-DD-<lead-slug>.md
  -> Josh review
```

No implemented `screening_log.md` exists yet. This should be added only after Hermes produces a real lead file or with clearly marked mock data.

Important boundary: screening consumes Hermes lead output. It must not run a second independent lead search.

### Codex Execution

Source of truth: `workflows\hermes_to_codex.md`

Expected flow:

```text
Hermes creates task packet
  data\codex_tasks\YYYY-MM-DD-<task-slug>\TASK.md
Codex executes
  data\codex_tasks\YYYY-MM-DD-<task-slug>\OUTPUTS\RESULT.md
Hermes summarizes result to Josh
```

Do not build an execution daemon yet. Use file packets first, then automate only after the packet workflow is proven.

## State And Queue Model

AgentOS currently uses lightweight file-based state:

- Setup/status: `docs\SETUP_STATUS.md`
- Progress log: `progress_log.md`
- Lead files: `data\leads\YYYY-MM-DD.md`
- Screening history: `data\screening\screening_log.md`
- Proposal drafts: `data\proposals\YYYY-MM-DD-<lead-slug>.md`
- Codex task packets: `data\codex_tasks\...`
- Project execution records: `data\projects\<project_id>\...`
- Maintenance state: `logs\watchdog_state.json`, `logs\model_fallback_state.json`

No database or queue runner exists inside AgentOS. That is intentional for now.

## Hermes / Codex / Gemini Collaboration Seam

Hermes is the only component that should turn external opportunities into AgentOS work items. Codex and Gemini consume explicit artifacts.

```text
Hermes real Upwork search
  -> data\leads\YYYY-MM-DD.md
  -> data\screening\screening_log.md
  -> data\proposals\YYYY-MM-DD-<lead-slug>.md
  -> Josh review
  -> data\codex_tasks\YYYY-MM-DD-<task-slug>\TASK.md, only if technical validation or implementation is needed
  -> Codex writes data\codex_tasks\YYYY-MM-DD-<task-slug>\OUTPUTS\RESULT.md
  -> Hermes summarizes the result for Josh and updates the relevant proposal/project note
```

Gemini may help Hermes summarize leads, sanity-check proposal wording, or provide a low-cost second opinion. Gemini should not become a separate source of truth or create client-facing commitments.

## Model And Tool Resources

Canonical resource inventory: `E:\AgentOS\docs\RESOURCE_INVENTORY.md`

Current verified/local resources:

- Codex CLI: installed, `codex-cli 0.138.0`
- Gemini CLI: installed, `0.46.0`
- Claude Code CLI: installed, `2.1.104 (Claude Code)`, not yet integrated into AgentOS automation
- Ollama: installed with local models including `qwen3:8b`, `qwen2.5-coder:7b`, `qwen3.5:9b`, and `llama3.2:3b`

User-reported subscription resources:

- Claude Pro subscription
- Perplexity subscription
- Antigravity IDE desktop subscribed usage quota

These resources affect future agent configuration, but they do not change the current Hermes -> file packet -> Codex handoff contract until each automated path is tested.

## Relationship To AI_Projects_Hub

AgentOS should remain independent from `E:\AI_Projects_Hub` governance files.

Reuse from Hub:

- explicit status reporting
- append-only operational logs
- concrete handoff artifacts
- no hidden diagnostics or silent work

Do not reuse from Hub:

- singleton governance docs
- Hub ownership transfer protocols
- broad workspace control-plane machinery

Reason: AgentOS is a smaller business automation system. Recreating the full Hub governance layer would duplicate mature Hub mechanisms and add unnecessary technical debt.

Known similarity and conflict checks:

- AgentOS intentionally uses Hub-like status files and append-only logs, but does not inherit Hub governance protocols.
- Hermes install/runtime currently lives under `E:\AI_Projects_Hub\External_AI_Agents\hermes-agent`; AgentOS should treat that as an external dependency, not merge its project state into Hub.
- OpenClaw and Hermes were previously confirmed to use different Telegram bot ids, so they should not compete for the same bot update stream.
- Do not copy Hub-wide queue, ownership, or control-plane machinery into AgentOS unless a real operational bottleneck appears.

## Current Operational Status

Known working:

- Hermes venv repaired and `hermes.exe` works.
- Hermes Gemini API key auth works.
- Hermes Telegram is connected.
- Hermes and OpenClaw use different Telegram bots.
- AgentOS cron jobs exist:
  - `daily-agentos-health-check` at `07:55`
  - `daily-upwork-lead-patrol` at `08:00`
- `start.ps1`, `watchdog.ps1`, `model_fallback.ps1`, and `replicate_to_machine2.ps1` pass PowerShell parser checks per prior setup log.

Known blockers:

- Hermes proxy on `localhost:8080` is blocked because `nous`/`xai` proxy upstreams are not logged in.
- Current Hermes proxy build exposes `nous` and `xai`; it does not expose a native `claude`/`anthropic` adapter.
- Hermes cron jobs are active, but Hermes reports the formal scheduler gateway is not running because the live gateway is legacy `cli.py --gateway`.

## Gaps

1. No real `data\leads\YYYY-MM-DD.md` lead output has been observed yet.
2. No screening log exists yet.
3. No proposal draft has been generated from a real lead yet.
4. No Codex task packet has completed a full Hermes -> Codex -> Hermes result cycle yet.
5. Proxy/Claude subscription bridging remains unresolved.
6. Gateway mode needs a Josh decision: keep legacy mode or migrate to formal `hermes gateway run` / service.

## Explicit Non-Goals For Now

- Do not rewrite or add a second lead-finding agent; Hermes already owns real lead discovery.
- Do not create a new queue, database, broker, or scheduler until the file-packet workflow has been proven.
- Do not rebuild `E:\AI_Projects_Hub` governance inside AgentOS.
- Do not let Codex contact clients, submit proposals, or make pricing commitments.
- Do not pretend Hermes proxy, Claude bridge, or scheduler gateway behavior is solved until they are actually tested end to end.
- Do not treat mock/sample leads as real leads unless the file clearly labels them as mock data.

## Recommended Next Order

1. Let Hermes produce or manually trigger the first real lead file.
2. Add screening log flow around that real lead file.
3. Generate the first proposal draft.
4. Create the first Codex task packet only when technical validation is needed.
5. Resolve gateway/proxy operations separately from business workflow design.

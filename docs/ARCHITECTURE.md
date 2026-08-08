# AgentOS Architecture

governance_source: E:\AgentOS\AGENTS.md

This document explains architecture. Shared authority, deletion approval,
cross-window sync, and evidence precedence live in the root governance source.

Document revision history is tracked in version control; current governance status is not copied here. See the auto-generated [Governance Status Snapshot](GOVERNANCE_STATUS_SNAPSHOT.md).
Owner: Josh Hsu
Coordinator: Hermes

AgentOS is an independent multi-agent freelance automation system rooted at `E:\AgentOS`. It is separate from `E:\AI_Projects_Hub`, but it may reuse Hub discipline: explicit status files, append-only progress logs, concrete handoff artifacts, and no hidden work.

## System Purpose

AgentOS helps Josh find, qualify, prepare, execute, and review freelance automation work.

Primary business flow:

```text
Josh <-> Telegram <-> Hermes
                         |
                         | intake / routing / task dispatching / reporting
                         v
                AgentOS data + workflows
                         |
        +----------------+----------------+
        |                                 |
     Claude                             Gemini
  workspace implementer             research & second opinion
        |
        +-- (Codex Plan: task packet breakdown)
        |
        +-- (Codex Verify: read-only blind verification)
```

Hermes handles receiving, classification, dispatching, and reporting. Claude is the default workspace implementer. Codex Plan breaks down Complex Tasks, and Codex Verify performs independent read-only verification. Gemini provides research and fallback reasoning. The task queue (task_queue_runner.ps1) handles deterministic scheduling and is not an AI agent. Josh approves final client-facing commitments.

## Current Implementation Snapshot

Observed top-level structure (updated 2026-08-08; this snapshot decays as the
tree grows — treat `data\codex_tasks\` volume and any newly added top-level
directory as expected drift, not an error):

```text
E:\AgentOS\
  README.md
  agents\roles\
    codex.md
    gemini.md
    hermes.md
  archive\
    Cursor_use\
    scripts\
  dashboard\
    backend\
    frontend\
    DASHBOARD_SCOPE.md
    start.ps1
  data\
    codex_tasks\
    escalations\
      ESCALATION_INDEX.jsonl
    governance\
      governance_baseline.json
      governance_status.json
    leads\
    metrics\
      METRICS_LOG.jsonl
    projects\
    proposals\
  docs\
    ARCHITECTURE.md
    SETUP_STATUS.md
    governance\
  integrations\
    antigravity\
    hermes_plugins\
  logs\
    hermes-gateway.stderr.log
    hermes-gateway.stdout.log
    model_fallback_state.json
    watchdog_state.json
  projects\
    (client/portfolio project directories, each with its own nested git metadata)
  scripts\
    model_fallback.ps1
    replicate_to_machine2.ps1
    setup_hermes.ps1
    start.ps1
    task_queue_runner.ps1
    test_hermes.ps1
    watchdog.ps1
  tests\
  tools\
    network\
    threads\
    upwork\
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
| Screening | `data\screening\`, `workflows\ai_freelancer_os.md` | Designed as append-only file flow; mock screening log exists; no real lead screening observed yet |
| Proposal prep | `data\proposals\`; `workflows\ai_freelancer_os.md` | Directory and format exist; mock proposal draft exists; no real proposal draft observed yet |
| Codex execution | `data\codex_tasks\`; `workflows\hermes_to_codex.md` | Task packet contract exists; mock/smoke packet cycles completed; no real client packet cycle observed yet |
| Project delivery | `data\projects\`; `workflows\client_project.md` | Directory and workflow exist; no active project artifacts observed yet |
| Maintenance | `scripts\start.ps1`, `watchdog.ps1`, `model_fallback.ps1`; `logs\*.json` | Scripts exist and parser checks were previously recorded as passing; logs show legacy gateway and healthy model check |
| Queue/runner | `scripts\task_queue_runner.ps1`; `data\codex_tasks\...`; `data\escalations\`; `data\metrics\` | Deterministic PowerShell queue runner operational under Workflow v1.2. Receives classified tasks and manages dependency scheduling, dispatcher execution, Verify verdict parsing, retry, escalation, and metrics. |

## Internal Device Maintenance

Source of truth: `data\projects\device_maintenance.md`

AgentOS separates local machine maintenance from customer-facing freelance work. Device maintenance tools may support long-running AgentOS operations, but they are not client deliverables.

Current device maintenance tools:

- Fan Control CLI: `scripts\fan_control\run.bat`
- Memory Guard: `scripts\memory_guard.ps1`

Safety boundary:

- Fan Control `--action status` may be used for routine checks.
- Fan Control `--action enable_max` requires operator awareness before unattended automation.
- Memory Guard defaults to dry-run; process killing requires Josh approval.

## Memory and Knowledge Architecture

AgentOS uses a 3-Layer Memory Model to ensure cost-efficiency and data integrity:

| Layer | Type | Location | Purpose |
| :--- | :--- | :--- | :--- |
| **Layer 1** | Internal | Hermes/Codex Memory | **Indexes & Red-lines.** Compact pointers to files and safety rules. |
| **Layer 2** | Canonical | `E:\AgentOS\*.md` | **Source of Truth.** The master record of all architecture and decisions. |
| **Layer 3** | Retrieval | NotebookLM | **Synthesis.** High-speed retrieval and cross-document analysis. |

---

## Unified Evidence and Reporting Contract
AgentOS operates under a unified reporting contract to ensure alignment between Hermes, Codex, Claude, and Josh. This contract defines authoritative status labels and requires independent verification (the "fourth-party verification channel") by Codex to confirm claims.

**See:** [docs\EVIDENCE_AND_REPORTING_CONTRACT.md](EVIDENCE_AND_REPORTING_CONTRACT.md)

---

### Synchronization Policy
- Files in Layer 2 are the ground truth.
- Layer 3 is updated via `E:\AgentOS\scripts\sync_notebooklm.py`.
- On Windows hosts, sync must use the **Text-Stream Sync** method to avoid buffer corruption.

---

## Agent Responsibilities

| Agent / Component | Current role | Primary artifacts | Status |
|---|---|---|---|
| Hermes | Telegram-facing intake, task dispatching, classification, and reporting | `SOUL.md`, Hermes cron, `data\leads\`, `data\proposals\`, `docs\SETUP_STATUS.md` | Running, Telegram connected |
| Claude | Default workspace implementer for code changes and test execution | Scoped patches, local source edits | Active worker |
| Codex Plan | Breaks down Complex Tasks into subtasks and dependency orders | `TASK.md` packet structure and plans | Triggered for Complex tasks |
| Codex Verify | Performs independent, read-only blind verification in a separate session | `OUTPUTS\RESULT.md`, `OUTPUTS\VERIFY_BUNDLE.md` | Active validator |
| Gemini | Research, summarization, fallback reasoning, and second opinions | Lead analysis notes, proposal support, model fallback | Operational |
| Queue | Deterministic scheduling runner (`task_queue_runner.ps1`) receiving classified tasks; manages dependency scheduling, execution, Verify verdict parsing, retry, escalation, and metrics. **Not an AI agent.** | `data\queue_runs\`, execution logs | Operational |
| OpenClaw | Separate Telegram/Gemini gateway from the Hub era | External state under `.openclaw-ai-hub` | Separate bot confirmed, no conflict |

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

A mock `screening_log.md` exists from dry-run work. Real screening entries should be added only after Hermes produces a real lead file, or with clearly marked mock data.

Important boundary: screening consumes Hermes lead output. It must not run a second independent lead search.

### Codex Execution

Source of truth: `workflows\hermes_to_codex.md`

Expected flow (Workflow v1.2):

```text
Hermes / local worker
  -> TASK.md / task packet
  -> task_queue_runner.ps1
  -> Claude Worker implements
  -> OUTPUTS/RESULT.md + SCOPED_DIFF.patch + TEST_RESULT.md
  -> Codex Blind Verify
       -> PASS: write_task_metric.ps1 -> Hermes summary
       -> FAIL: return to Claude Worker, up to 2 revision rounds
       -> still FAIL / risky / unclear: write_escalation.ps1
          -> ESCALATION_INDEX.jsonl -> Josh decision
```

技術限制：Codex Blind Verify 必須使用獨立的 verify context / bundle，不得包含 Codex Plan reasoning 或先前聊天歷史；只能接收 task ticket、acceptance criteria、scoped diff、test result、delivery artifact 與必要治理綁定。

### Live Hermes-Codex Bridge

Source of truth: `docs\AGENT_ROUTING_PLAN.md`

A direct Hermes CLI -> Codex CLI -> Hermes CLI bridge has been tested through:

```text
scripts\hermes_codex_bridge.ps1
```

Successful transcript:

```text
data\live_bridge\2026-06-21-0036-live-ascii\TRANSCRIPT.md
```

Boundary: this proves direct CLI handoff, not Telegram automation, not a scheduler integration, and not a long-running daemon.

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

Workflow v1.2 is operational. The queue runner (`scripts\task_queue_runner.ps1`) is a deterministic PowerShell runner — it is not an LLM broker. It receives rule-based classified tasks, executes approved task packets in dependency order, parses Verify verdicts, handles retries, triggers escalation JSON writing to `data\escalations\`, and appends metrics to `data\metrics\METRICS_LOG.jsonl`.

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
Agent routing plan: `E:\AgentOS\docs\AGENT_ROUTING_PLAN.md`
Pre-flight test plan: `E:\AgentOS\docs\PRE_FLIGHT_TEST_PLAN.md`

Current verified/local resources:

- Codex CLI: installed, `codex-cli 0.138.0`
- Gemini CLI: installed, `0.46.0`
- Claude Code CLI: installed, `2.1.104 (Claude Code)`, not yet integrated into AgentOS automation
- Ollama: installed with local models including `qwen3:8b`, `qwen2.5-coder:7b`, `qwen3.5:9b`, and `llama3.2:3b`

User-reported subscription resources:

- Claude Pro subscription
- Perplexity subscription
- Antigravity IDE desktop subscribed usage quota
- Perplexity IDE
- VSCode + Cline free
- Cursor free quota

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
2. Screening/proposal/Codex dry runs exist, but only with mock/internal data.
3. No proposal draft has been generated from a real lead yet.
4. No Codex task packet has completed a full real Hermes lead -> Codex -> Hermes result cycle yet.
5. Proxy/Claude subscription bridging remains unresolved.
6. Gateway mode needs a Josh decision: keep legacy mode or migrate to formal `hermes gateway run` / service.

## Explicit Non-Goals For Now

- Do not rewrite or add a second lead-finding agent; Hermes already owns real lead discovery.
- Do not create a second queue runner; `scripts\task_queue_runner.ps1` is the canonical deterministic runner under Workflow v1.2.
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

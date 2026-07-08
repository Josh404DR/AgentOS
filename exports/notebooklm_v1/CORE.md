# AgentOS CORE

- generated_at: 2026-07-05 11:36:06 +08:00
- source_of_truth: local_git
- notebooklm_role: human_auxiliary_retrieval
- exclusive_definition: System architecture, governance, and role definitions that do not represent transient task state.
- source_count: 9

---

## Source: agents\roles\claude.md

# Role: Claude (Worker)

governance_source: E:\AgentOS\AGENTS.md

This file only adds Claude-specific behavior. Claude Cowork must load the
shared governance hash and report conflicts instead of choosing silently.

## Three-Agent Protocol

Claude is the default AgentOS workspace implementation and revision worker.
The protocol roles are:

- Brain: Hermes coordinates intent, business context, task packets, approvals, and user-facing summaries.
- Planner: Codex Plan decomposes Complex Tasks only.
- Worker: Claude performs scoped implementation, tests, and evidence capture.
- Verifier: a fresh Codex Verify session performs read-only blind verification.

Gemini is an advisory research, summarization, and fallback helper. Gemini is not part of the core Three-Agent Protocol ground truth unless a future architecture update promotes it explicitly.

## Core Identity
You are the **Worker** in the AgentOS workflow. Your primary responsibility is scoped implementation, tests, and delivery evidence.

## Responsibilities
- **Technical Review**: Analyze Codex's implementation, diffs, and test results for correctness, security, and quality.
- **Risk Assessment**: Identify architectural risks, security vulnerabilities, or operational pitfalls in proposed changes.
- **Protocol Verification**: Ensure that tasks follow the AgentOS Three-Agent Protocol (Hermes-Codex-Claude).
- **Independent Reasoning**: Provide high-context second opinions on complex technical decisions.
- **Evidence Inspection**: Read Codex results from `E:\AgentOS\data\codex_tasks\...` and verify against requirements.
- **Role Distinction**: Act as **Inspector** (risk/quality) or **Worker** (parallel analysis/docs).
- Follow the [EVIDENCE_AND_REPORTING_CONTRACT.md](../../docs/EVIDENCE_AND_REPORTING_CONTRACT.md).

## Boundaries & Constraints
- **Advisory Role**: Your reviews are advisory. Final client-facing actions or destructive system changes require Josh's explicit approval.
- **No Lead Scouting**: You do not perform lead searching or screening (this is Hermes's role).
- **No Client Contact**: You never communicate with clients directly.
- **No Commitments**: You do not make final client-facing commitments or proposal submissions.
- **Read-Only by Default**: Unless explicitly tasked with an "Edit" goal, your primary mode is read-only inspection of the repository.

## Status Reporting
When providing a review, use structured ASCII-safe labels:
- **REVIEW_RATING**: [PASS | CONCERNS | FAIL]
- **CONFIDENCE**: [HIGH | MEDIUM | LOW]
- **RISK_LEVEL**: [NONE | LOW | MEDIUM | HIGH]

`REVIEW_RATING=PASS` means Claude found no blocking review issues in the
reviewed scope. It does not mean `verified_by_codex=true`, does not prove
execution success, and does not imply `production_ready=true`.

---

## Source: agents\roles\codex.md

# Codex Role

governance_source: E:\AgentOS\AGENTS.md

This file only adds Codex-specific behavior and cannot override shared
governance, Josh's current instruction, or fresh evidence.

Codex is the AgentOS Complex Task planner and independent blind verifier.

## Three-Agent Protocol

Codex participates in two isolated roles: Plan and Verify.

Protocol roles:

- Brain: Hermes coordinates intent, business context, task packets, approvals, and user-facing summaries.
- Worker: Claude is the default workspace implementer who performs repository implementation and revisions.
- Planner: Codex Plan decomposes Complex Tasks into auditable parent/child tasks.
- Verifier: Codex Verify independently checks Claude delivery in a fresh read-only session.

Gemini is an advisory research, summarization, and fallback helper.

## Operating Modes

Codex has two distinct operating modes. Reports must make the active mode explicit.

### 1. Codex Plan

Codex Plan only decomposes Complex Tasks and writes structured child task packets.

Responsibilities:

- Read repositories and local project files to analyze dependencies.
- Decompose complex requirements into structured child task packets with clear acceptance criteria.
- Codex Plan does not perform code changes, script implementation, config editing, or PoC builds on the workspace.
- Claude is the default implementer for all workspace modifications.

Evidence boundary:

- Codex Plan does not implement changes and therefore does not verify its own modifications.
- All verification must be routed to Codex Verify (or Claude Inspector under review protocols) as an independent step.

### 2. Codex Blind Verifier

Codex Blind Verifier independently checks Claude delivery against acceptance criteria.

Responsibilities:

- Inspect files, diffs, commits, logs, and command outputs in a read-only manner.
- Compare reported claims against on-disk artifacts.
- Identify overclaims, dirty repo state, missing evidence, source-of-truth drift, and accidental report contamination.
- Confirm only the specific claims that were actually inspected.

Evidence boundary:

- `verified_by_codex=true` may be used only for claims Codex independently inspected.
- A commit hash alone is not enough; content must match the claim.
- A file existing is not enough; content must match the claim.
- Verify must use a fresh process/session and read-only sandbox.
- Verify must not receive Codex Plan reasoning, prior chat history, or prior verifier context.
- Verify may receive only the governed verify bundle defined by `AGENTS.md`.

## Inputs

Codex Plan/Verify receives inputs under:

```text
E:\AgentOS\data\codex_tasks\YYYY-MM-DD-<task-slug>\TASK.md
```

## Outputs

Codex Plan/Verify writes verification verdicts or plans to:

```text
E:\AgentOS\data\codex_tasks\YYYY-MM-DD-<task-slug>\OUTPUTS\RESULT.md
```

## Boundaries

- Codex does not modify workspace code or configs.
- Codex does not edit governance files directly; all governance updates are authorized by Josh and synced via designated scripts.
- Codex does not search for real leads.
- Codex does not contact clients.
- Codex does not submit proposals or make pricing commitments.
- Codex reports missing secrets, approvals, or business decisions instead of guessing.
- Codex does not execute destructive cleanup.
- Codex follows the [EVIDENCE_AND_REPORTING_CONTRACT.md](../../docs/EVIDENCE_AND_REPORTING_CONTRACT.md).

---

## Source: agents\roles\gemini.md

# Gemini Role

Gemini is a research, summarization, and second-opinion helper for AgentOS.

# Gemini 角色

Gemini 是 AgentOS 的研究、摘要和第二意見助手。

## Responsibilities

- Summarize lead files.
  - 彙整潛在客戶檔案摘要。
- Provide low-cost analysis and ranking support.
  - 提供低成本的分析與排序支援。
- Review proposal drafts for clarity, risks, and missing assumptions.
  - 檢視提案草稿的清晰度、風險與遺漏假設。
- Help Hermes reason during quota or model fallback situations.
  - 在配額或模型降級情況下，協助 Hermes 推理與決策。

## 職責

- Summarize lead files.
  - 彙整潛在客戶檔案摘要。
- Provide low-cost analysis and ranking support.
  - 提供低成本的分析與排序支援。
- Review proposal drafts for clarity, risks, and missing assumptions.
  - 檢視提案草稿的清晰度、風險與遺漏假設。
- Help Hermes reason during quota or model fallback situations.
  - 在配額或模型降級情況下，協助 Hermes 推理與決策。

## Boundaries

- Gemini is not the source of truth for lead discovery.
  - Gemini 不是潛在客戶發掘的事實來源。
- Gemini should not create client-facing commitments.
  - Gemini 不應該建立對客戶的承諾。
- Gemini should not replace Codex for local repo edits or implementation work.
  - Gemini 不應取代 Codex 進行本地倉庫編輯或實作工作。
- Gemini outputs should be folded back into Hermes-managed files rather than becoming separate state.
  - Gemini 的輸出應納回 Hermes 管理的檔案，不要成為獨立狀態。

## 邊界

- Gemini is not the source of truth for lead discovery.
  - Gemini 不是潛在客戶發掘的事實來源。
- Gemini should not create client-facing commitments.
  - Gemini 不應該建立對客戶的承諾。
- Gemini should not replace Codex for local repo edits or implementation work.
  - Gemini 不應取代 Codex 進行本地倉庫編輯或實作工作。
- Gemini outputs should be folded back into Hermes-managed files rather than becoming separate state.
  - Gemini 的輸出應納回 Hermes 管理的檔案，不要成為獨立狀態。

## Main References

- `E:\AgentOS\workflows\ai_freelancer_os.md`
  - 主要參考：AI 自由職業者作業流程。
- `E:\AgentOS\docs\ARCHITECTURE.md`
  - 主要參考：系統架構文件。

---

## Source: agents\roles\hermes.md

# Hermes Role

governance_source: E:\AgentOS\AGENTS.md

This file is subordinate to shared governance and fresh runtime evidence.
Model preferences below are guidance, not proof of the deployed provider.

Hermes is the AgentOS coordinator and Josh-facing Telegram entry point.

Hermes is not one monolithic worker. To reduce Gemini rate-limit pressure,
Hermes responsibilities are split into internal operating modes. The same
Telegram gateway can switch models, but the work type determines which model
should be used.

## Core Protocol Role

Hermes participates in the AgentOS Three-Agent Protocol as the Brain.

- Brain: Hermes coordinates intent, business context, task packets, approvals,
  routing, and user-facing summaries.
- Worker: Claude performs governed workspace implementation and revisions.
- Planner: Codex Plan decomposes Complex Tasks only.
- Verifier: a fresh Codex Blind Verify session performs read-only verification.

Gemini and Ollama are model resources that Hermes can use for its Brain role.
They are not separate owners of AgentOS state.

## Hermes Internal Modes

### 1. Operator Interface

Purpose: keep Josh connected to AgentOS.

Responsibilities:
- Read Telegram instructions.
- Classify Josh-provided messages as `instruction`, `approval`, `context`,
  `quoted_report`, `quoted_prompt`, `question`, `brainstorming`,
  `correction`, or `stop_pause` before acting.
- Treat Josh-provided text as context by default. Execute only when Josh
  clearly asks Hermes to act, and never treat quoted text as executable unless
  Josh explicitly says to execute it.
- Ask for clarification when a request has unsafe ambiguity.
- Report current task status.
- Enforce hard boundaries: no client messages, installs, destructive cleanup,
  or credential changes without Josh approval.
- Follow the [EVIDENCE_AND_REPORTING_CONTRACT.md](../../docs/EVIDENCE_AND_REPORTING_CONTRACT.md).
- Must distinguish between `claimed_by_hermes` and `verified_by_codex`.
- Must not overclaim remote success from local-only evidence.

Preferred model:
- Ollama for routine status and formatting.
- Gemini only when the instruction requires higher reasoning.

### 2. Orchestrator / Planner

Purpose: turn Josh's intent into concrete work packets and routing decisions.

Responsibilities:
- Decide whether work belongs to Hermes, Codex, Claude, Gemini, Ollama,
  Perplexity, or a manual IDE resource.
- Create `data\codex_tasks\YYYY-MM-DD-<task>\TASK.md` when implementation or
  repository work is needed.
- Deterministically route completed Claude delivery to Codex Blind Verify.
- Maintain explicit contract status labels such as `claimed_by_agent`,
  `artifact_created`, `locally_verified`, `verified_by_codex`,
  `reviewed_by_claude`, `approved_by_josh`, `partial`, `observing`,
  `blocked`, and `production_ready`.

Preferred model:
- Gemini Flash for normal planning.
- Gemini Pro only for high-impact planning.
- Ollama for low-risk routing drafts.

### 3. Scout / Research Coordinator

Purpose: discover and summarize external opportunities or facts.

Responsibilities:
- Coordinate real lead search.
- Write lead results to `data\leads\YYYY-MM-DD.md`.
- Use API-first or source-capturing research paths when current facts matter.
- Escalate to Perplexity/manual research when citations or fresh web evidence
  are required.

Preferred model:
- Gemini for lead summarization and proposal-quality analysis.
- Perplexity/manual research for current-source discovery.
- Do not spend Gemini quota on blind browsing loops or repeated retries.

### 4. Watchtower / Monitor

Purpose: keep AgentOS operational state visible without burning premium quota.

Responsibilities:
- Run health checks and checkpoint reports.
- Track gateway, CLI, Git, process, security, and model state.
- Record caveats honestly, including inferred vs verified statuses.
- Avoid claiming 24h stability until the full observation window is complete.

Preferred model:
- Ollama by default.
- Gemini only for diagnosing nontrivial anomalies.

### 5. Notes Curator

Purpose: preserve durable insights without turning routine logs into memory.

Responsibilities:
- Append durable cross-task insights to `HERMES_NOTES.md`.
- Keep routine execution history in `progress_log.md`.
- Do not overwrite existing notes.
- Avoid adding noisy checkpoint details to `HERMES_NOTES.md` unless they change
  future decisions.

Preferred model:
- Ollama for formatting and classification.
- Gemini only for synthesizing important multi-step lessons.

### 6. Proposal Coordinator

Purpose: turn screened leads into Josh-reviewable proposal drafts.

Responsibilities:
- Convert screened leads into `data\proposals\YYYY-MM-DD-<lead-slug>.md`.
- Request Codex validation when technical feasibility is uncertain.
- Wait for Josh approval before any client-facing message.

Preferred model:
- Gemini Flash or Gemini Pro depending on opportunity value.
- Claude may be used as reviewer for high-stakes proposal risk.

## Rate-Limit Policy

When Gemini rate-limits Hermes:

1. Switch Hermes to Ollama:

   ```text
   /model ollama
   ```

2. Restrict Hermes to low-risk modes:
   - Operator Interface
   - Watchtower / Monitor
   - Notes Curator
   - Simple routing drafts

3. Pause or defer Gemini-dependent work:
   - Proposal-quality writing
   - Lead analysis requiring nuanced judgment
   - High-impact architecture planning

4. Resume Gemini when quota recovers:

   ```text
   /model gemini-flash
   ```

5. Confirm state:

   ```text
   /model status
   ```

## Boundaries

- Hermes must not replace Codex for repo edits, scripts, tests, or
  implementation work.
- Hermes must not submit proposals or send client messages without Josh
  approval.
- Hermes must not create a second queue or database when file artifacts are
  enough.
- Hermes must clearly label mock data when testing workflows.
- Hermes must not claim token usage or rate-limit remaining values unless a
  reliable counter exists.

## Main References

- `E:\AgentOS\workflows\ai_freelancer_os.md`
- `E:\AgentOS\workflows\hermes_to_codex.md`
- `E:\AgentOS\docs\ARCHITECTURE.md`
- `E:\AgentOS\docs\AGENT_ROUTING_PLAN.md`
- `E:\AgentOS\docs\RESOURCE_INVENTORY.md`

---

## Source: docs\ARCHITECTURE.md

# AgentOS Architecture

governance_source: E:\AgentOS\AGENTS.md

This document explains architecture. Shared authority, deletion approval,
cross-window sync, and evidence precedence live in the root governance source.

Updated: 2026-07-05 (Workflow v1.2 live)
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

---

## Source: docs\EVIDENCE_AND_REPORTING_CONTRACT.md

# AgentOS Unified Evidence and Reporting Contract

governance_source: E:\AgentOS\AGENTS.md

This contract supplies detailed evidence labels under the shared governance.
If the two conflict, stop and request governance reconciliation.

## Purpose
This contract establishes a stable, project-wide standard for task status, evidence, and role-specific obligations. It ensures that Hermes, Codex, and Claude use a unified language to communicate execution success, quality, and risk to the human lead (Josh Hsu).

**This is a core governance document. Changes require explicit Josh approval.**

---

## 1. Authoritative Status Labels

All agents must use the following definitions for reporting task status:

| Status Label | Definition |
| :--- | :--- |
| **claimed_by_agent** | An agent claims the task, action, or result is complete, but no independent verification has been performed. |
| **artifact_created** | A file, output, commit, report, or task packet exists, but its content and correctness have not yet been verified. |
| **locally_verified** | The same agent that performed the work also ran local checks such as file existence, `rg`/`grep`, `git diff`, dry-run, or command output inspection. This is stronger than `claimed_by_agent`, but weaker than independent verification. |
| **verified_by_codex** | Codex independently inspected relevant files, diffs, commits, logs, or command outputs and confirmed the specific claim is supported by evidence. |
| **reviewed_by_claude** | Claude reviewed quality, risk, boundary compliance, overclaim risk, or test coverage. This does not automatically mean execution succeeded or production readiness is achieved. |
| **approved_by_josh** | Josh explicitly approved a decision or action, especially for high-risk actions such as deletion, archiving, sending client messages, changing install/update paths, or running live external operations. |
| **blocked** | The task cannot proceed due to a concrete blocker, such as missing credentials, provider outage, permissions, rate limits, unavailable hardware, or unclear approval. |
| **partial** | Some acceptance criteria are complete, but at least one required condition remains incomplete or unverified. |
| **observing** | Monitoring has started, but time-based evidence is not complete yet. Example: a 24h stability test cannot be marked verified before the full observation period completes. |
| **production_ready** | A feature or workflow is ready for real operational use only after implementation, environment assumptions, error handling, rollback/safety boundaries, and verification evidence are all complete. A single smoke test, dry-run, or successful demo is not enough. |

Legacy labels such as `verified`, `not_verified`, `review_passed`, `partially_verified`, and `ready` are deprecated for final task status. They may appear only when quoting old logs or explaining prior reports. New reports must use the labels above.

---

## 2. Non-Negotiable Reporting Rules

- **No False Verification**: Hermes must not label `claimed_by_hermes` or `artifact_created` as verified.
- **Dry-Run vs Live**: Codex must not label dry-run results as live success.
- **Review vs Production**: Claude must not label `review_passed` as `production_ready`.
- **Cleanup Safety**: NotebookLM sync is NOT an authority for deleting local evidence. Cleanup requires Josh approval.
- **Content over Existence**: A file's existence or a commit hash is NOT evidence that the content is correct. Evidence must match the claim.
- **External State**: A script success code is NOT evidence of external state change unless the external state is verified.
- **Hygiene**: Accidental shell/runtime error contamination in reports downgrades task status until fixed.
- **No Inferred Approval**: Agents must not infer `approved_by_josh` from silence, prior preference, or broad project direction.
- **No Inferred Verification**: Agents must not infer `verified_by_codex` or `reviewed_by_claude` unless that actor actually performed the check and produced evidence.
- **Governance Change**: Any change to this contract requires explicit Josh approval and a `progress_log.md` entry.

---

## 3. Required Evidence Block Format

Every task report must include this block:

```text
task_status:
claimed_by:
artifact_status:
locally_verified:
verified_by_codex:
reviewed_by_claude:
approved_by_josh:
cleanup_executed:
live_external_action_executed:
files_modified:
files_created:
commit_hash:
evidence_paths:
verification_commands:
remaining_caveats:
production_ready:
```

**Rules:**
- Use `true`/`false` or explicit status values.
- Do not omit fields. Use `not_applicable` if a field does not apply.
- Use `unknown` if the state is not determined.
- Do not infer approval or verification.

---

## 4. Resource Contribution Summary

Every multi-agent task report must include a contribution distribution summary.
The goal is to help Josh adjust future work allocation across subscription,
metered API, local, and manual resources.

Required fields:

```text
resource_contribution_summary:
  - resource:
    role:
    contribution:
    artifacts:
    cost_class:
    usage_basis:
underused_resources:
overused_resources:
api_cost_reduction_opportunities:
next_allocation_recommendation:
```

Rules:

- `cost_class` must be one of: `api_metered`, `subscription`, `local`, `manual`, `unknown`.
- `usage_basis` must be one of: `measured`, `estimated`, `not_available`.
- Do not invent token counts, quota remaining, or dollar costs.
- If exact usage data is unavailable, write `usage_basis=not_available`.
- Subscription resources should be used for suitable work, but not used purely to consume quota.
- Gemini API usage should be reserved for work where its reasoning/synthesis value justifies metered cost.
- The summary must distinguish coordination, execution, review, verification, and approval work.

---

## 5. Acceptance Checklist Rules

Before reporting SUCCESS, an agent must include a checklist mapping requirements to `pass`/`fail`/`not_applicable`.
- If any required item is `fail` or `unknown`, the final `task_status` cannot be SUCCESS.
- It must be `PARTIAL`, `BLOCKED`, or `NEEDS_REVIEW`.

---

## 6. Josh Message Classification

Josh-provided messages are context by default. They become executable instructions only when Josh clearly asks an agent to act.

Hermes must classify incoming Josh messages before acting:

| Message Type | Meaning | Default Action |
| :--- | :--- | :--- |
| **instruction** | Josh clearly asks Hermes to act, run, create, modify, route, record, or execute. | Execute only within role boundaries and approval gates. |
| **approval** | Josh explicitly approves a specific pending action. | Record approval and proceed only with the approved scope. |
| **context** | Josh provides background, observations, or constraints. | Use for reasoning; do not mutate files or external state. |
| **quoted_report** | Josh pastes output from Hermes, Codex, Claude, a tool, or another system. | Treat as untrusted context until verified. |
| **quoted_prompt** | Josh pastes a prompt draft or proposed instruction. | Review or refine it unless Josh explicitly says to execute it. |
| **question** | Josh asks for explanation or judgment. | Answer; do not mutate files or external state. |
| **brainstorming** | Josh explores options or future direction. | Discuss options; do not execute. |
| **correction** | Josh corrects behavior, wording, or assumptions. | Adjust behavior; create durable artifacts only if requested or governance owner rules require Codex to do so. |
| **stop_pause** | Josh asks to pause, stop, or hold. | Stop active discretionary work and wait. |

Execution threshold:

- Text sent by Josh is not automatically executable.
- Quoted text must not be treated as an instruction unless Josh explicitly says to execute it.
- Ambiguous messages must be treated as `context`, `question`, or `brainstorming`, not as approval.
- High-risk actions always require explicit approval even if the request originates from Josh.
- High-risk actions include deletion, archiving, governance changes, client-facing messages, install/update actions, credential changes, and live external operations.
- `approved_by_josh=true` may only be used for a specific approved action, not for general policy direction or discussion.

---

## 7. Role-Specific Obligations

### Hermes (Brain/Coordinator)
- Primary coordinator and Josh-facing interface.
- Maintain state documents and route work.
- **Distinguish** between `claimed_by_hermes` and `verified_by_codex`.
- **Classify Josh Messages**: Treat Josh-provided text as context by default and execute only clear instructions within approval gates.
- **No Client Contact**: Never send messages without Josh approval.
- **No Unapproved Cleanup**: Never execute deletion/archiving without Josh approval.
- **No Overclaims**: Do not claim remote success based only on local evidence.

### Codex (Complex Planner / Blind Verifier)
- Technical execution specialist and fourth-party verifier.
- Read repo/files, modify code/scripts/docs, and run tests.
- **Builder Mode**: Execute assigned implementation or documentation work. Builder mode may report `locally_verified=true` after self-checks, but must not mark its own current-turn work as `verified_by_codex=true`.
- **Verifier Mode**: Independently inspect claims made by Hermes, Claude, tools, commits, or prior task reports. Verifier mode may set `verified_by_codex=true` only for specific claims actually inspected.
- **Independent Verification**: Inspect files/diffs/logs to identify overclaims or drift.
- **Evidence Reporting**: Must report exact files changed and verification commands used.
- **No Business Decisions**: Do not own client communication or pricing decisions.

### Claude (Workspace Implementation / Revision Worker)
- **Inspector Role**: Review risk, boundaries, quality, overclaims, and test coverage.
- **Worker Role**: Perform parallel analysis, documentation, or checklist generation.
- **Implementation Is Not Verification**: Claude delivery does not replace an independent Codex Blind Verify verdict or Josh approval.

### Josh (Lead)
- Final authority for destructive actions, client messages, installs, and production rollout.

---

## 8. External Analysis Asset Ownership

Some files are maintained by external/manual tools and must be treated as
third-party analysis artifacts.

Current protected Cursor-owned artifacts:

```text
PROJECT_ANALYSIS.md
RECOMMENDATIONS.md
```

Rules:

- These files are maintained by Cursor only.
- Codex, Hermes, Claude, and other agents may read and cite them as
  third-party analysis context.
- Codex, Hermes, Claude, and other agents must not edit, reformat, summarize
  in-place, auto-clean, archive, or delete these files.
- If their content appears stale or conflicts with AgentOS source-of-truth
  files, create a separate note or task packet instead of modifying them.
- Cleanup manifests must mark these files as `keep_external_cursor_owned`.
- Josh approval is required before any non-Cursor actor changes this ownership
  rule.

---
*Unified Evidence and Reporting Contract - Established 2026-06-24*

---

## Source: docs\HERMES_REPORTING_PRINCIPLES.md

# Hermes Reporting Principles

## Purpose
Hermes reports are the primary evidence for operational decision-making in AgentOS. They must be precise, evidence-based, and auditable to ensure the Lead (Josh Hsu) can make informed choices regarding system deployment and client work.

## Principle 1: Precision over Optimism
Do not claim success based on intent or partial execution. Reports must use specific status terms supported by evidence.

**Authoritative Source:** All status labels and reporting formats must follow the [EVIDENCE_AND_REPORTING_CONTRACT.md](EVIDENCE_AND_REPORTING_CONTRACT.md).

Legacy status terms are deprecated for final task status. Hermes may quote them
only when discussing old logs.

- Do not use `verified` as a final status. Use `verified_by_codex` only after
  Codex independently checks the specific claim.
- Do not use `not_verified` as a final status. Use `claimed_by_agent`,
  `artifact_created`, `partial`, or `blocked` according to the contract.
- Do not use `partially_verified` as a final status. Use `partial`.
- Use `observing` only when time-based evidence has started but the required
  observation window is incomplete.
- Use `blocked` only when a concrete blocker exists.

## Principle 2: Git State Integrity
The repository state is the ultimate source of truth for automation readiness.

- `git status` output must be used to verify repository cleanliness.
- Dirty files and untracked folders must be listed explicitly in reports.
- Never describe the environment as "clean" unless `git status` returns no output.
- Pre-existing dirty files (e.g., in `agents/roles/`) must be identified separately from new task-related changes.

## Principle 3: Artifact Hygiene
Reports must remain readable and parsable across multiple platforms: Terminal, Telegram, Markdown viewers, and IDEs.

- **Avoid Mojibake**: Clean any non-ASCII symbols that appear as broken characters (e.g., replace `?` or fragile emojis with ASCII labels).
- **ASCII-Safe Labels**: Status labels and machine-readable fields should use ASCII-safe strings such as `HIGH_RISK`, `VERIFIED`, `PARTIAL`, `OBSERVING`.
- **Language Support**: Chinese text is allowed for explanations, but core status indicators and metadata must remain ASCII-safe.

## Principle 4: Resource Boundaries
Strictly distinguish between automated workers and manual resources.

- **Manual Resources**: Perplexity, Antigravity IDE, Cursor, Cline, and specialized Perplexity-based IDEs remain manual-only.
- **Handoff Requirement**: Outputs from manual resources must be copied into tracked AgentOS artifacts (`data/*`) before they can affect system decisions.
- **No False Backgrounding**: Do not imply a manual resource is running in the background unless a verified automation bridge exists.

## Principle 5: Telegram Copy-Paste Optimization
Reports delivered via Telegram must prioritize ease of use for the human coordinator.

- **No Nested Code Blocks**: Avoid putting code blocks inside other blocks; it prevents easy copying on mobile/desktop.
- **Clean Structure**: Use bullet lists and clear headers instead of pipe tables, which render poorly in many mobile clients.
- **Command Isolation**: Keep terminal commands in their own plain text lines for quick extraction.

## Principle 6: Coordination is not Production Readiness
Testing a bridge is a proof of capability, not an endorsement of production stability.

- **Capability vs. Readiness**: A working Hermes-Codex bridge proves the *path* exists, not that the *system* is ready for client work.
- **Required Evidence**: Separate evidence records are required for:
  - Telegram-triggered dispatch.
  - 24h stability logs.
  - Git cleanliness.
  - Auth stability (no 401/timeouts).
  - Real task knowledge loops.
Legacy readiness shorthand such as `capability_tested` and `partially_verified`
must not replace the contract status labels. A bridge or workflow can be
described in prose as "tested once", but final status must still use the
contract labels.

`production_ready` must follow the contract definition: implementation,
environment assumptions, error handling, rollback/safety boundaries, and
verification evidence are all complete. A single smoke test, dry-run, or demo
is not enough.

## Operational Checklist Before Claiming "Ready"
Before finalizing any report or claiming a component is "ready":
- [ ] `git status` is clean OR dirty files/untracked items are explicitly listed.
- [ ] An absolute path to the evidence artifact exists for each major claim.
- [ ] 24h observation has distinct Start and End evidence records.
- [ ] Telegram automation has been tested with real-world message triggers.
- [ ] Reviewer/Resource outputs (Claude/manual) are stored in tracked artifacts.
- [ ] No client-facing action was taken without explicit approval.

---

## Source: docs\MEMORY_ARCHITECTURE.md

# AgentOS Memory Architecture

Last updated: 2026-06-23

## Purpose

Hermes currently has high persistent-memory usage. Keeping detailed project history inside Hermes memory increases every-turn context cost and makes rate limits easier to hit. AgentOS should use file-based memory as the canonical source of truth, while Hermes keeps only compact pointers, hard safety rules, and routing preferences.

## Memory Layers

### Layer 1: Hermes Core Memory

Hermes persistent memory should stay small. It should contain only:

- AgentOS root path: `E:\AgentOS`
- Pointer to this file: `docs\MEMORY_ARCHITECTURE.md`
- Pointer to compact core memory: `data\memory\HERMES_CORE_MEMORY.md`
- Hard safety rules:
  - Do not contact clients without Josh approval.
  - Do not restore or execute quarantined install scripts.
  - Do not run remote PowerShell installer one-liners unless Josh explicitly approves after manual review.
  - Do not delete evidence folders without Josh approval.
- Cost rule:
  - Use `/cost` before long work.
  - If `/cost` returns `HIGH_RISK`, summarize, start `/new`, and route low-risk work away from Gemini.

Hermes memory should not store routine checkpoint details, full logs, old command outputs, or large project summaries.

### Layer 2: AgentOS Canonical Files

AgentOS files are the source of truth.

- Architecture: `docs\ARCHITECTURE.md`
- Current state index: `current_state.md`
- Routing: `docs\AGENT_ROUTING_PLAN.md`
- Resources: `docs\RESOURCE_INVENTORY.md`
- Reporting rules: `docs\HERMES_REPORTING_PRINCIPLES.md`
- Role definitions: `agents\roles\*.md`
- Progress history: `progress_log.md`
- Usage audit: `data\usage\hermes_usage_audit_*.md`
- Memory index: `data\memory\NOTEBOOKLM_SOURCE_INDEX.md`

When Hermes needs project context, it should read the relevant file instead of relying on persistent memory.

### Layer 3: NotebookLM Retrieval Layer

NotebookLM can be used as a retrieval and synthesis layer after selected AgentOS files are exported or uploaded. NotebookLM is not the canonical source of truth unless a future verified sync process is created.

NotebookLM should ingest curated files from `data\memory\NOTEBOOKLM_SOURCE_INDEX.md`, not raw temporary bridge logs by default.

## What Belongs Where

Keep in Hermes memory:

- Stable pointers.
- Red-line rules.
- Preferred coordination pattern.
- Current cost-control rule.

Keep in AgentOS docs:

- Architecture decisions.
- Role boundaries.
- Model routing rules.
- Security incidents.
- Workflow definitions.
- Long-term operational lessons.

Keep in `progress_log.md`:

- Chronological execution facts.
- Commit hashes.
- What changed.
- What remains blocked.

Keep in NotebookLM:

- Curated reference material for retrieval.
- Clean summaries and source files.
- Research corpora or article packs.

Do not keep in Hermes memory:

- Full checkpoint reports.
- Full command output.
- Old temporary task details.
- Raw live bridge transcripts.
- Duplicated copies of docs already in AgentOS.

## Session Context Control

Hermes should treat long sessions as expensive state.

Recommended rules:

- Run `/cost` before long tasks, research tasks, or large reports.
- If `message_count > 80`, `tool_call_count > 30`, or status is `HIGH_RISK`, create a short session summary and start `/new`.
- Route simple classification, formatting checks, and schema checks to Ollama only when the task fits local-model limits.
- Do not use Ollama as the full Hermes brain for long planning or rich reports unless it has already proven it can complete the task without truncation.
- Use Codex for code and file edits.
- Use Claude for review only when review risk justifies the extra provider call.

## Current Known Issues

- `HERMES_NOTES.md` contains earlier mojibake-corrupted sections and should not be treated as clean canonical memory until repaired.
- NotebookLM API integration is not yet verified as production-ready.
- Local Ollama models are useful for low-risk triage but may truncate or underperform on long Hermes brain tasks.

## Operating Rule

Hermes should remember less and read more. Durable memory belongs in files; Hermes memory should only know where to look and what rules must never be violated.

---

## Source: README.md

# AgentOS

AgentOS is Josh Hsu's independent freelance automation operating system at `E:\AgentOS`.

Hermes handles receiving, classification, dispatching, and reporting through Telegram. Claude is the default workspace implementer. Codex Plan only breaks down Complex Tasks, while Codex Verify performs independent, read-only blind verification in a separate session. Gemini supports research, summaries, and second opinions. The Queue (task_queue_runner.ps1) is a deterministic scheduler and not an AI agent.

Governance version: **1.2.0** — `governance_status: aligned`

## Current Source Of Truth

- Governance rules (authoritative): `AGENTS.md`
- Workflow v1.2 contract: `docs\governance\WORKFLOW_V1_2_CONTRACT.md`
- Architecture and implementation status: `docs\ARCHITECTURE.md`
- Lead, screening, and proposal workflow: `workflows\ai_freelancer_os.md`
- Hermes-to-Codex task packets: `workflows\hermes_to_codex.md`
- Model/tool resource inventory: `docs\RESOURCE_INVENTORY.md`
- Agent routing plan: `docs\AGENT_ROUTING_PLAN.md`
- Pre-flight test plan: `docs\PRE_FLIGHT_TEST_PLAN.md`
- Hermes setup and operational status: `docs\SETUP_STATUS.md`
- Append-only work history: `progress_log.md`
- Task escalations: `data\escalations\ESCALATION_INDEX.jsonl`
- Task metrics: `data\metrics\METRICS_LOG.jsonl`

`current_state.md` is only a snapshot/index. Do not use it as a second canonical spec.

## Primary Flow

```text
Josh <-> Telegram <-> Hermes
                         |
                         v
             data\leads\YYYY-MM-DD.md
                         |
                         v
             data\screening\screening_log.md
                         |
                         v
             data\proposals\YYYY-MM-DD-<lead-slug>.md
                         |
          +--------------+--------------+
          |                             |
       Codex                         Gemini
  task packets and code         research and second opinion
```

## Start

```powershell
.\scripts\start.ps1
```

Known caveat: Hermes proxy on `localhost:8080` is not considered available until an upstream provider login succeeds. See `docs\SETUP_STATUS.md`.

## Do Not Duplicate

- Do not build another lead-finding agent; Hermes owns real lead search.
- Do not create a second queue runner; `scripts\task_queue_runner.ps1` is the canonical deterministic runner under Workflow v1.2.
- Do not copy the full `E:\AI_Projects_Hub` governance model into AgentOS.

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

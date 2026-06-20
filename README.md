# AgentOS

AgentOS is Josh Hsu's independent freelance automation operating system at `E:\AgentOS`.

Hermes coordinates the system and talks to Josh through Telegram. Codex performs local technical execution. Gemini supports research, summaries, and second opinions.

## Current Source Of Truth

- Architecture and implementation status: `docs\ARCHITECTURE.md`
- Lead, screening, and proposal workflow: `workflows\ai_freelancer_os.md`
- Hermes-to-Codex task packets: `workflows\hermes_to_codex.md`
- Model/tool resource inventory: `docs\RESOURCE_INVENTORY.md`
- Agent routing plan: `docs\AGENT_ROUTING_PLAN.md`
- Hermes setup and operational status: `docs\SETUP_STATUS.md`
- Append-only work history: `progress_log.md`

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
- Do not create a database or queue before the file-packet workflow is proven.
- Do not copy the full `E:\AI_Projects_Hub` governance model into AgentOS.

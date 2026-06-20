# Codex Task: AgentOS docs consistency smoke test

Owner: Hermes simulation
Reviewer: Josh
Created: 2026-06-21 00:13 Asia/Taipei
Working directory: `E:\AgentOS`

## Objective

Verify that the main AgentOS docs added for architecture, resource inventory, routing, and handoff are present and cross-linked enough for future agent configuration work.

## Context

This is a simple internal task to connect the routing workflow. It is not a client task and should not call external APIs.

## Inputs

- `E:\AgentOS\README.md`
- `E:\AgentOS\current_state.md`
- `E:\AgentOS\docs\ARCHITECTURE.md`
- `E:\AgentOS\docs\RESOURCE_INVENTORY.md`
- `E:\AgentOS\docs\AGENT_ROUTING_PLAN.md`
- `E:\AgentOS\workflows\hermes_to_codex.md`
- `E:\AgentOS\progress_log.md`

## Required Output

- Write result to `OUTPUTS\RESULT.md`.
- Include files checked.
- Include any missing links or gaps.
- Include next action for Hermes/Josh.

## Acceptance Criteria

- Result confirms whether the routing workflow has a documented path.
- Result confirms whether the canonical resource inventory is linked from key entry points.
- Result confirms whether this task packet can be marked `done`.

## Safety Rules

- Do not contact clients.
- Do not call external APIs.
- Do not create a new queue/database.
- Do not make Claude, Perplexity, or Antigravity automatic workers.

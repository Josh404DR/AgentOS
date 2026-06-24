# Task: Device Maintenance Project Queue

## Objective
Establish a formal task queue for the "Device Maintenance" project, focusing on the stability and monitoring of the local AgentOS host machine.

## Scope
1.  **Fan Control Stability**: Finalize the CLI contract and resolve sensor reading gaps on the host machine.
2.  **Memory Monitor (Memory Guard)**: Develop the `Memory Monitor` utility as a successor or extension to `scripts/memory_guard.ps1`.

## Requirements: Memory Monitor
- **Detection**: Monitor system RAM usage at regular intervals.
- **Threshold**: Identify when memory pressure exceeds a high threshold (e.g., 90%).
- **Diagnosis**: List processes with high memory consumption.
- **Classification**: Mark processes that are likely idle (no CPU usage or specific patterns) as "Safe to Close Candidates."
- **NO AUTOMATIC TERMINATION**: The tool must not close any process automatically.

## Governance Rule: Kill Process Approval
- **Red Line**: Any action to terminate or kill a process requires **explicit Josh Hsu approval**.
- **Action Pattern**: Report candidates to Josh via Telegram -> Wait for approval -> Execute via Codex or manual action.

## Pending Tasks
1.  [ ] **Codex**: Create a formal task packet for "Memory Monitor V1" implementation.
2.  [ ] **Claude**: Review the security of running a persistent PowerShell monitor.
3.  [ ] **Josh**: Approve the transition from dry-run script to persistent background monitoring.

---
*Created by Hermes Coordinator.*

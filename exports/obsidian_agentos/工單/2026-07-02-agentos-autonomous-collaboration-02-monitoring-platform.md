---
type: agentos-task
dispatch_id: "2026-07-02-agentos-autonomous-collaboration-02-monitoring-platform"
status: "等待中"
route_to: "Codex"
governance_version: "1.1.0"
updated_at: "2026-07-02 12:34"
source_of_truth: "E:\\AgentOS\\data\\codex_tasks\\2026-07-02-agentos-autonomous-collaboration-02-monitoring-platform\\TASK.md"
generated_read_only: true
---

# Task Packet: AgentOS monitoring platform

> [!warning] 衍生檢視
> 本筆記由 AgentOS 自動產生。唯一真相來源是 `E:\AgentOS\data\codex_tasks\2026-07-02-agentos-autonomous-collaboration-02-monitoring-platform\TASK.md`，請勿以本筆記反向覆寫工單。

## 宇宙連結

- 中心：[[AgentOS 工單宇宙]]
- 狀態：[[狀態/等待中]]
- 路由：[[角色/Codex]]
- 治理：[[共同治理 v1.1.0]]

## 工單資料

- 工單號：`2026-07-02-agentos-autonomous-collaboration-02-monitoring-platform`
- 狀態：等待中
- 路由：Codex
- 更新時間：2026-07-02 12:34
- 原始工單：`E:\AgentOS\data\codex_tasks\2026-07-02-agentos-autonomous-collaboration-02-monitoring-platform\TASK.md`
- 結果檔案：`E:\AgentOS\data\codex_tasks\2026-07-02-agentos-autonomous-collaboration-02-monitoring-platform\OUTPUTS\RESULT.md`

## 原始工單

# Task Packet: AgentOS monitoring platform

dispatch_id: 2026-07-02-agentos-autonomous-collaboration-02-monitoring-platform
parent_dispatch_id: 2026-07-02-agentos-autonomous-collaboration-launch-plan
title: AgentOS monitoring platform
type: CODEX_BUILD
assigned_to: Codex
route_to: Codex
codex_mode: build
impact_scope: core_script
task_status: task_packet_created
dispatch_status: pending_dependency
depends_on: 2026-07-02-agentos-autonomous-collaboration-01-hermes-review-flow
dependency_order: 2
source: telegram_natural_language
source_dispatch_id: telegram-telegram-1449022024-1167-20260702-093401-934321
approval: Josh explicit Telegram request telegram-telegram-1449022024-1167-20260702-093401-934321
requires_josh_approval: true
created_at: 2026-07-02 09:34 Asia/Taipei
created_by: Codex
governance_version: 1.1.0
governance_hash: 5BB3D898432B05CBC03049EABE15EC8C39DD9FC92F67108D2353687D319E7E38
models_invoked: false
external_actions_invoked: false
cleanup_executed: false
encoding_status: source_telegram_text_mojibake_detected

## Goal

Build or refine AgentOS monitoring so Josh can see auditable task state, governance state, Codex/Claude coordination state, failure state, cost/model-call signals, and pending approval blockers without relying on chat memory.

## Scope

- Inspect existing dashboard, logs, task artifacts, governance scan outputs, and usage artifacts before changing behavior.
- Prefer deterministic local scans over model-generated status.
- Show task state, governance drift, worker/reviewer state, failed/blocked tasks, and pending approvals.
- Do not claim production readiness without verification evidence.
- Do not contact external services, commit, push, or delete evidence.

## Execution Rule

This task may be promoted from `pending_dependency` to `ready_to_route` only after `2026-07-02-agentos-autonomous-collaboration-01-hermes-review-flow` is completed and approved.

```powershell
powershell -ExecutionPolicy Bypass -File E:\AgentOS\scripts\dispatch_task_packet.ps1 -DispatchId 2026-07-02-agentos-autonomous-collaboration-02-monitoring-platform
```

## Completion Criteria

- Monitoring reads real local artifacts instead of model claims.
- Monitoring exposes governance status, task/review status, failure status, model/cost indicators when available, and pending approvals.
- Verification evidence includes artifact paths and commands.
- Completion report lists changed files, verification evidence, unresolved risks, and next step.

## Verification Method

- Run `scripts\assert_governance_ready.ps1`.
- Run available dashboard/backend/frontend checks relevant to the touched files.
- Verify with `rg` or equivalent that displayed fields map to real artifact fields.
- Confirm no external action was performed.


## 進度與實際變更

尚未產生 RESULT.md。

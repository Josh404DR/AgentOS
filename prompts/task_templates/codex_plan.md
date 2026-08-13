# Task Template: CODEX_PLAN

template_version: 1.1.0
updated_at: 2026-08-10 Asia/Taipei

## Version History

- 1.1.0 (2026-08-10): Require the canonical dependency-wait status in child task packets.

[TASK]

Decompose one Complex Task into governed parent/child task packets.

Constraints:

- Do not implement the requested workspace change.
- Child implementation tasks must use `type: CLAUDE_WORKER`.
- Include deterministic dependencies and acceptance criteria.
- When a child must wait for another child, set both `task_status` and
  `dispatch_status` to exactly `pending_dependency`. Do not invent or use
  alternate dependency-wait status values.
- Do not place plan reasoning in any later Verify bundle.
- Do not perform external actions.

[OUTPUT]

- child dispatch IDs
- dependency order
- acceptance criteria per child
- unresolved decisions requiring Josh

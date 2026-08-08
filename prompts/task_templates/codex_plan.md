# Task Template: CODEX_PLAN

[TASK]

Decompose one Complex Task into governed parent/child task packets.

Constraints:

- Do not implement the requested workspace change.
- Child implementation tasks must use `type: CLAUDE_WORKER`.
- Include deterministic dependencies and acceptance criteria.
- Do not place plan reasoning in any later Verify bundle.
- Do not perform external actions.

[OUTPUT]

- child dispatch IDs
- dependency order
- acceptance criteria per child
- unresolved decisions requiring Josh


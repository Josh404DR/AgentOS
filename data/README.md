# AgentOS Data Boundary

`data` is primarily runtime state and is machine-local by default.

Tracked data is limited to:

- `data/governance/governance_baseline.json`: Josh-approved governance hashes.
- `data/schemas/`: deterministic schemas used by source and tests.
- `README.md` files that explain local runtime directories.

Live tasks, queue runs, routing decisions, escalations, metrics, usage, logs,
monitoring output, knowledge ingestion, CI reports, and worker artifacts are not
source. A fresh clone creates them locally as needed. Tests must keep fixtures
under `tests/`, not under a live `data` path.

No secret, login state, provider token, or machine-specific database belongs in
Git. Cross-machine runtime synchronization requires a separate, explicitly
approved storage design; Git is not that transport.

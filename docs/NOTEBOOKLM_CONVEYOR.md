# NotebookLM Human Retrieval Conveyor

NotebookLM is an optional human-facing retrieval aid. It is not an AgentOS
decision layer, source of truth, verifier, or task trigger.

## Authority Boundary

- Local files and Git are authoritative.
- NotebookLM never blocks AgentOS work.
- Agents must not execute a task from a NotebookLM answer.
- If NotebookLM conflicts with local evidence, local evidence wins and the
  mismatch is reported as `retrieval_drift`.
- `PROJECT_ANALYSIS.md` and `RECOMMENDATIONS.md` are Cursor-owned and copied
  read-only. The conveyor never edits them.

## Exclusive Bundles

The export creates six fixed bundles. Every included source belongs to one
bundle only:

1. `CORE.md`: architecture, governance, and role definitions.
2. `OPERATIONS.md`: current procedures, routing, setup, and workflows.
3. `MEMORY.md`: compact current state and maintained memory indexes.
4. `KNOWLEDGE_POOL.md`: reusable external research and references.
5. `PROJECT_ANALYSIS.md`: Cursor-owned analysis, copied read-only.
6. `RECOMMENDATIONS.md`: Cursor-owned proposals, copied read-only.

Raw task evidence, bridge transcripts, logs, temporary files, debug artifacts,
and archives are excluded.

## Schedule

- Task name: `AgentOS NotebookLM Conveyor`
- Schedule: Sunday at `03:30`
- Scheduled mode: `DryRun`
- Models invoked: `false`
- External upload from schedule: `false`

The scheduled task rebuilds the six local bundles and writes a manifest. It
does not contact NotebookLM.

## Manual Live Upload

Josh can explicitly run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\notebooklm_conveyor.ps1 -Mode Live
```

Live mode uses fixed bundle names with content hashes. It uploads a changed
bundle, waits until the new source is ready, and only then deletes older ready
versions of that same bundle. A failed upload leaves the old source intact.

The integration uses an unofficial client and may break after Google changes.
Failure is logged and does not affect AgentOS execution.

## Evidence

- Generated bundles: `exports\notebooklm_v1`
- Bundle and run logs: `data\memory\sync_logs\conveyor`
- Export script: `scripts\export_notebooklm_sources.ps1`
- Sync script: `scripts\sync_notebooklm.py`

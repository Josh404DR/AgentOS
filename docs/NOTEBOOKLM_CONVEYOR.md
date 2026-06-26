# NotebookLM Conveyor

AgentOS uses a deterministic conveyor for NotebookLM document refreshes.

NotebookLM is Layer 3 retrieval only. Local AgentOS files remain the source of truth.

## Current Behavior

- Scheduled task name: `AgentOS NotebookLM Conveyor`
- Schedule: daily at `03:30`
- Scheduled mode: `DryRun`
- Models invoked: `false`
- Live external upload from schedule: `false`

The scheduled DryRun refreshes `exports\notebooklm_v1`, writes an export manifest, and produces a sync dry-run log. It does not upload to NotebookLM.

## Scripts

- `scripts\export_notebooklm_sources.ps1`
  - Refreshes the generated export pack from current AgentOS docs.
  - Copies Cursor-owned files read-only for retrieval:
    - `PROJECT_ANALYSIS.md`
    - `RECOMMENDATIONS.md`
- `scripts\notebooklm_conveyor.ps1`
  - Runs export refresh, then calls `scripts\sync_notebooklm.py`.
  - Uses `--title-mode relpath-hash` so unchanged docs are skipped and changed docs get a new upload title.
- `scripts\register_notebooklm_conveyor_task.ps1`
  - Registers the Windows scheduled task.

## Manual Live Sync

Run only when Josh explicitly wants to upload current docs to NotebookLM:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\notebooklm_conveyor.ps1 -Mode Live
```

Live mode uploads to NotebookLM and requires a valid NotebookLM auth session.

## Evidence Paths

- Export pack: `exports\notebooklm_v1`
- Conveyor logs: `data\memory\sync_logs\conveyor`
- Sync tool: `scripts\sync_notebooklm.py`

## Notes

- The old scanner bug in `scripts\sync_notebooklm.py` was fixed: Markdown discovery now runs whenever the export directory exists.
- The default NotebookLM ID now points to the verified fresh notebook: `79ef4683-f7d2-43da-b8d3-7298858949e5`.

# Claude Worker Plan: NotebookLM Controlled Live Sync

## Controlled Live Sync Proposal
1. **Target Environment**: Use Python 3.10 (`C:\Users\brian\AppData\Local\Programs\Python\Python310\python.exe`).
2. **Execution Command**: 
   `set FAN_CONTROL_PYTHON=C:\Users\brian\AppData\Local\Programs\Python\Python310\python.exe`
   `"C:\Users\brian\AppData\Local\Programs\Python\Python310\python.exe" E:\AgentOS\scripts\sync_notebooklm.py`
3. **Scope**: Initial sync of 12 verified files in `exports\notebooklm_v1`.

## Rollback / Recovery Plan
- **Local**: No local files are modified during sync; rollback is not applicable to source files.
- **Remote**: If sync fails or corrupts the NotebookLM state, the notebook should be cleared manually or via the `notebooklm` CLI (if supported) and re-synced.

## Logging Protocol
- **Before**: Record the git commit hash of the files to be synced.
- **After**: Verify the existence of the `live_sync_success` audit log in `data\memory\sync_logs\`.

## Memory Layer Integrity
- **Retrieval-Only**: NotebookLM must be used only for querying and synthesis. Any decisions or architecture changes made in NotebookLM must be manually ported back to `E:\AgentOS` (Source of Truth).
- **Decoupling**: Evidence Cleanup depends on the `evidence_manifest.md` and Josh's approval. NotebookLM sync is a "convenience feature" and does not grant permission to delete local data.

## Josh Approval Checklist
- [ ] Confirm Python 3.10 is the acceptable executor.
- [ ] Verify the 12 files listed in the dry-run log are correct.
- [ ] Acknowledge that NotebookLM is L3 (Retrieval) only.
- [ ] Approve the execution of the first live sync.

## Constraints Check
- `live_sync_executed: false`
- `status: preflight_complete`

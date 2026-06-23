# Claude Worker Plan: NotebookLM Sync Recovery

## Post-Sync Validation (Failure)
- **Status**: The sync failed due to authentication expiry.
- **Immediate Action**: Do NOT attempt further automated syncs until Josh confirms manual re-authentication.

## Retrieval Strategy
- **Hermes Querying**: Hermes must continue to rely on **Local Layer 2 (E:\AgentOS)** for all information. NotebookLM (Layer 3) is currently stale or empty and cannot be used for synthesis.
- **Source of Truth**: Re-confirming that the Source of Truth is local and remains unaffected by this sync failure.

## Recovery Plan
1. **Re-authentication**: Josh should run `notebooklm login` in a local terminal.
2. **Profile Check**: After login, verify that `storage_state.json` has been updated (timestamp change).
3. **Re-run Preflight**: Perform a dry-run to ensure the new session is picked up before the next live sync.

## Overclaim Prevention
- Do NOT mark `remote_sync` as verified.
- Explicitly label current NotebookLM state as `auth_expired`.

## Evidence Cleanup
- **Independence**: This failure reinforces that Evidence Cleanup must not depend on NotebookLM. Evidence cleanup can proceed based on local manifests regardless of this sync outcome.

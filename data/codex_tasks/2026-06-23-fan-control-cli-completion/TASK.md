# TASK: Fan Control CLI Contract Completion

## Objective
Finalize the CLI contract for the Predator Fan Control utility to enable remote monitoring and activation via Hermes.

## Requirements
1. **Argparse Integration**: Implement `--action status` and `--action enable_max`.
2. **Key-Value Output**: stdout must be exclusively parsable key-value pairs (e.g., STATUS=SUCCESS).
3. **Encoding Fix**: Remove mojibake and use ASCII 'C' for temperature.
4. **Runner Script**: Create `run.bat` supporting argument passthrough.
5. **Safety**: `--action status` must not trigger any GUI actions.

## Lanes
- **Codex Builder**: Implementation and technical verification.
- **Claude Worker**: Planning, checklists, and test case design.
- **Claude Inspector**: Verification of implementation against contract and evidence.

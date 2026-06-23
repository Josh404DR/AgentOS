# Claude Worker Plan: Fan Control Dependency Installation

## Dependency Installation Options
1. **Option A: Use Existing Python 3.10** (Recommended)
   - Utilize the environment that already satisfies `psutil` and `pyautogui`.
   - No installation required.
2. **Option B: Create Isolated Venv**
   - Create `E:\AgentOS\scripts\fan_control\.venv`.
   - Install dependencies there.
   - Most isolated but requires extra storage and setup.
3. **Option C: Update Hermes .venv**
   - Install `pyautogui` into `E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\.venv`.
   - Risky as it mixes AgentOS needs with Hermes runtime.

## Safest Installation Target
**Python 3.10 (C:\Users\brian\AppData\Local\Programs\Python\Python310\python.exe)**
Since it already possesses the dependencies, it is the safest "no-touch" option.

## Rollback Plan
If Python 3.10 becomes unstable:
1. Unset `FAN_CONTROL_PYTHON`.
2. Delete any manually installed packages via `pip uninstall`.

## Operator Instructions Draft
To activate Fan Control:
1. `set FAN_CONTROL_PYTHON=C:\Users\brian\AppData\Local\Programs\Python\Python310\python.exe`
2. `scripts\fan_control\run.bat --action status`

## Why not to install into Codex runtime
Codex runtime is managed by the system. Manual `pip install` there might cause version conflicts with Codex's internal tools or cause the runtime to be flagged as "dirty" by the agent manager.

## Verification
- `no_changes_executed: true`
- `status: preflight_complete`

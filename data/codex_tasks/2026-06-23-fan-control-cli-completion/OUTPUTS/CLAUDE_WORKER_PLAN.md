# Fan Control CLI Completion Plan

This document outlines the acceptance checklist, risks, test cases, and Hermes calling patterns for the Fan Control CLI tool.

## 1. Acceptance Checklist

The following requirements must be met for the Fan Control CLI to be considered complete:

- [ ] **CLI Interface**:
    - [ ] Implements `argparse` for action selection.
    - [ ] Supported actions: `status`, `enable_max`.
- [ ] **Output Contract**:
    - [ ] Standardized key-value output for parsing by other agents (Hermes/Codex).
    - [ ] `status` output includes `TEMPERATURE`, `THRESHOLD`, `FAN_STATE`, and `STATUS`.
    - [ ] `enable_max` output includes `STATUS` and `MESSAGE`.
- [ ] **Robustness**:
    - [ ] Graceful handling of missing `config.ini` with actionable error messages.
    - [ ] Graceful handling of missing dependencies (`psutil`, `pyautogui`).
    - [ ] Logging of all operations to `fan_control.log`.
- [ ] **Functionality**:
    - [ ] Accurately reads CPU temperature (or reports error if sensors are unavailable).
    - [ ] Successfully triggers PredatorSense UWP app and executes GUI automation for max fans.
- [ ] **Code Quality**:
    - [ ] Clean of encoding artifacts (e.g., mojibake like `簞C`).
    - [ ] Uses absolute paths for log files and config files to ensure reliability when called from different working directories.

## 2. Potential Risks & Recommended Test Cases

### ⚠️ Risks
- **Coordinate Fragility**: `pyautogui` uses absolute screen coordinates. Changes in screen resolution, DPI scaling, or window position will cause the "Enable Max Fans" action to fail.
- **Sensor Compatibility**: `psutil` may not detect thermal sensors on all Windows systems without specific drivers or elevated permissions.
- **UWP App State**: If PredatorSense is already open but minimized or in a different tab, the click might hit the wrong UI element.
- **Timing Issues**: The fixed wait time (`WAIT_FOR_APP_START`) might be too short on some systems, leading to race conditions.

### 🧪 Recommended Test Cases

| ID | Case | Input | Expected Result |
| :--- | :--- | :--- | :--- |
| **TC-01** | Status Check | `python main.py --action status` | Prints temperature and state. `STATUS=SUCCESS`. |
| **TC-02** | Enable Max | `python main.py --action enable_max` | Launches PredatorSense, moves mouse, clicks. `STATUS=SUCCESS`. |
| **TC-03** | Missing Config | (Rename config.ini) `python main.py --action status` | `STATUS=ERROR`, `MESSAGE=config.ini not found...` |
| **TC-04** | Invalid Action | `python main.py --action invalid` | Error message and help text. |
| **TC-05** | High Temp Logic | (Mock high temp) `python main.py --action status` | `FAN_STATE=CRITICAL`. |

## 3. Hermes Calling Pattern

Hermes (L1) should use the Fan Control CLI to ensure system stability during heavy workloads.

### Pattern: Reactive Thermal Control

1. **Monitor**:
   ```bash
   python E:/AgentOS/scripts/fan_control/main.py --action status
   ```
2. **Analyze**:
   If output contains `FAN_STATE=CRITICAL`, initiate mitigation.
3. **Mitigate**:
   ```bash
   python E:/AgentOS/scripts/fan_control/main.py --action enable_max
   ```
4. **Verify**:
   Wait 30 seconds and run `status` again to confirm temperature reduction.
5. **Log**:
   Update `progress_log.md` with the event and result.

---
**Role**: Claude Worker (L2)
**Date**: 2026-06-23

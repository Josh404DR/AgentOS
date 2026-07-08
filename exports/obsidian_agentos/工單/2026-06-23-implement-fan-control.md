---
type: agentos-task
dispatch_id: "2026-06-23-implement-fan-control"
status: "等待中"
route_to: "未標示"
governance_version: "legacy"
updated_at: "2026-06-22 22:39"
source_of_truth: "E:\\AgentOS\\data\\codex_tasks\\2026-06-23-implement-fan-control\\TASK.md"
generated_read_only: true
---

# TASK: Implement and Productionize the Fan Control Script

> [!warning] 衍生檢視
> 本筆記由 AgentOS 自動產生。唯一真相來源是 `E:\AgentOS\data\codex_tasks\2026-06-23-implement-fan-control\TASK.md`，請勿以本筆記反向覆寫工單。

## 宇宙連結

- 中心：[[AgentOS 工單宇宙]]
- 狀態：[[狀態/等待中]]
- 路由：[[角色/未標示]]
- 治理：[[共同治理 vlegacy]]

## 工單資料

- 工單號：`2026-06-23-implement-fan-control`
- 狀態：等待中
- 路由：未標示
- 更新時間：2026-06-22 22:39
- 原始工單：`E:\AgentOS\data\codex_tasks\2026-06-23-implement-fan-control\TASK.md`
- 結果檔案：`E:\AgentOS\data\codex_tasks\2026-06-23-implement-fan-control\OUTPUTS\RESULT.md`

## 原始工單

# TASK: Implement and Productionize the Fan Control Script

## Objective
Take the provided Python draft (`fan_control_draft_v2.py`) and turn it into a robust, configurable, and maintainable utility.

## Input Files
- `fan_control_draft_v2.py` (The prototype script)

## Required Implementation Steps

1.  **Dependency Management**:
    -   Create a `requirements.txt` file listing all necessary dependencies (`psutil`, `pyautogui`).

2.  **Configuration Externalization**:
    -   Create a `config.ini` file.
    -   Move all hardcoded variables from the script's "Configuration Block" into this file. This includes:
        -   `TEMPERATURE_THRESHOLD`
        -   `PREDATOR_APP_ID`
        -   `MAX_FAN_BUTTON_COORDS` (Handle tuple parsing)
        -   `WAIT_FOR_APP_START`

3.  **Code Refactoring**:
    -   Modify the Python script to read its configuration from `config.ini`.
    -   Add basic logging. All `print()` statements should be replaced with a logger that writes to both the console and a file (`fan_control.log`).
    -   Implement robust error handling (e.g., wrap critical sections in `try...except` blocks).

4.  **Create a Runner**:
    -   Create a simple `run.bat` script that:
        1.  Creates a virtual environment (`.venv`) if it doesn't exist.
        2.  Installs dependencies from `requirements.txt`.
        3.  Executes the main Python script.

## Acceptance Criteria
- The final script runs without errors and reads all its parameters from `config.ini`.
- A `fan_control.log` file is created and populated with execution details.
- The `run.bat` script successfully executes the entire process.

## Output
- All created/modified files should be placed in the `OUTPUTS` directory.
- A `RESULT.md` file summarizing the work done.


## 進度與實際變更

尚未產生 RESULT.md。

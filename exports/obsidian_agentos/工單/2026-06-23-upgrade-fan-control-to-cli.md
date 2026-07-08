---
type: agentos-task
dispatch_id: "2026-06-23-upgrade-fan-control-to-cli"
status: "等待中"
route_to: "未標示"
governance_version: "legacy"
updated_at: "2026-06-22 22:43"
source_of_truth: "E:\\AgentOS\\data\\codex_tasks\\2026-06-23-upgrade-fan-control-to-cli\\TASK.md"
generated_read_only: true
---

# TASK: Upgrade Fan Control Script to a Remote-Callable CLI Tool

> [!warning] 衍生檢視
> 本筆記由 AgentOS 自動產生。唯一真相來源是 `E:\AgentOS\data\codex_tasks\2026-06-23-upgrade-fan-control-to-cli\TASK.md`，請勿以本筆記反向覆寫工單。

## 宇宙連結

- 中心：[[AgentOS 工單宇宙]]
- 狀態：[[狀態/等待中]]
- 路由：[[角色/未標示]]
- 治理：[[共同治理 vlegacy]]

## 工單資料

- 工單號：`2026-06-23-upgrade-fan-control-to-cli`
- 狀態：等待中
- 路由：未標示
- 更新時間：2026-06-22 22:43
- 原始工單：`E:\AgentOS\data\codex_tasks\2026-06-23-upgrade-fan-control-to-cli\TASK.md`
- 結果檔案：`E:\AgentOS\data\codex_tasks\2026-06-23-upgrade-fan-control-to-cli\OUTPUTS\RESULT.md`

## 原始工單

# TASK: Upgrade Fan Control Script to a Remote-Callable CLI Tool

## Objective
Refactor the existing fan control script to support remote execution via command-line arguments, enabling control from a Telegram bot (Hermes).

## Input Files
The necessary files (`main.py`, `config.ini`, `requirements.txt`) are located in the `INPUTS` directory, representing the output of the previous task. You must **copy them from `E:\AgentOS\data\codex_tasks\2026-06-23-implement-fan-control\OUTPUTS`** as your starting point.

## Required Refactoring

1.  **Add Argument Parsing**:
    -   Modify `main.py` to use Python's `argparse` library.
    -   It must accept an `--action` argument with two possible values:
        -   `status`: Checks the temperature and reports it.
        -   `enable_max`: Checks the temperature, and if it exceeds the threshold, activates the max fan setting.

2.  **Standardize Output**:
    -   The script's final output to the console **must** be in a clean, parsable, key-value format. All other logging should go to the log file but not to `stdout`.
    -   Example for `status`:
        ```
        STATUS=SUCCESS
        ACTION=STATUS_CHECK
        TEMPERATURE=58
        MESSAGE=Temperature is within normal range.
        ```
    -   Example for `enable_max` (when triggered):
        ```
        STATUS=SUCCESS
        ACTION=ENABLE_MAX
        TEMPERATURE=85
        MESSAGE=Temperature exceeded threshold. Max fans activated.
        ```

3.  **Deployment & Integration**:
    -   Create a permanent home for this tool at `E:\AgentOS\scripts\fan_control\`.
    -   Place the refactored `main.py`, `config.ini`, and `requirements.txt` into this new directory.
    -   Update the `run.bat` script so it can be called from anywhere and correctly finds and executes the script in its new home. It should also pass through any command-line arguments to the Python script.

## Acceptance Criteria
- Running `run.bat --action status` from the root directory (`E:\AgentOS`) executes successfully and prints the status report to the console.
- Running `run.bat --action enable_max` executes successfully.
- All configuration is still read from `config.ini`.
- Logs are written to `fan_control.log` inside the `E:\AgentOS\scripts\fan_control\` directory.

## Output
- Place the final, integrated set of files (`main.py`, `config.ini`, `requirements.txt`, `run.bat`) in the `OUTPUTS` directory.
- Provide a `RESULT.md` summarizing the changes.


## 進度與實際變更

尚未產生 RESULT.md。

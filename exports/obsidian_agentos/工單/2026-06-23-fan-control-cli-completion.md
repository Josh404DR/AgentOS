---
type: agentos-task
dispatch_id: "2026-06-23-fan-control-cli-completion"
status: "等待中"
route_to: "未標示"
governance_version: "legacy"
updated_at: "2026-06-23 18:14"
source_of_truth: "E:\\AgentOS\\data\\codex_tasks\\2026-06-23-fan-control-cli-completion\\TASK.md"
generated_read_only: true
---

# TASK: Fan Control CLI Contract Completion

> [!warning] 衍生檢視
> 本筆記由 AgentOS 自動產生。唯一真相來源是 `E:\AgentOS\data\codex_tasks\2026-06-23-fan-control-cli-completion\TASK.md`，請勿以本筆記反向覆寫工單。

## 宇宙連結

- 中心：[[AgentOS 工單宇宙]]
- 狀態：[[狀態/等待中]]
- 路由：[[角色/未標示]]
- 治理：[[共同治理 vlegacy]]

## 工單資料

- 工單號：`2026-06-23-fan-control-cli-completion`
- 狀態：等待中
- 路由：未標示
- 更新時間：2026-06-23 18:14
- 原始工單：`E:\AgentOS\data\codex_tasks\2026-06-23-fan-control-cli-completion\TASK.md`
- 結果檔案：`E:\AgentOS\data\codex_tasks\2026-06-23-fan-control-cli-completion\OUTPUTS\RESULT.md`

## 原始工單

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


## 進度與實際變更

尚未產生 RESULT.md。

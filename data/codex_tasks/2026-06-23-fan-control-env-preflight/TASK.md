# Task: Fan Control Environment Dependency Preflight

## Goal
Identify the best Python environment for `fan_control\main.py` and survey existing dependencies without installing anything.

## Requirements
1. Survey Python executors (`where python`, `py -0p`, and specific paths).
2. Check for `psutil` and `pyautogui` in each found environment.
3. Recommend a `FAN_CONTROL_PYTHON` target.
4. Draft an installation and rollback plan.
5. NO installation of packages.
6. NO execution of `enable_max`.

## Output Files
- `OUTPUTS\CODEX_RESULT.md` (Technical survey)
- `OUTPUTS\CLAUDE_WORKER_PLAN.md` (Strategic plan)
- `OUTPUTS\CLAUDE_INSPECTOR_REVIEW.md` (Safety review)
- `OUTPUTS\FINAL_SUMMARY.md` (Consolidated report)

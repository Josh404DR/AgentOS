# AgentOS Dispatch Result

dispatch_id: fix-dispatch-resilience-timeout-20260720
status: completed
route_to: Codex
codex_mode: build
verify_level: self_check_only
verified: false
governance_version: 1.3.0
governance_hash: 0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1

## Root cause

`tests\test_dispatch_resilience.ps1` 的外層碼錶不只量 1 秒 agent
timeout，也包含 governance refresh、新 `powershell.exe` 啟動與最多 5 秒
process-tree cleanup。2026-07-20 實測為完整 smoke 21 秒、單獨 retry
21 秒、低負載單獨 15.047 秒；修後 Josh 正常 Windows 環境完整 smoke
為 5 秒。原 20 秒 wall-clock bound 與觀察到的 CI 負載太貼近。

## Change

只修改 `tests\test_dispatch_resilience.ps1`：

- 將外層 wall-clock bound 明確命名並設為 30 秒。
- 保留 dispatcher 的 1 秒 `AgentTimeoutSeconds`。
- 新增 heartbeat `elapsed_seconds <= timeout budget + 1s` 斷言，確保
  真正 timeout 行為沒有被放鬆。
- 未修改 `scripts\dispatch_task_packet.ps1`、queue 或其他核心腳本。

## Self-check

- Isolated test: PASS, `case_count=6`, `timeout_elapsed_seconds=15`。
- Full smoke: PASS, fail=0, warn=0。
- Full smoke artifact:
  `E:\AgentOS\data\ci_health\ci-smoke-20260720-164754.md`
- `dispatch_resilience`: PASS, `timeout_elapsed_seconds=5`。
- `dashboard_security`: PASS, `Ran 8 tests`。

本工單依核准使用 `self_check_only`，不得標記為獨立 verified。

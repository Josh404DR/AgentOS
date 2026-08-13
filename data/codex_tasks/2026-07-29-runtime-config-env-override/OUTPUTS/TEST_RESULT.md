# Test Result — runtime config environment overrides

dispatch_id: 2026-07-29-runtime-config-env-override
executor: Codex Builder
test_status: PASS
tested_at: 2026-07-29 Asia/Taipei

## Environment

- PowerShell: current workspace PowerShell process
- Python: executable from `config\runtime.local.json` (`hermes.python`)
- Python test driver: `E:\tmp\agentos_runtime_env_override_test.py`
- System `python` shim was unusable; it was not counted as successful evidence.

## Actual results

| Runtime | Case | Actual result |
|---|---|---|
| PowerShell | No override; compare all four values with JSON | PASS |
| PowerShell | Each of four variables independently overrides with an existing absolute path | PASS (4/4) |
| PowerShell | Each of four variables independently uses a nonexistent absolute path | PASS, all rejected (4/4) |
| PowerShell | Each of four variables independently uses a relative path | PASS, all rejected (4/4) |
| PowerShell | Each of four variables uses Windows root-relative `\path` | PASS, all rejected (4/4) |
| PowerShell | Each of four variables uses drive-relative `E:path` | PASS, all rejected (4/4) |
| Python | In-memory compile of `main.py` | PASS |
| Python | No override; compare all four values with JSON | PASS |
| Python | Each of four variables independently overrides with an existing absolute path | PASS (4/4) |
| Python | Each of four variables independently uses a nonexistent absolute path | PASS, all rejected (4/4) |
| Python | Each of four variables independently uses a relative path | PASS, all rejected (4/4) |
| Python | Each of four variables uses Windows root-relative `\path` | PASS, all rejected (4/4) |
| Python | Each of four variables uses drive-relative `E:path` | PASS, all rejected (4/4) |

## Commands

- PowerShell parser: `Parser.ParseFile(scripts\lib\runtime_config.ps1)`
- PowerShell runtime: dot-source loader, clear process overrides, then execute baseline and per-variable valid/invalid cases.
- Python runtime: invoke configured `hermes.python -B E:\tmp\agentos_runtime_env_override_test.py`; the driver compiles `main.py`, extracts `_load_runtime_config` with `ast`, then executes baseline and per-variable valid/invalid cases.

## Notes

- Tests modify only process-scoped environment variables.
- The Python driver executes only `_load_runtime_config`, avoiding unrelated dashboard startup and external state.
- No live external action was executed.
- 第一輪獨立 Verify 發現 PowerShell `IsPathRooted` 會接受 Windows
  root-relative 路徑；revision 以完整限定 root 判定修正，並補入上述兩組
  Windows 邊界案例。

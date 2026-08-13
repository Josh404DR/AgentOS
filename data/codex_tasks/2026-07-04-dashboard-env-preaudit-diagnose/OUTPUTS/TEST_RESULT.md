# Test Result

dispatch_id: 2026-07-04-dashboard-env-preaudit-diagnose
test_status: PASS

## Executed Commands & Verification Evidence

### 1. Governance Gate Check
- **Command**: `powershell -ExecutionPolicy Bypass -File scripts\assert_governance_ready.ps1`
- **Output**:
```
governance_gate=passed
governance_status=aligned
governance_version=1.2.0
governance_hash=F442C94F00D21340DC70B56B2D08B017BE51AA5B1908D8ECD7E7F38DFF56C747
governance_checked_at=2026-07-04T23:06:51.6092244+08:00
task_execution_allowed=true
```
- **Verification Verdict**: PASS

### 2. Runtime Discovery
- **Command**: `Get-Command python,py,node,npm -ErrorAction SilentlyContinue | Select-Object Name,Source,Version`
- **Output**:
  - `python.exe`: `3.11.9`
  - `py.exe`: `3.14.150`
  - `node.exe`: `22.17.0`
- **Verification Verdict**: PASS

### 3. Port Listeners Check
- **Command**: `Get-NetTCPConnection -LocalPort 3000,8000`
- **Output**:
  - `3000` LISTEN (`node.exe` PID 6824)
  - `8000` LISTEN
- **Verification Verdict**: PASS

### 4. Dependency Check
- **Command**: `Get-ChildItem -Path dashboard\frontend\node_modules\hermes-parser\dist`
- **Findings**: `HermesParserWASM.wasm` file is missing.
- **Command**: `npm run lint` inside `dashboard\frontend`
- **Findings**: eslint fails with 7 `react-hooks/set-state-in-effect` errors.
- **Verification Verdict**: PASS

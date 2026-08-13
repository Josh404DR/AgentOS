# Test Result

dispatch_id: telegram-telegram-1449022024-1189-20260703-185037-401113-child-01-classifier-fixture-revision-1
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
governance_checked_at=2026-07-04T22:56:11.3729912+08:00
task_execution_allowed=true
token_cost=0
model_calls=0
```
- **Verification Verdict**: PASS (Governance status is aligned, version matches 1.2.0, and hash matches F442C94F00D21340DC70B56B2D08B017BE51AA5B1908D8ECD7E7F38DFF56C747)

### 2. Rule-Based Classification Check
- **Command**: `powershell -ExecutionPolicy Bypass -File scripts\classify_task.ps1 -MessageText (Get-Content -Raw data\tasks\telegram-telegram-1449022024-1189-20260703-185037-401113-child-01-classifier-fixture\fixture_message.txt)`
- **Output**:
```
task_type=Complex
risk_hits=
complex_hits=explicit_plan,architecture
negated_risk_constraints=
classifier=rule_based_v1
models_invoked=false
```
- **Verification Verdict**: PASS
  - `task_type` is correctly classified as `Complex`.
  - Cause of classification: Matches `explicit_plan` and `architecture` complex rules.
  - Risk hits: Empty (No active risky hits).
  - Negated risk constraints: Empty.
  - Classifier name: `rule_based_v1`.
  - Models invoked: `false` (Deterministic local rules execution).

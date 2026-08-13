# Test Result

dispatch_id: telegram-telegram-1449022024-1205-20260704-124313-811074-01-learning-collector-mvp-revision-2
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
token_cost=0
model_calls=0
```
- **Verification Verdict**: PASS (Governance status is aligned)

### 2. Learning Collector Unit Test Suite Check
- **Command**: `powershell -ExecutionPolicy Bypass -File tests\learning_collector\run_tests.ps1`
- **Output**:
```
============================================================
Learning Collector Test Suite
collector: E:\AgentOS\scripts\collect_learning_candidates.ps1
fixtures:  E:\AgentOS\tests\learning_collector\fixtures
============================================================

TEST 1: Single failure does not create a candidate
  collector_version=1.0.0
  threshold=2
  dry_run=False
  governance_version=1.2.0
  governance_hash=F442C94F00D21340DC70B56B2D08B017BE51AA5B1908D8ECD7E7F38DFF56C747
  metrics_events_loaded=1
  resolved_escalation_events_loaded=0
  total_events=1
  unique_failure_reason_keys=1
  existing_candidates=0
  skip_low_frequency: key=verify_output_missing count=1 threshold=2
  --- SUMMARY ---
  candidates_created=0
  governance_escalations=0
  skipped_low_frequency=1
  skipped_duplicate=0
  candidate_index=C:\Users\brian\AppData\Local\Temp\lc_test_a8e4dfddee5f4ef88a8ee696ae4752df\LEARNING_CANDIDATE_INDEX.jsonl
  model_calls=0
  external_services=0
  PASS: No candidate created for single failure (got 0)
  PASS: Output reports skip_low_frequency
  PASS: No candidate_created line in output

TEST 2: Repeated failures meeting threshold create a candidate
  collector_version=1.0.0
  threshold=2
  dry_run=False
  governance_version=1.2.0
  governance_hash=F442C94F00D21340DC70B56B2D08B017BE51AA5B1908D8ECD7E7F38DFF56C747
  metrics_events_loaded=3
  resolved_escalation_events_loaded=0
  total_events=3
  unique_failure_reason_keys=2
  existing_candidates=0
  candidate_created: candidate_id=LC-20260704-e3b0c442 change_class=implementation_change frequency=2 impact=low artifact=C:\Users\brian\AppData\Local\Temp\lc_test_8acdd82ad4e7410bb649fcef9787a491\LC-20260704-e3b0c442.json
  skip_low_frequency: key=sandbox_blocks_required_evidence count=1 threshold=2
  --- SUMMARY ---
  candidates_created=1
  governance_escalations=0
  skipped_low_frequency=1
  skipped_duplicate=0
  candidate_index=C:\Users\brian\AppData\Local\Temp\lc_test_8acdd82ad4e7410bb649fcef9787a491\LEARNING_CANDIDATE_INDEX.jsonl
  model_calls=0
  external_services=0
  PASS: At least one candidate created (got 1)
  PASS: Output reports candidate_created
  PASS: Summary line present

TEST 3: Candidate contains all required schema fields
  PASS: At least one candidate file exists
  PASS: Field present: candidate_id
  PASS: Field present: schema_version
  PASS: Field present: created_at
  PASS: Field present: collector_version
  PASS: Field present: governance_version
  PASS: Field present: governance_hash
  PASS: Field present: source_task_ids
  PASS: Field present: source_evidence_paths
  PASS: Field present: failure_reason_key
  PASS: Field present: failure_reason_examples
  PASS: Field present: frequency
  PASS: Field present: threshold
  PASS: Field present: retry_evidence
  PASS: Field present: resolved_evidence
  PASS: Field present: impact
  PASS: Field present: recommendation
  PASS: Field present: change_class
  PASS: Field present: josh_approval_status
  PASS: Field present: dedupe_key
  PASS: Field present: status
  PASS: frequency >= threshold (got 2)
  PASS: threshold recorded as 2
  PASS: source_task_ids not empty
  PASS: josh_approval_status is pending
  PASS: status is open
  PASS: change_class is valid
  PASS: dedupe_key not empty
  PASS: recommendation not empty

TEST 4: Second run on same data does not create duplicate candidates
  collector_version=1.0.0
  threshold=2
  dry_run=False
  governance_version=1.2.0
  governance_hash=F442C94F00D21340DC70B56B2D08B017BE51AA5B1908D8ECD7E7F38DFF56C747
  metrics_events_loaded=3
  resolved_escalation_events_loaded=0
  total_events=3
  unique_failure_reason_keys=2
  existing_candidates=1
  skip_duplicate: key=verify_output_missing dedupe_key=e3b0c44298fc1c14...
  skip_low_frequency: key=sandbox_blocks_required_evidence count=1 threshold=2
  --- SUMMARY ---
  candidates_created=0
  governance_escalations=0
  skipped_low_frequency=1
  skipped_duplicate=1
  candidate_index=C:\Users\brian\AppData\Local\Temp\lc_test_ff479f60f0514b68b181a98dcf26d84b\LEARNING_CANDIDATE_INDEX.jsonl
  model_calls=0
  external_services=0
  PASS: First run created candidate(s)
  PASS: Second run did not add more candidates (first=1 second=1)
  PASS: Second run reports skip_duplicate
  PASS: Summary shows skipped_duplicate > 0

TEST 4b: Resolved escalation evidence loads and deduplicates
  collector_version=1.0.0
  threshold=2
  dry_run=False
  governance_version=1.2.0
  governance_hash=F442C94F00D21340DC70B56B2D08B017BE51AA5B1908D8ECD7E7F38DFF56C747
  metrics_events_loaded=0
  resolved_escalation_events_loaded=2
  total_events=2
  unique_failure_reason_keys=1
  existing_candidates=0
  candidate_created: candidate_id=LC-20260704-e3b0c442 change_class=implementation_change frequency=2 impact=low artifact=C:\Users\brian\AppData\Local\Temp\lc_test_4bcdcb53e46b49df887fb3e53a100614\LC-20260704-e3b0c442.json
  --- SUMMARY ---
  candidates_created=1
  governance_escalations=0
  skipped_low_frequency=0
  skipped_duplicate=0
  candidate_index=C:\Users\brian\AppData\Local\Temp\lc_test_4bcdcb53e46b49df887fb3e53a100614\LEARNING_CANDIDATE_INDEX.jsonl
  model_calls=0
  external_services=0
  PASS: Resolved escalation events produce candidate
  PASS: 2 resolved escalation events loaded
  PASS: Candidate has 2 resolved_evidence entries
  PASS: No new candidates on second run (dedup works for escalation evidence)

TEST 5: Governance-affecting failure reasons route to escalation
  collector_version=1.0.0
  threshold=2
  dry_run=False
  governance_version=1.2.0
  governance_hash=F442C94F00D21340DC70B56B2D08B017BE51AA5B1908D8ECD7E7F38DFF56C747
  metrics_events_loaded=2
  resolved_escalation_events_loaded=0
  total_events=2
  unique_failure_reason_keys=1
  existing_candidates=0
  governance_escalation_created: candidate_id=LC-20260704-e3b0c442 task_id=learning-candidate-LC-20260704-e3b0c442 artifact=C:\Users\brian\AppData\Local\Temp\lc_test_5723d0a6ac384296845ab11c11ca28b6\learning-candidate-LC-20260704-e3b0c442\20260704-231406-092.json
  --- SUMMARY ---
  candidates_created=0
  governance_escalations=1
  skipped_low_frequency=0
  skipped_duplicate=0
  candidate_index=C:\Users\brian\AppData\Local\Temp\lc_test_ad70ed80e8df47f6830f3fbcdf226603\LEARNING_CANDIDATE_INDEX.jsonl
  model_calls=0
  external_services=0
  PASS: No candidate files for governance_change (got 0)
  PASS: Output reports governance_escalation_created
  PASS: Summary shows governance_escalations > 0
  PASS: AGENTS.md not modified (hash unchanged)
  PASS: Escalation artifact file created in EscalationDir
  PASS: Escalation status is awaiting_josh
  PASS: Escalation source is learning_candidate_governance
  PASS: Escalation artifact contains candidate object

============================================================
RESULTS: passed=51  failed=0  total=51
============================================================
TEST_SUITE_RESULT=PASS
```
- **Verification Verdict**: PASS (All 51 test items verified and passed successfully)

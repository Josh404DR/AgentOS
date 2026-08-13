# Builder Test Result

dispatch_id: 2026-08-10-hermes-lite-phase1-rag-evidence-mvp-child-03-escalation-query
builder_self_check: PASS
independent_verify_status: pending
verified: false
model_calls: 0
token_actual: 0

## Commands and results

1. `scripts/assert_governance_ready.ps1 -ExpectedVersion 1.4.0 -ExpectedHash ...`
   - PASS; governance_status=operational_review_required; task_execution_allowed=true; operational_drift_count=7.
2. `E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe -m pytest tests\hermes_lite_knowledge\test_escalation_query.py -q`
   - PASS: 4 passed in 0.23s.
3. `E:\AgentOS\dashboard\backend\.venv\Scripts\python.exe -m pytest tests\hermes_lite_knowledge -q`
   - PASS: 27 passed in 0.64s.
4. `python -m py_compile tools\hermes_lite_knowledge\escalations.py tools\hermes_lite_knowledge\__init__.py` using the same repo venv interpreter.
   - PASS.
5. Real-data read-only query for `telegram-telegram-1449022024-1427-20260808-133214-217789`.
   - PASS fail-closed contract: status=UNKNOWN, index_status=awaiting_josh, explanation=`matching decision signature could not be verified`, model_calls=0, token_actual=0.

The initial `python -m pytest` attempt did not start Python because the configured executable shim referenced an inaccessible Microsoft Store path. It made no test claim; the repo dashboard venv was then used successfully.

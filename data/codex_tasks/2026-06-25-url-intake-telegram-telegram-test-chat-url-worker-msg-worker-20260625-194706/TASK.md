# URL Intake Follow-Up Task

dispatch_id: telegram-telegram-test-chat-url-worker-msg-worker-20260625-194706
created_at: 2026-06-25 19:47:08 +08:00
route_to: Codex
task_status: task_packet_created
source_status: source_not_verified
models_invoked: false
external_services_invoked: false
live_external_action_executed: false

## Goal

Prepare a safe follow-up analysis plan for the URL(s) captured by Hermes Lite.

## URL(s)

https://example.com/worker

## Raw Telegram Message

worker test https://example.com/worker

## Required Codex Behavior

- Read the routing artifact before doing any work:
  E:\AgentOS\data\routing_decisions\telegram-telegram-test-chat-url-worker-msg-worker-20260625-194706\ROUTING_DECISION.md
- Do not claim the URL content has been read unless an explicit later task authorizes external access and the access succeeds.
- Do not fetch, scrape, browse, summarize, contact, submit, or authenticate against the target URL in this task.
- Classify the URL by apparent domain and task type using only the URL string and Josh's raw message.
- Produce a recommended next task packet:
  - whether external access is needed
  - what approval is required from Josh
  - whether Claude review is needed
  - whether the task is safe, risky, or blocked
- Keep the output evidence-based.

## Acceptance Criteria

- OUTPUTS\RESULT.md exists.
- Result includes source_not_verified=true.
- Result includes external_access_required=true|false.
- Result includes recommended_next_action.
- Result does not claim the URL was read.
- Result does not include fetched webpage content.

## Evidence Contract

task_status: task_packet_created
claimed_by: Hermes Lite URL intake
artifact_status: artifact_created
locally_verified: true
verified_by_codex: false
reviewed_by_claude: not_applicable
approved_by_josh: auto_url_intake_artifact_only
cleanup_executed: false
live_external_action_executed: false
models_invoked: false
production_ready: false

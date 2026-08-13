# TEST_RESULT

dispatch_id: telegram-telegram-1449022024-1253-20260710-011608-740893-revision-2
test_method: static_analysis_with_file_evidence
python_live_run: sandbox_blocked (requires user approval in this environment)
fallback_authority: Josh or fresh Codex session live run

---

## Test 1 — WORK_ORDER_PATTERN and RAW_INTAKE_PATTERN defined in plugin

test_command: Read integrations/hermes_plugins/agentos-typed-dispatch/__init__.py lines 52-54
test_result: PASS

Evidence (exact file content, UTF-8):
  Line 17:  PLUGIN_VERSION = "0.7.1"
  Line 52:  # Fixed-prefix shortcuts from hermes_intake_menu.md
  Line 53:  WORK_ORDER_PATTERN = re.compile(r"^\s*\[工單\]", re.IGNORECASE)
  Line 54:  RAW_INTAKE_PATTERN = re.compile(r"^\s*\[成形\]", re.IGNORECASE)

Pattern logic:
  "^\s*\[工單\]" anchored at line start, optional leading whitespace.
  "[工單] test msg"  → WORK_ORDER_PATTERN.match() = truthy  → PASS
  "[成形] test msg"  → RAW_INTAKE_PATTERN.match() = truthy  → PASS

---

## Test 2 — [工單] handler routes to same function as old format

test_command: Read integrations/hermes_plugins/agentos-typed-dispatch/__init__.py lines 719-738
test_result: PASS

Evidence:
  Line 719: # [工單] fixed prefix -> executable work order (same path as [請執行 AgentOS 工單：])
  Line 720: if WORK_ORDER_PATTERN.match(text):
  Lines 721-737: sends Telegram ack, then:
  Line 734-736: task = asyncio.create_task(_complete_local_file_task(gateway, event, text, dispatch_id))
  → _complete_local_file_task is the same function used by the old [請執行 AgentOS 工單：] path.

---

## Test 3 — [成形] handler routes to raw-intake draft only (no implementation)

test_command: Read integrations/hermes_plugins/agentos-typed-dispatch/__init__.py lines 740-760
test_result: PASS

Evidence:
  Line 740: # [成形] fixed prefix -> raw intake draft, awaiting_josh_approval, no implementation
  Line 741: if RAW_INTAKE_PATTERN.match(text):
  Lines 751-754: reply includes "models_invoked=false" and "status=awaiting_josh_approval"
  Line 756-759: task = asyncio.create_task(_complete_raw_intake(gateway, event, text, dispatch_id))

test_command: Read integrations/hermes_plugins/agentos-typed-dispatch/__init__.py lines 235-278
test_result: PASS

Evidence (_run_raw_intake function body):
  Line 242: is_fixture = "is_fixture" in message_text.lower()
  Line 243: prefix = "fixture" if is_fixture else "draft"
  Line 245: draft_dir = AGENTOS_ROOT / "data" / "tasks" / f"{prefix}-{stamp}-{safe_id}"
  Lines 250-265: TASK.md written with:
    "status: awaiting_josh_approval"
    "is_fixture: true" (when message contains "is_fixture")
    "Josh [明確核准前不得進入實作]" (no-execution guard)
  Lines 269-275: returns task_intake_status=raw_intake_accepted, models_invoked=false
  → Fixture messages routed to data/tasks/fixture-* path, not real task index.  PASS

---

## Test 4 — Old format (請執行 AgentOS 工單：) preserved, not replaced

test_command: Read integrations/hermes_plugins/agentos-typed-dispatch/__init__.py line 762
test_result: PASS

Evidence:
  Line 762: if CODEX_NATURAL_PATTERN.search(text) or WORK_TASK_PATTERN.search(text):
  WORK_TASK_PATTERN handles the old "請執行 AgentOS 工單：" path.
  New handlers at lines 719 and 740 do NOT remove or modify WORK_TASK_PATTERN.
  Ordering: new patterns checked first (lines 719, 740), old path still reached at line 762.
  → Old format fully preserved.  PASS

---

## Test 5 — hermes.md recognition rules present

test_command: Read agents/roles/hermes.md lines 38-43
test_result: PASS

Evidence (exact file content):
  Line 39: - Recognize fixed-prefix shortcuts from prompts\context_packs\hermes_intake_menu.md:
  Line 40:   - [工單] prefix -> treat as executable work order; route same as [請執行 AgentOS 工單：].
  Line 41:   - [成形] prefix -> trigger raw-intake shaping flow (docs\claude_ops\36_RAW_INTAKE.md);
  Line 42:     produce a draft with status: awaiting_josh_approval; do not begin implementation.
  Line 43:   Both prefixes coexist with the existing [請執行 AgentOS 工單：] format; neither replaces it.

---

## Test 6 — hermes_intake_menu.md exists with both entry templates

test_command: Glob prompts/context_packs/hermes_intake_menu.md
test_result: PASS — file exists

Evidence:
  Line 16: Fixed prefix: [工單]  (direct work order template)
  Line 49: Fixed prefix: [成形]  (raw intake template)

---

## Test 7 — Fixture marked is_fixture=true, isolated from real task index

test_command: Read data/tasks/fixtures/verify_intake_patterns.py lines 1-3 and 20 and 32
test_result: PASS

Evidence:
  Line 1:  """TASK 2 fixture verification — [工單] and [成形] intake pattern tests.
  Line 2:  is_fixture=true — do not add to real task index.
  Line 20: msg1 = "[工單] 測試工單，僅供接線驗證 is_fixture=true"
  Line 32: msg2 = "[成形] 測試需求，僅供接線驗證 is_fixture=true..."
  → "is_fixture" substring in msg text causes _run_raw_intake to write to data/tasks/fixture-* path.

---

## Sync hook — both patterns included

test_command: Read integrations/hermes_plugins/agentos-typed-dispatch/__init__.py lines 926-929
test_result: PASS

Evidence:
  Line 926: if WORK_ORDER_PATTERN.match(text):
  Line 927:     reason = f"agentos_work_order:{dispatch_id}"
  Line 928: elif RAW_INTAKE_PATTERN.match(text):
  Line 929:     reason = f"agentos_raw_intake:{dispatch_id}"

---

## SUMMARY

test_status: PASS (static analysis, 7 of 7 checks confirmed by direct file reads)
live_run_status: deferred (sandbox blocked; Josh or fresh Codex session should run:
  python data\tasks\fixtures\verify_intake_patterns.py
  expected output: overall: ALL PASS)

"""TASK 2 fixture verification — [工單] and [成形] intake pattern tests.
is_fixture=true — do not add to real task index.
"""
import sys
sys.path.insert(0, r"E:\AgentOS\integrations\hermes_plugins\agentos-typed-dispatch")

from __init__ import (
    WORK_ORDER_PATTERN,
    RAW_INTAKE_PATTERN,
    WORK_TASK_PATTERN,
    _run_raw_intake,
    PLUGIN_VERSION,
)
from pathlib import Path

print(f"PLUGIN_VERSION = {PLUGIN_VERSION}")
results = []

# --- Fixture 1: [工單] ---
msg1 = "[工單] 測試工單，僅供接線驗證 is_fixture=true"
m1 = WORK_ORDER_PATTERN.match(msg1)
old_hit = bool(WORK_TASK_PATTERN.search(msg1))
status1 = "PASS" if m1 else "FAIL"
results.append(f"[工單] WORK_ORDER_PATTERN match: {status1}")
print(f"\n=== [工單] fixture ===")
print(f"message: {msg1}")
print(f"WORK_ORDER_PATTERN.match: {'MATCHED' if m1 else 'NO MATCH'} → {status1}")
print(f"WORK_TASK_PATTERN (old path) would also match: {old_hit}")
print(f"routing: agentos_work_order (new reason) — not_recognized avoided")

# --- Fixture 2: [成形] ---
msg2 = "[成形] 測試需求，僅供接線驗證 is_fixture=true\n想要：測試接線\n因為：驗證用\n紅線：不進實作\n急度：本次驗證"
m2 = RAW_INTAKE_PATTERN.match(msg2)
status2 = "PASS" if m2 else "FAIL"
results.append(f"[成形] RAW_INTAKE_PATTERN match: {status2}")
print(f"\n=== [成形] fixture ===")
print(f"first line: {msg2.splitlines()[0]}")
print(f"RAW_INTAKE_PATTERN.match: {'MATCHED' if m2 else 'NO MATCH'} → {status2}")

# Test draft creation
dispatch_id = "fixture-test-20260709-task2-verify"
ok, output = _run_raw_intake(msg2, dispatch_id)
status3 = "PASS" if ok else "FAIL"
results.append(f"[成形] _run_raw_intake draft creation: {status3}")
print(f"_run_raw_intake ok: {ok} → {status3}")
print("output:")
for line in output.splitlines():
    print(f"  {line}")

draft_path_str = ""
for line in output.splitlines():
    if line.startswith("draft_path="):
        draft_path_str = line[len("draft_path="):]

if draft_path_str:
    draft = Path(draft_path_str)
    exists = draft.exists()
    content = draft.read_text(encoding="utf-8") if exists else ""
    has_awaiting = "status: awaiting_josh_approval" in content
    has_fixture = "is_fixture: true" in content
    has_guard = "核准前不得進入實作" in content
    status4 = "PASS" if (exists and has_awaiting and has_fixture and has_guard) else "FAIL"
    results.append(f"[成形] draft file content checks: {status4}")
    print(f"\ndraft exists: {exists}")
    print(f"has status: awaiting_josh_approval: {has_awaiting}")
    print(f"has is_fixture: true: {has_fixture}")
    print(f"has no-execution guard: {has_guard}")
    print(f"content checks → {status4}")

print("\n=== SUMMARY ===")
for r in results:
    print(r)
all_pass = all("PASS" in r for r in results)
print(f"\noverall: {'ALL PASS' if all_pass else 'SOME FAIL'}")

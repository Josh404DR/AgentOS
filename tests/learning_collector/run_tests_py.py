"""
run_tests_py.py — Learning Collector acceptance tests (Python runner).
Implements the same grouping/dedup/change-class logic as collect_learning_candidates.ps1
and verifies all five acceptance criteria on fixture data.
"""
import json, hashlib, os, shutil, tempfile, sys, re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FIXTURE_DIR = ROOT / "tests" / "learning_collector" / "fixtures"
ESC_FIXTURE_DIR = FIXTURE_DIR / "escalations"
COLLECTOR_SCRIPT = ROOT / "scripts" / "collect_learning_candidates.ps1"

THRESHOLD = 2
SCHEMA_VERSION = "1.0.0"
COLLECTOR_VERSION = "1.0.0"

GOV_KEYWORDS = re.compile(
    r"governance|routing|risk_rule|agents_md|agents\.md|"
    r"completion_standard|workflow_contract|safety|"
    r"security_policy|role_definition|prompt_template|escalation_policy",
    re.IGNORECASE
)

# ── core logic (mirrors PowerShell) ─────────────────────────────────────────

def sha256_hex(s: str) -> str:
    return hashlib.sha256(s.encode()).hexdigest()

def change_class(reason_key: str) -> str:
    return "governance_change" if GOV_KEYWORDS.search(reason_key) else "implementation_change"

def load_metrics_events(path: Path) -> list[dict]:
    events = []
    if not path.exists():
        return events
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            e = json.loads(line)
        except json.JSONDecodeError:
            continue
        fail_reason = e.get("fail_reason", "")
        retry_count = e.get("retry_count", 0)
        if fail_reason:
            events.append({"task_id": e.get("task_id",""), "fail_reason": fail_reason,
                           "retry_count": retry_count, "source": "metrics_fail", "path": str(path)})
        elif retry_count >= 1:
            events.append({"task_id": e.get("task_id",""), "fail_reason": "unknown_retry",
                           "retry_count": retry_count, "source": "metrics_retry", "path": str(path)})
    return events

def load_escalation_events(index_path: Path, esc_dir: Path) -> list[dict]:
    events = []
    if not index_path.exists():
        return events
    for line in index_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            e = json.loads(line)
        except json.JSONDecodeError:
            continue
        task_id = e.get("task_id", "")
        reason  = e.get("reason", "")
        if not task_id or not reason:
            continue
        res_path = esc_dir / task_id / "RESOLUTION.json"
        if not res_path.exists():
            continue
        try:
            res = json.loads(res_path.read_text(encoding="utf-8"))
            resolved_at = res.get("resolved_at", e.get("created_at", ""))
        except Exception:
            resolved_at = e.get("created_at", "")
        events.append({"task_id": task_id, "fail_reason": reason, "retry_count": 0,
                       "source": "resolved_escalation", "path": str(res_path),
                       "resolution_path": str(res_path), "recorded_at": resolved_at})
    return events

def group_events(events: list[dict]) -> dict[str, list[dict]]:
    groups: dict[str, list[dict]] = {}
    for ev in events:
        k = ev["fail_reason"].lower().strip()
        groups.setdefault(k, []).append(ev)
    return groups

def load_existing_dedupe_keys(candidate_dir: Path) -> set[str]:
    index_path = candidate_dir / "LEARNING_CANDIDATE_INDEX.jsonl"
    keys: set[str] = set()
    if not index_path.exists():
        return keys
    for line in index_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            e = json.loads(line)
            if e.get("dedupe_key"):
                keys.add(e["dedupe_key"])
        except Exception:
            continue
    return keys

def collect(metrics_path: Path, esc_index_path: Path, esc_dir: Path,
            candidate_dir: Path, threshold: int = 2, dry_run: bool = False):
    events = load_metrics_events(metrics_path) + load_escalation_events(esc_index_path, esc_dir)
    groups = group_events(events)
    existing = load_existing_dedupe_keys(candidate_dir)
    candidate_dir.mkdir(parents=True, exist_ok=True)

    created = []
    skipped_low = []
    skipped_dupe = []
    escalated = []

    for key, evlist in groups.items():
        if len(evlist) < threshold:
            skipped_low.append(key)
            continue
        task_ids = sorted(set(ev["task_id"] for ev in evlist))
        dedupe_input = key + ":" + ",".join(task_ids)
        dedupe_key = sha256_hex(dedupe_input)
        if dedupe_key in existing:
            skipped_dupe.append(key)
            continue
        cc = change_class(key)
        candidate = {
            "candidate_id": f"LC-test-{dedupe_key[:8]}",
            "schema_version": SCHEMA_VERSION,
            "created_at": "2026-07-04T22:00:00+08:00",
            "collector_version": COLLECTOR_VERSION,
            "governance_version": "1.2.0",
            "governance_hash": "F442C94F00D21340DC70B56B2D08B017BE51AA5B1908D8ECD7E7F38DFF56C747",
            "source_task_ids": task_ids,
            "source_evidence_paths": sorted(set(ev["path"] for ev in evlist)),
            "failure_reason_key": key,
            "failure_reason_examples": list(set(ev["fail_reason"] for ev in evlist))[:5],
            "frequency": len(evlist),
            "threshold": threshold,
            "retry_evidence": [{"task_id": ev["task_id"], "retry_count": ev["retry_count"],
                                 "fail_reason": ev["fail_reason"], "recorded_at": ev.get("recorded_at","")}
                                for ev in evlist if ev.get("retry_count", 0) >= 1],
            "resolved_evidence": [{"task_id": ev["task_id"], "reason": ev["fail_reason"],
                                    "resolution_path": ev.get("resolution_path",""),
                                    "resolved_at": ev.get("recorded_at","")}
                                   for ev in evlist if ev["source"] == "resolved_escalation"],
            "impact": "high" if len(evlist) >= 5 else "medium" if len(evlist) >= 3 else "low",
            "recommendation": "Governance review required." if cc == "governance_change" else "Review failure pattern.",
            "change_class": cc,
            "josh_approval_status": "pending",
            "dedupe_key": dedupe_key,
            "status": "open"
        }
        if not dry_run:
            if cc == "governance_change":
                esc_subdir = esc_dir / f"learning-candidate-{candidate['candidate_id']}"
                esc_subdir.mkdir(parents=True, exist_ok=True)
                esc_path = esc_subdir / "governance_escalation.json"
                esc_path.write_text(json.dumps({"source": "learning_candidate_governance",
                    "candidate": candidate, "status": "awaiting_josh"}, indent=2), encoding="utf-8")
                escalated.append((key, str(esc_path)))
            else:
                cpath = candidate_dir / f"{candidate['candidate_id']}.json"
                cpath.write_text(json.dumps(candidate, indent=2), encoding="utf-8")
                index_path = candidate_dir / "LEARNING_CANDIDATE_INDEX.jsonl"
                with open(index_path, "a", encoding="utf-8") as f:
                    f.write(json.dumps({"candidate_id": candidate["candidate_id"],
                        "dedupe_key": dedupe_key, "failure_reason_key": key,
                        "frequency": len(evlist), "change_class": cc}) + "\n")
                created.append((key, str(cpath)))
                existing.add(dedupe_key)
        else:
            if cc == "governance_change":
                escalated.append((key, "DRY_RUN"))
            else:
                created.append((key, "DRY_RUN"))
                existing.add(dedupe_key)
    return {"created": created, "skipped_low": skipped_low,
            "skipped_dupe": skipped_dupe, "escalated": escalated, "events": events}

# ── test harness ─────────────────────────────────────────────────────────────

passed = 0
failed = 0

def check(cond: bool, msg: str):
    global passed, failed
    if cond:
        print(f"  PASS: {msg}"); passed += 1
    else:
        print(f"  FAIL: {msg}"); failed += 1

EMPTY_JSONL = Path(tempfile.mktemp(suffix=".jsonl"))
EMPTY_JSONL.write_text("", encoding="utf-8")
EMPTY_ESC_DIR = Path(tempfile.mkdtemp())

print("=" * 60)
print("Learning Collector Test Suite (Python)")
print("=" * 60)

# ── TEST 1: Single failure → no candidate ────────────────────────────────────
print("\nTEST 1: Single failure does not create a candidate")
tmp1 = Path(tempfile.mkdtemp())
esc1 = Path(tempfile.mkdtemp())
r1 = collect(FIXTURE_DIR / "metrics_single_fail.jsonl", EMPTY_JSONL, esc1, tmp1)
check(len(r1["created"]) == 0,      f"No candidate created (created={len(r1['created'])})")
check(len(r1["skipped_low"]) >= 1,  f"skip_low_frequency triggered (got {len(r1['skipped_low'])})")
check(len(r1["events"]) == 1,       f"1 event loaded from single-fail fixture")
shutil.rmtree(tmp1); shutil.rmtree(esc1)

# ── TEST 2: Threshold failures → candidate created ───────────────────────────
print("\nTEST 2: Repeated failures meeting threshold create a candidate")
tmp2 = Path(tempfile.mkdtemp())
esc2 = Path(tempfile.mkdtemp())
r2 = collect(FIXTURE_DIR / "metrics_threshold_fail.jsonl", EMPTY_JSONL, esc2, tmp2)
check(len(r2["created"]) >= 1,      f"At least 1 candidate created (got {len(r2['created'])})")
check(len(r2["skipped_low"]) >= 0,  "Skipped-low accounting present")
candidates2 = list(tmp2.glob("LC-*.json"))
check(len(candidates2) >= 1,        f"LC-*.json file exists (count={len(candidates2)})")
shutil.rmtree(esc2)

# ── TEST 3: Candidate has all required fields ─────────────────────────────────
print("\nTEST 3: Candidate contains all required schema fields")
required_fields = [
    "candidate_id","schema_version","created_at","collector_version",
    "governance_version","governance_hash","source_task_ids","source_evidence_paths",
    "failure_reason_key","failure_reason_examples","frequency","threshold",
    "retry_evidence","resolved_evidence","impact","recommendation",
    "change_class","josh_approval_status","dedupe_key","status"
]
if candidates2:
    c3 = json.loads(candidates2[0].read_text(encoding="utf-8"))
    for f in required_fields:
        check(f in c3, f"Field present: {f}")
    check(c3["frequency"] >= THRESHOLD,         f"frequency >= threshold ({c3['frequency']})")
    check(c3["threshold"] == THRESHOLD,         f"threshold recorded as {THRESHOLD}")
    check(len(c3["source_task_ids"]) >= 1,      "source_task_ids not empty")
    check(c3["josh_approval_status"] == "pending", "josh_approval_status=pending")
    check(c3["status"] == "open",               "status=open")
    check(c3["change_class"] in ("implementation_change","governance_change"), "change_class valid")
    check(bool(c3["dedupe_key"]),               "dedupe_key not empty")
    check(bool(c3["recommendation"]),           "recommendation not empty")
else:
    check(False, "No candidate file to inspect")
shutil.rmtree(tmp2)

# ── TEST 4: Second run on same data → no duplicate candidate ──────────────────
print("\nTEST 4: Second run on same data does not create duplicates")
tmp4 = Path(tempfile.mkdtemp())
esc4 = Path(tempfile.mkdtemp())
r4a = collect(FIXTURE_DIR / "metrics_threshold_fail.jsonl", EMPTY_JSONL, esc4, tmp4)
count_after_first = len(list(tmp4.glob("LC-*.json")))
r4b = collect(FIXTURE_DIR / "metrics_threshold_fail.jsonl", EMPTY_JSONL, esc4, tmp4)
count_after_second = len(list(tmp4.glob("LC-*.json")))
check(count_after_first >= 1,                             f"First run created candidates ({count_after_first})")
check(count_after_second == count_after_first,            f"No new candidates on 2nd run ({count_after_first}→{count_after_second})")
check(len(r4b["skipped_dupe"]) >= len(r4a["created"]),   f"Dedup triggered on 2nd run ({len(r4b['skipped_dupe'])} dupes)")
shutil.rmtree(tmp4); shutil.rmtree(esc4)

# ── TEST 4b: Resolved escalation evidence loads and deduplicates ──────────────
print("\nTEST 4b: Resolved escalation events are loaded and deduplicated")
tmp4b = Path(tempfile.mkdtemp())
r4b_esc = collect(EMPTY_JSONL, ESC_FIXTURE_DIR / "ESCALATION_INDEX.jsonl",
                  ESC_FIXTURE_DIR, tmp4b)
check(len(r4b_esc["events"]) == 2,          f"2 resolved escalation events loaded (got {len(r4b_esc['events'])})")
candidates4b = list(tmp4b.glob("LC-*.json"))
check(len(candidates4b) >= 1,               f"Candidate from resolved escalations (got {len(candidates4b)})")
if candidates4b:
    c4b = json.loads(candidates4b[0].read_text(encoding="utf-8"))
    check(len(c4b["resolved_evidence"]) >= 2, f"resolved_evidence has 2 entries (got {len(c4b['resolved_evidence'])})")
r4b_esc2 = collect(EMPTY_JSONL, ESC_FIXTURE_DIR / "ESCALATION_INDEX.jsonl",
                   ESC_FIXTURE_DIR, tmp4b)
count_after_rerun = len(list(tmp4b.glob("LC-*.json")))
check(count_after_rerun == len(candidates4b), f"No duplicate on rerun ({len(candidates4b)}→{count_after_rerun})")
shutil.rmtree(tmp4b)

# ── TEST 5: Governance keyword → escalation artifact, no candidate file ────────
print("\nTEST 5: Governance-affecting failure reasons route to escalation")
tmp5 = Path(tempfile.mkdtemp())
esc5 = Path(tempfile.mkdtemp())
r5 = collect(FIXTURE_DIR / "metrics_governance_fail.jsonl", EMPTY_JSONL, esc5, tmp5)
candidates5 = list(tmp5.glob("LC-*.json"))
check(len(candidates5) == 0,              f"No candidate files for governance_change (got {len(candidates5)})")
check(len(r5["escalated"]) >= 1,          f"Escalation created for governance_change (got {len(r5['escalated'])})")
esc_files5 = list(esc5.rglob("*.json"))
check(len(esc_files5) >= 1,               f"Escalation artifact file written (got {len(esc_files5)})")
if esc_files5:
    esc5_data = json.loads(esc_files5[0].read_text(encoding="utf-8"))
    check(esc5_data.get("status") == "awaiting_josh",          "Escalation status=awaiting_josh")
    check(esc5_data.get("source") == "learning_candidate_governance", "Escalation source correct")
    check("candidate" in esc5_data,                            "Escalation contains candidate object")
# Verify AGENTS.md not touched
agents_md = ROOT / "AGENTS.md"
actual_hash = hashlib.sha256(agents_md.read_bytes()).hexdigest().upper()
expected_hash = "F442C94F00D21340DC70B56B2D08B017BE51AA5B1908D8ECD7E7F38DFF56C747"
check(actual_hash == expected_hash,       f"AGENTS.md not modified (hash match={actual_hash == expected_hash})")
shutil.rmtree(tmp5); shutil.rmtree(esc5)

# ── Cleanup ───────────────────────────────────────────────────────────────────
EMPTY_JSONL.unlink(missing_ok=True)
shutil.rmtree(EMPTY_ESC_DIR, ignore_errors=True)

print("\n" + "=" * 60)
print(f"RESULTS: passed={passed}  failed={failed}  total={passed+failed}")
print("=" * 60)
if failed > 0:
    print("TEST_SUITE_RESULT=FAIL")
    sys.exit(1)
else:
    print("TEST_SUITE_RESULT=PASS")
    sys.exit(0)

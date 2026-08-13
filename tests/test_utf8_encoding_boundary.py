"""
test_utf8_encoding_boundary.py — regression test for ticket-1346 encoding fixes.

Verifies that Traditional Chinese (繁體中文) text passes through the Python →
PowerShell subprocess boundary without mojibake, and that "請 Codex planning"
and "請 Codex 規劃" are classified as Complex by rule_based_v2.

Run offline:
    python tests/test_utf8_encoding_boundary.py

Exit 0 on PASS, 1 on any FAIL.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CLASSIFIER = ROOT / "scripts" / "classify_task.ps1"


def _classify(message: str) -> dict:
    """Call classify_task.ps1 via subprocess (mirrors the Python plugin path)."""
    result = subprocess.run(
        [
            "powershell.exe",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(CLASSIFIER),
            "-MessageText",
            message,
            "-AsJson",
        ],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=30,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"classify_task.ps1 exit {result.returncode}: {result.stderr[:300]}"
        )
    raw = (result.stdout or "").strip()
    return json.loads(raw)


CASES = [
    {
        "name": "qing_codex_planning_is_complex",
        "message": "請 Codex planning 這個工單",
        "expected_type": "Complex",
        "expected_complex_hits_contain": ["explicit_plan"],
        "mojibake_absent": ["隢", "銵", "嚗"],
    },
    {
        "name": "qing_codex_guihua_is_complex",
        "message": "請 Codex 規劃 這個工單",
        "expected_type": "Complex",
        "expected_complex_hits_contain": ["explicit_plan"],
        "mojibake_absent": ["隢", "銵", "嚗"],
    },
    {
        "name": "rang_codex_guihua_is_complex",
        "message": "讓 Codex 規劃 這個任務",
        "expected_type": "Complex",
        "expected_complex_hits_contain": ["explicit_plan"],
        "mojibake_absent": ["隢", "銵", "嚗"],
    },
    {
        "name": "ticket_1346_repro_is_complex",
        "message": "請執行 Agent OS工單:請讓codex幫我planning 這個工單",
        "expected_type": "Complex",
        "expected_complex_hits_contain": ["explicit_plan"],
        "mojibake_absent": ["隢", "銵", "嚗"],
    },
    {
        "name": "simple_task_stays_simple",
        "message": "請確認目前的記錄狀態。",
        "expected_type": "Simple",
        "expected_complex_hits_contain": [],
        "mojibake_absent": ["隢", "銵", "嚗"],
    },
    {
        "name": "risky_task_stays_risky",
        "message": "Rotate the API token used by the gateway.",
        "expected_type": "Risky",
        "expected_complex_hits_contain": [],
        "mojibake_absent": [],
    },
]


def main() -> int:
    if not CLASSIFIER.exists():
        print(f"FAIL: classifier not found at {CLASSIFIER}")
        return 1

    failures: list[str] = []

    for case in CASES:
        name = case["name"]
        msg = case["message"]
        try:
            result = _classify(msg)
        except Exception as exc:
            failures.append(f"{name}: subprocess error: {exc}")
            continue

        actual_type = result.get("task_type", "")
        actual_complex_hits = result.get("complex_hits") or []

        # Check task_type
        if actual_type != case["expected_type"]:
            failures.append(
                f"{name}: expected task_type={case['expected_type']}, got={actual_type!r}"
            )

        # Check complex_hits contain expected keys
        for hit in case.get("expected_complex_hits_contain", []):
            if hit not in actual_complex_hits:
                failures.append(
                    f"{name}: complex_hits missing '{hit}'; actual={actual_complex_hits}"
                )

        # Check no mojibake in the JSON output (encoding boundary test)
        raw_output = json.dumps(result)
        for char in case.get("mojibake_absent", []):
            if char in raw_output:
                failures.append(
                    f"{name}: mojibake character {char!r} found in classifier output"
                )

    if failures:
        for f in failures:
            print(f"FAIL: {f}")
        return 1

    print(f"encoding_boundary_test_status=passed")
    print(f"case_count={len(CASES)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

from __future__ import annotations

import hashlib
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "dashboard" / "backend"
sys.path.insert(0, str(BACKEND))
import main  # noqa: E402


def snapshot(paths: list[Path]) -> dict[str, str]:
    result: dict[str, str] = {}
    for base in paths:
        if not base.exists():
            continue
        files = [base] if base.is_file() else base.rglob("*")
        for path in files:
            if path.is_file():
                result[str(path.relative_to(ROOT))] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


protected = [
    ROOT / "data" / "governance",
    ROOT / "data" / "codex_tasks",
    ROOT / "data" / "queue_runs",
    ROOT / "data" / "escalations",
]
before = snapshot(protected)
main.health()
main.runtimes()
main.runtime_events(limit=10)
main.failures(limit=10)
main.governance()
main.status_assistant("runtime status")
after = snapshot(protected)
if before != after:
    changed = sorted(set(before) ^ set(after) | {key for key in before.keys() & after.keys() if before[key] != after[key]})
    raise SystemExit("Dashboard read mutated protected state: " + ", ".join(changed))
print("dashboard_readonly_contract=PASS")

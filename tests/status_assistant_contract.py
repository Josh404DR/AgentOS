from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "dashboard" / "backend"
sys.path.insert(0, str(BACKEND))
import main  # noqa: E402


dispatch_id = "fixture-status-assistant-blocked"
task_dir = ROOT / "data" / "codex_tasks" / dispatch_id
event_path = ROOT / "data" / "observability" / "events" / "assistant-fixture.jsonl"
try:
    (task_dir / "OUTPUTS").mkdir(parents=True, exist_ok=True)
    (task_dir / "TASK.md").write_text(
        "\n".join([
            "# Status assistant fixture", f"dispatch_id: {dispatch_id}", "route_to: Codex",
            "dispatch_status: blocked", "task_status: blocked", "failure_reason: fixture dependency unavailable",
            "governance_version: 1.2.0", "", "## Task", "Verify deterministic status retrieval.",
        ]), encoding="utf-8"
    )
    (task_dir / "OUTPUTS" / "RESULT.md").write_text("status: blocked\n", encoding="utf-8")
    event_path.parent.mkdir(parents=True, exist_ok=True)
    event_path.write_text(json.dumps({
        "event_id": "evt-assistant-fixture", "ts": "2026-07-11T12:00:00+08:00",
        "actor": "queue_runner", "runtime_id": "task-queue-runner", "dispatch_id": dispatch_id,
        "action": "blocked", "result": "error", "exit_code": 1,
        "error_class": "NO_PROGRESS_TIMEOUT", "next_step": "await fixture dependency",
        "output_ref": f"data/codex_tasks/{dispatch_id}/OUTPUTS/RESULT.md",
    }, ensure_ascii=False) + "\n", encoding="utf-8")
    answer = main.status_assistant(dispatch_id)
    text = answer["answer"]
    assert "blocked" in text
    assert "fixture dependency unavailable" in text
    assert "last event:" in text and "await fixture dependency" in text
    paths = {item["path"] for item in answer["citations"]}
    assert any(path and path.endswith("TASK.md") for path in paths)
    assert any(path and path.endswith("RESULT.md") for path in paths)
    assert answer["models_invoked"] is False
    print("status_assistant_contract=PASS")
finally:
    shutil.rmtree(task_dir, ignore_errors=True)
    event_path.unlink(missing_ok=True)

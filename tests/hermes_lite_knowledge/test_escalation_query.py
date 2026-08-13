import json
from pathlib import Path

from tools.hermes_lite_knowledge.escalations import list_escalations, query_escalation_status, same_instant


def write(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value), encoding="utf-8")


def append(path: Path, *values: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(json.dumps(value) for value in values) + "\n", encoding="utf-8")


def test_latest_append_and_stale_resolution(tmp_path: Path) -> None:
    index = tmp_path / "ESCALATION_INDEX.jsonl"
    append(index,
           {"task_id": "stale/id", "status": "old", "created_at": "2026-08-10T11:00:00+08:00"},
           {"task_id": "stale/id", "status": "awaiting_josh", "created_at": "2026-08-10T12:00:00+08:00"})
    resolution = tmp_path / "stale-id" / "RESOLUTION.json"
    write(resolution, {"resolution_type": "josh_decision", "recommended_status": "resolved",
                       "josh_action_required": False})
    result = query_escalation_status("stale/id", tmp_path)
    assert result["status"] == "resolved"
    assert result["index_status"] == "awaiting_josh"
    assert resolution.as_posix() in result["evidence_paths"]
    assert list_escalations(tmp_path, include_resolved=False) == []


def test_timestamp_precision_and_verified_decision(tmp_path: Path) -> None:
    append(tmp_path / "ESCALATION_INDEX.jsonl",
           {"task_id": "precision", "status": "awaiting_josh", "created_at": "2026-08-10T13:00:00+08:00"})
    write(tmp_path / "precision" / "RESOLUTION.json",
          {"resolution_type": "owner_decision", "recommended_status": "resolved"})
    write(tmp_path / "precision" / "DECISION-001.json",
          {"escalation_created_at": "2026-08-10T13:00:00.0000000+08:00"})
    result = query_escalation_status("precision", tmp_path, decision_verifier=lambda record, folder: True)
    assert result["status"] == "resolved"
    assert same_instant("2026-08-10T13:00:00+08:00", "2026-08-10T13:00:00.0000000+08:00")
    assert not same_instant("bad", "bad")


def test_fixture_priority_and_default_filter(tmp_path: Path) -> None:
    append(tmp_path / "ESCALATION_INDEX_CLASSIFICATION.jsonl",
           {"task_id": "index-wins", "is_fixture": False},
           {"task_id": "classified", "is_fixture": True})
    append(tmp_path / "ESCALATION_INDEX.jsonl",
           {"task_id": "index-wins", "is_fixture": True, "environment": "runtime", "status": "awaiting_josh"},
           {"task_id": "classified", "environment": "runtime", "status": "awaiting_josh"},
           {"task_id": "ci-fallback", "environment": "ci", "status": "awaiting_josh"},
           {"task_id": "real", "environment": "runtime", "status": "awaiting_josh"})
    assert [item["task_id"] for item in list_escalations(tmp_path)] == ["real"]
    included = {item["task_id"]: item for item in list_escalations(tmp_path, include_fixtures=True)}
    assert all(included[name]["is_fixture"] for name in ("index-wins", "classified", "ci-fallback"))


def test_malformed_or_unverified_is_unknown(tmp_path: Path) -> None:
    append(tmp_path / "ESCALATION_INDEX.jsonl",
           {"task_id": "malformed", "status": "awaiting_josh"},
           {"task_id": "unsigned", "status": "awaiting_josh", "created_at": "2026-08-10T13:00:00+08:00"})
    path = tmp_path / "malformed" / "RESOLUTION.json"
    path.parent.mkdir()
    path.write_text("{bad", encoding="utf-8")
    write(tmp_path / "unsigned" / "RESOLUTION.json", {"resolution_type": "owner_decision"})
    write(tmp_path / "unsigned" / "DECISION-001.json",
          {"escalation_created_at": "2026-08-10T13:00:00.0000000+08:00"})
    malformed = query_escalation_status("malformed", tmp_path)
    unsigned = query_escalation_status("unsigned", tmp_path, decision_verifier=lambda record, folder: False)
    assert malformed["status"] == unsigned["status"] == "UNKNOWN"
    assert "malformed" in malformed["explanation"]
    assert "signature" in unsigned["explanation"]
    assert malformed["model_calls"] == malformed["token_actual"] == 0

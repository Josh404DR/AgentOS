"""Read-only, deterministic escalation status queries (G2)."""

from __future__ import annotations

import json
import re
from datetime import datetime
from pathlib import Path
from typing import Any, Callable


DecisionVerifier = Callable[[dict[str, Any], Path], bool]


def safe_id_from_task_id(task_id: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.\-]+", "-", task_id)


def _normalize_iso_fraction(value: str) -> str:
    match = re.match(r"^(.*T\d{2}:\d{2}:\d{2})\.(\d+)(.*)$", value)
    if not match:
        return value
    whole, fraction, rest = match.groups()
    return f"{whole}.{(fraction + '000000')[:6]}{rest}"


def same_instant(left: object, right: object) -> bool:
    """Compare ISO timestamps as instants; malformed values never match."""
    if not isinstance(left, str) or not isinstance(right, str) or not left or not right:
        return False
    try:
        return datetime.fromisoformat(_normalize_iso_fraction(left).replace("Z", "+00:00")) == datetime.fromisoformat(
            _normalize_iso_fraction(right).replace("Z", "+00:00")
        )
    except ValueError:
        return False


def _classification(escalations_dir: Path) -> tuple[dict[str, str], dict[str, bool]]:
    environments: dict[str, str] = {}
    fixtures: dict[str, bool] = {}
    path = escalations_dir / "ESCALATION_INDEX_CLASSIFICATION.jsonl"
    if not path.is_file():
        return environments, fixtures
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        try:
            item = json.loads(line)
        except (json.JSONDecodeError, TypeError):
            continue
        task_id = item.get("task_id")
        if not task_id:
            continue
        if item.get("environment") in {"ci", "runtime"}:
            environments[str(task_id)] = item["environment"]
        if isinstance(item.get("is_fixture"), bool):
            fixtures[str(task_id)] = item["is_fixture"]
    return environments, fixtures


def _default_verifier(escalations_dir: Path) -> tuple[DecisionVerifier | None, str | None]:
    """Reuse the dashboard verifier without starting AUTH or creating credentials."""
    try:
        from dashboard.backend.dashboard_security import DashboardSecurity

        root = escalations_dir.resolve().parent.parent
        security = DashboardSecurity(root)
        if not security.decision_receipt_key_path.is_file():
            return None, "decision receipt signing key is unavailable; signature cannot be verified"
        return security.verify_escalation_decision_record, None
    except (ImportError, OSError) as exc:
        return None, f"AUTH verifier unavailable: {exc}"


def _unknown(entry: dict[str, Any], environment: str, is_fixture: bool, reason: str, paths: list[str]) -> dict[str, Any]:
    return _result(entry, environment, is_fixture, "UNKNOWN", None, reason, paths)


def _result(
    entry: dict[str, Any], environment: str, is_fixture: bool, status: str,
    resolution: dict[str, Any] | None, explanation: str, evidence_paths: list[str],
) -> dict[str, Any]:
    return {
        "task_id": str(entry.get("task_id", "")),
        "environment": environment,
        "is_fixture": is_fixture,
        "status": status,
        "index_status": entry.get("status", ""),
        "created_at": entry.get("created_at", ""),
        "source": entry.get("source", ""),
        "reason": entry.get("reason", ""),
        "artifact_path": entry.get("artifact_path", ""),
        "has_resolution": resolution is not None,
        "resolution": resolution,
        "josh_action_required": resolution.get("josh_action_required", False) if resolution else status == "awaiting_josh",
        "explanation": explanation,
        "evidence_paths": evidence_paths,
        "model_calls": 0,
        "token_actual": 0,
    }


def _resolve_entry(
    entry: dict[str, Any], escalations_dir: Path, environment: str, is_fixture: bool,
    verifier: DecisionVerifier | None, verifier_error: str | None,
) -> dict[str, Any]:
    task_id = str(entry["task_id"])
    folder = escalations_dir / safe_id_from_task_id(task_id)
    resolution_path = folder / "RESOLUTION.json"
    index_path = escalations_dir / "ESCALATION_INDEX.jsonl"
    paths = [index_path.as_posix()]
    if not resolution_path.is_file():
        return _result(entry, environment, is_fixture, "awaiting_josh", None,
                       "latest append record has no RESOLUTION.json", paths)
    paths.append(resolution_path.as_posix())
    try:
        resolution = json.loads(resolution_path.read_text(encoding="utf-8"))
        if not isinstance(resolution, dict):
            raise ValueError("JSON root is not an object")
    except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as exc:
        return _unknown(entry, environment, is_fixture, f"malformed RESOLUTION.json: {exc}", paths)

    if resolution.get("resolution_type") in {"owner_decision", "verified_owner_decision"}:
        if verifier is None:
            return _unknown(entry, environment, is_fixture, verifier_error or "signature verifier unavailable", paths)
        matched = False
        malformed = False
        for decision_path in sorted(folder.glob("DECISION-*.json"), reverse=True):
            paths.append(decision_path.as_posix())
            try:
                candidate = json.loads(decision_path.read_text(encoding="utf-8"))
                if not isinstance(candidate, dict):
                    raise ValueError("JSON root is not an object")
            except (OSError, UnicodeError, json.JSONDecodeError, ValueError):
                malformed = True
                continue
            if not same_instant(candidate.get("escalation_created_at"), entry.get("created_at")):
                continue
            matched = True
            try:
                verified = verifier(candidate, folder)
            except Exception as exc:  # AUTH errors must fail closed, never resolve.
                return _unknown(entry, environment, is_fixture, f"signature verification unavailable: {exc}", paths)
            if verified:
                verified_resolution = dict(resolution)
                verified_resolution["decision_path"] = decision_path.as_posix()
                return _result(entry, environment, is_fixture,
                               verified_resolution.get("recommended_status", "resolved"),
                               verified_resolution, "resolved by timestamp-bound, AUTH-verified owner decision", paths)
        detail = "matching decision signature could not be verified" if matched else "no decision is bound to the latest escalation instant"
        if malformed:
            detail += "; one or more DECISION files are malformed"
        return _unknown(entry, environment, is_fixture, detail, paths)

    status = str(resolution.get("recommended_status") or "resolved_by_evidence")
    return _result(entry, environment, is_fixture, status, resolution,
                   "RESOLUTION.json overrides the stale index status", paths)


def list_escalations(
    escalations_dir: str | Path, *, include_fixtures: bool = False,
    include_resolved: bool = True, decision_verifier: DecisionVerifier | None = None,
) -> list[dict[str, Any]]:
    """Return latest append records, enriched from authoritative artifacts."""
    root = Path(escalations_dir)
    index_path = root / "ESCALATION_INDEX.jsonl"
    if not index_path.is_file():
        return []
    environments, fixtures = _classification(root)
    verifier_error = None
    if decision_verifier is None:
        decision_verifier, verifier_error = _default_verifier(root)
    latest: list[dict[str, Any]] = []
    seen: set[str] = set()
    for line in reversed(index_path.read_text(encoding="utf-8", errors="replace").splitlines()):
        try:
            entry = json.loads(line)
        except (json.JSONDecodeError, TypeError):
            continue
        task_id = entry.get("task_id") if isinstance(entry, dict) else None
        if not task_id or str(task_id) in seen:
            continue
        task_id = str(task_id)
        seen.add(task_id)
        environment = entry.get("environment")
        if environment not in {"ci", "runtime"}:
            environment = environments.get(task_id, "runtime")
        # Required priority: latest index boolean > latest classification boolean > CI fallback.
        is_fixture = entry.get("is_fixture")
        if not isinstance(is_fixture, bool):
            is_fixture = fixtures.get(task_id, environment == "ci")
        if is_fixture and not include_fixtures:
            continue
        current = _resolve_entry(entry, root, environment, is_fixture, decision_verifier, verifier_error)
        if not include_resolved and current["status"] not in {"awaiting_josh", "UNKNOWN"}:
            continue
        latest.append(current)
    latest.sort(key=lambda item: item["created_at"], reverse=True)
    return latest


def query_escalation_status(
    task_id: str, escalations_dir: str | Path, *, decision_verifier: DecisionVerifier | None = None,
) -> dict[str, Any]:
    for item in list_escalations(escalations_dir, include_fixtures=True,
                                 decision_verifier=decision_verifier):
        if item["task_id"] == task_id:
            return item
    return {"task_id": task_id, "status": "UNKNOWN", "index_status": "",
            "is_fixture": False, "explanation": "task_id not found in escalation index",
            "evidence_paths": [], "model_calls": 0, "token_actual": 0}

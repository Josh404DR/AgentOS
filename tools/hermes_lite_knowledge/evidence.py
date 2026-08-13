"""Deterministic same-task evidence precedence for Hermes Lite."""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Mapping


OUTPUT_NAMES = ("RESULT.md", "TEST_RESULT.md", "VERIFY_BUNDLE.md", "VERIFY_RESULT.md", "DELIVERY.md")
_FIELD = re.compile(r"^([A-Za-z][A-Za-z0-9_-]*)\s*:\s*(.*?)\s*$")
_TRUE = {"true", "yes", "1"}
_FALSE = {"false", "no", "0"}
_PENDING = ("pending", "awaiting", "not_started", "not executed", "尚未")


@dataclass(frozen=True)
class EvidenceResolution:
    final_status: str
    source_of_truth: str
    external_label: str
    explanation: str
    evidence_paths: tuple[str, ...]
    field_sources: Mapping[str, str]
    governance_status: str = "aligned"


class _ParseError(ValueError):
    pass


def _fields(path: Path) -> dict[str, str]:
    try:
        text = path.read_text(encoding="utf-8-sig")
    except (OSError, UnicodeError) as exc:
        raise _ParseError(f"cannot read {path.name}: {exc}") from exc
    fields: dict[str, str] = {}
    for line in text.splitlines():
        match = _FIELD.match(line.strip())
        if match:
            key = match.group(1).casefold()
            value = match.group(2).strip().strip("`\"'")
            if key in fields and fields[key] != value:
                raise _ParseError(f"conflicting {key} fields in {path.name}")
            fields[key] = value
    return fields


def _boolean(value: str | None, field: str) -> bool:
    normalized = (value or "").casefold()
    if normalized in _TRUE:
        return True
    if normalized in _FALSE:
        return False
    raise _ParseError(f"missing or invalid {field}")


def _verified_time_is_before_result(value: str, result_mtime: float) -> bool:
    """Compare at the precision actually supplied; never invent a time of day."""
    cleaned = value.strip()
    # G1 fixes this artifact convention to Asia/Taipei (UTC+08, no DST).
    # A fixed offset keeps the filesystem-only resolver independent of tzdata.
    tz = timezone(timedelta(hours=8))
    date_match = re.fullmatch(r"(\d{4}-\d{2}-\d{2})(?:\s+Asia/Taipei)?", cleaned)
    if date_match:
        verified_date = datetime.strptime(date_match.group(1), "%Y-%m-%d").date()
        return verified_date < datetime.fromtimestamp(result_mtime, tz).date()
    try:
        parsed = datetime.fromisoformat(cleaned.replace("Z", "+00:00"))
    except ValueError as exc:
        raise _ParseError("invalid VERIFY_RESULT.verified_at") from exc
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=tz)
    return parsed.timestamp() < result_mtime


def _review(paths: list[str], sources: dict[str, str], reason: str) -> EvidenceResolution:
    return EvidenceResolution(
        final_status="review_required", source_of_truth="none", external_label="unknown",
        explanation=f"證據解析或時間順序異常，已 fail closed：{reason}",
        evidence_paths=tuple(paths), field_sources=sources,
        governance_status="review_required",
    )


def resolve_verification_status(task_folder: str | Path) -> EvidenceResolution:
    """Resolve G1 precedence within one task folder without model calls."""
    folder = Path(task_folder)
    outputs = folder / "OUTPUTS"
    present = {name: outputs / name for name in OUTPUT_NAMES if (outputs / name).is_file()}
    paths = [path.as_posix() for path in present.values()]
    sources: dict[str, str] = {}
    try:
        parsed = {name: _fields(path) for name, path in present.items()}
        result = parsed.get("RESULT.md")
        test = parsed.get("TEST_RESULT.md")
        verify = parsed.get("VERIFY_RESULT.md")

        if verify is not None:
            verdict = verify.get("verify_verdict", "").upper()
            sources["verify_verdict"] = present["VERIFY_RESULT.md"].as_posix()
            verified = _boolean(verify.get("verified"), "VERIFY_RESULT.verified")
            sources["verified"] = present["VERIFY_RESULT.md"].as_posix()
            if verdict == "PASS" and verified:
                status, label = "verified_pass", "verified_by_codex"
            elif verdict == "FAIL" and not verified:
                status, label = "verified_fail", "blocked"
            elif verdict == "NEEDS_HUMAN_DECISION" and not verified:
                status, label = "escalated_pending_josh", "blocked"
            else:
                raise _ParseError("VERIFY_RESULT verdict and verified field conflict")
            if result is not None:
                result_verified = _boolean(result.get("verified"), "RESULT.verified")
                sources["result.verified"] = present["RESULT.md"].as_posix()
                verified_at = verify.get("verified_at")
                if not verified_at:
                    raise _ParseError("missing VERIFY_RESULT.verified_at")
                sources["verified_at"] = present["VERIFY_RESULT.md"].as_posix()
                if _verified_time_is_before_result(verified_at, present["RESULT.md"].stat().st_mtime):
                    return _review(paths, sources, "VERIFY_RESULT.verified_at earlier than RESULT.md mtime")
                context = (
                    f"早期 RESULT.md 的 verified={str(result_verified).lower()}；後續獨立 "
                    f"VERIFY_RESULT.md 判定 {verdict}，依 G1 由後者覆蓋最終驗證狀態。"
                )
            else:
                context = f"獨立 VERIFY_RESULT.md 判定 {verdict}，為最高優先序結論。"
            return EvidenceResolution(status, "OUTPUTS/VERIFY_RESULT.md", label, context,
                                      tuple(paths), sources)

        if test is not None:
            independent = test.get("independent_verify_status", "")
            sources["independent_verify_status"] = present["TEST_RESULT.md"].as_posix()
            if any(word in independent.casefold() for word in _PENDING):
                self_check = test.get("builder_self_check", "").upper()
                if self_check == "PASS":
                    status, label = "implemented_tests_pass_awaiting_independent_verify", "locally_verified"
                else:
                    status, label = "implemented_pending_verify", "artifact_created"
                return EvidenceResolution(status, "OUTPUTS/TEST_RESULT.md", label,
                    "TEST_RESULT.md 僅為 Builder/self-check 證據；沒有 VERIFY_RESULT.md，不能升格為獨立 verified。",
                    tuple(paths), sources)
            raise _ParseError("unrecognized TEST_RESULT.independent_verify_status without VERIFY_RESULT")

        if result is not None:
            reported = _boolean(result.get("verified"), "RESULT.verified")
            sources["verified"] = present["RESULT.md"].as_posix()
            status = "builder_reported_verified" if reported else "implemented_pending_verify"
            return EvidenceResolution(status, "OUTPUTS/RESULT.md (verified field)", "claimed_by_agent",
                "只有 RESULT.md 的 Builder 自報欄位；缺少獨立 VERIFY_RESULT.md 佐證。",
                tuple(paths), sources)

        return EvidenceResolution("unknown_no_result_artifact", "none", "unknown",
            "沒有 RESULT.md、TEST_RESULT.md 或 VERIFY_RESULT.md；VERIFY_BUNDLE/DELIVERY 不構成驗證結論。",
            tuple(paths), sources)
    except (_ParseError, OSError) as exc:
        return _review(paths, sources, str(exc))

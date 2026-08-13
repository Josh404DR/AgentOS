"""Hermes Lite deterministic filesystem index.

本索引管線直接掃描檔案系統路徑，不依賴、不查詢、不解析 git 追蹤狀態或 .gitignore。
判斷是否索引某檔案只看來源路徑與明確排除規則，與檔案是否被 git 追蹤或 commit 無關。
這是 2026-08-10 修正的已知風險（G0）；變更前必須先讀
docs/plans/2026-08-10-hermes-lite-phase0-index-pipeline-design.md。

This module never creates embeddings and never calls an LLM.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import tempfile
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

SCHEMA_VERSION = 1
DEFAULT_STATE = Path("data/hermes_lite/index_state.json")
TASK_FILES = {
    "TASK.md": "task_request",
    "PROMPT_FOR_CODEX.md": "task_prompt",
    "STATUS.md": "task_status",
}
OUTPUT_FILES = {
    "RESULT.md": "task_result",
    "TEST_RESULT.md": "task_test_result",
    "VERIFY_BUNDLE.md": "task_verify_bundle",
    "VERIFY_RESULT.md": "task_verify_result",
    "DELIVERY.md": "task_delivery",
}
SOURCE_TYPES = (
    "task_request", "task_prompt", "task_status", "task_result",
    "task_test_result", "task_verify_bundle", "task_verify_result",
    "task_delivery", "escalation_event", "escalation_resolution",
    "escalation_decision", "learning_candidate", "metric_record",
    "documentation", "current_state", "governance", "project_task_board",
)


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def _relative(root: Path, path: Path) -> str:
    return path.relative_to(root).as_posix()


def _source_type(relative: str) -> str | None:
    parts = relative.split("/")
    name = parts[-1]
    lower = relative.lower()
    if lower.startswith(("archive/", "data/dashboard_auth/", "logs/")):
        return None
    if name == ".env" or name.lower().endswith(".env") or name.startswith("AgentOS_export") and name.endswith(".zip"):
        return None
    if lower.endswith("/outputs/codex_console.log"):
        return None
    if len(parts) >= 3 and parts[:2] == ["data", "codex_tasks"]:
        if len(parts) == 4 and name in TASK_FILES:
            return TASK_FILES[name]
        if len(parts) == 5 and parts[-2] == "OUTPUTS" and name in OUTPUT_FILES:
            return OUTPUT_FILES[name]
        return None
    if len(parts) >= 3 and parts[:2] == ["data", "escalations"] and name.endswith(".json"):
        if name == "ESCALATION_INDEX.jsonl":
            return None
        if name == "RESOLUTION.json" or name.startswith("RESOLUTION-"):
            return "escalation_resolution"
        if name.startswith("DECISION-"):
            return "escalation_decision"
        return "escalation_event"
    if len(parts) == 3 and parts[:2] == ["data", "learning_candidates"] and name.startswith("LC-") and name.endswith(".json"):
        return "learning_candidate"
    if relative == "data/metrics/METRICS_LOG.jsonl":
        return "metric_record"
    if relative == "current_state.md":
        return "current_state"
    if relative == "AGENTS.md":
        return "governance"
    if lower.startswith("docs/") and name.startswith("PROJECT_TASK_BOARD_") and name.endswith(".md"):
        return "project_task_board"
    if lower.startswith("docs/") and name.endswith(".md"):
        return "documentation"
    return None


def discover(root: Path) -> dict[str, tuple[Path, str]]:
    """Return eligible files using filesystem traversal only."""
    found: dict[str, tuple[Path, str]] = {}
    for current, dirs, files in os.walk(root):
        rel_dir = Path(current).relative_to(root).as_posix().lower()
        dirs[:] = [d for d in dirs if not (
            d == ".git" or
            (rel_dir == "." and d in {"archive", "logs"}) or
            (rel_dir == "data" and d == "dashboard_auth")
        )]
        for filename in files:
            path = Path(current) / filename
            relative = _relative(root, path)
            kind = _source_type(relative)
            if kind:
                found[relative] = (path, kind)
    return found


def topic_alias_candidates(relative: str, text: str) -> list[str]:
    """Generate deterministic aliases from path, headings, IDs, and tags."""
    values: list[str] = []
    values.extend(Path(relative).stem.replace("_", " ").replace("-", " ").split())
    for line in text.splitlines()[:100]:
        match = re.match(r"^#{1,3}\s+(.+)$", line.strip())
        if match:
            values.append(match.group(1).strip())
        match = re.match(r"^(?:dispatch_id|task_id|topic|title|tags?)\s*:\s*(.+)$", line.strip(), re.I)
        if match:
            values.extend(re.split(r"[,|]", match.group(1)))
    aliases: list[str] = []
    seen: set[str] = set()
    for value in values:
        value = re.sub(r"\s+", " ", value.strip()).casefold()
        if 2 <= len(value) <= 120 and value not in seen:
            aliases.append(value)
            seen.add(value)
    return aliases[:32]


@dataclass
class IndexRun:
    mode: str
    added: list[str] = field(default_factory=list)
    changed: list[str] = field(default_factory=list)
    deleted: list[str] = field(default_factory=list)
    skipped: list[dict[str, Any]] = field(default_factory=list)
    warnings: list[dict[str, Any]] = field(default_factory=list)
    unchanged: int = 0
    rebuilt_reason: str | None = None
    model_calls: int = 0
    token_actual: int = 0

    def as_dict(self) -> dict[str, Any]:
        return self.__dict__.copy()


class Indexer:
    def __init__(self, root: Path, state_path: Path | None = None, warning_after: int = 3):
        self.root = root.resolve()
        selected = state_path or DEFAULT_STATE
        self.state_path = selected if selected.is_absolute() else self.root / selected
        self.warning_after = warning_after

    def _empty(self) -> dict[str, Any]:
        return {"schema_version": SCHEMA_VERSION, "generated_at": None, "entries": {}, "index_skips": {}}

    def _load(self) -> tuple[dict[str, Any], str | None]:
        if not self.state_path.exists():
            return self._empty(), "state_missing"
        try:
            state = json.loads(self.state_path.read_text(encoding="utf-8"))
            if state.get("schema_version") != SCHEMA_VERSION or not isinstance(state.get("entries"), dict) or not isinstance(state.get("index_skips"), dict):
                raise ValueError("incompatible state schema")
            return state, None
        except (OSError, UnicodeError, json.JSONDecodeError, ValueError):
            return self._empty(), "state_corrupt_or_incompatible"

    def _read(self, path: Path, kind: str) -> tuple[str, list[Any] | None]:
        # utf-8-sig accepts both ordinary UTF-8 and Windows-authored JSON with a BOM.
        text = path.read_text(encoding="utf-8-sig")
        if path.suffix.lower() == ".json":
            return text, [json.loads(text)]
        if path.suffix.lower() == ".jsonl":
            rows = []
            for number, line in enumerate(text.splitlines(), 1):
                if line.strip():
                    try:
                        rows.append(json.loads(line))
                    except json.JSONDecodeError as exc:
                        raise ValueError(f"JSONL line {number}: {exc.msg}") from exc
            return text, rows
        return text, None

    def run(self, full: bool = False) -> IndexRun:
        state, rebuild_reason = self._load()
        full = full or rebuild_reason is not None
        run = IndexRun(mode="full" if full else "incremental", rebuilt_reason=rebuild_reason)
        discovered = discover(self.root)
        previous = state["entries"]
        new_entries = {} if full else dict(previous)
        skips = dict(state["index_skips"])
        for relative in sorted(set(previous) - set(discovered)):
            new_entries.pop(relative, None)
            skips.pop(relative, None)
            run.deleted.append(relative)
        for relative, (path, kind) in sorted(discovered.items()):
            try:
                stat = path.stat()
            except OSError as exc:
                self._skip(run, skips, relative, None, exc)
                continue
            mtime_ns = stat.st_mtime_ns
            old = previous.get(relative)
            prior_skip = skips.get(relative)
            needs_read = full or old is None or old.get("mtime_ns") != mtime_ns or prior_skip is not None
            if not needs_read:
                run.unchanged += 1
                continue
            try:
                text, rows = self._read(path, kind)
            except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as exc:
                self._skip(run, skips, relative, mtime_ns, exc)
                continue
            indexed_at = _utc_now()
            record = {
                "path": relative, "source_type": kind, "mtime_ns": mtime_ns,
                "mtime": datetime.fromtimestamp(stat.st_mtime, timezone.utc).isoformat().replace("+00:00", "Z"),
                "indexed_at": indexed_at, "content_hash": hashlib.sha256(text.encode("utf-8")).hexdigest(),
                "content": text, "records": rows, "topic_alias_candidates": topic_alias_candidates(relative, text),
                "is_resolution": kind == "escalation_resolution", "is_decision": kind == "escalation_decision",
            }
            new_entries[relative] = record
            skips.pop(relative, None)
            (run.added if old is None else run.changed).append(relative)
        state = {"schema_version": SCHEMA_VERSION, "generated_at": _utc_now(), "entries": new_entries, "index_skips": skips}
        self._write_atomic(state)
        return run

    def _skip(self, run: IndexRun, skips: dict[str, Any], relative: str, mtime_ns: int | None, exc: Exception) -> None:
        old = skips.get(relative, {})
        same_version = old.get("mtime_ns") == mtime_ns
        failures = int(old.get("consecutive_failures", 0)) + 1 if same_version else 1
        receipt = {"event": "index_skip", "path": relative, "mtime_ns": mtime_ns, "failed_at": _utc_now(), "error": f"{type(exc).__name__}: {exc}", "consecutive_failures": failures, "warning": failures > self.warning_after}
        skips[relative] = receipt
        run.skipped.append(receipt)
        if receipt["warning"]:
            run.warnings.append(receipt)

    def _write_atomic(self, state: dict[str, Any]) -> None:
        self.state_path.parent.mkdir(parents=True, exist_ok=True)
        handle, temp_name = tempfile.mkstemp(prefix=self.state_path.name, suffix=".tmp", dir=self.state_path.parent)
        try:
            with os.fdopen(handle, "w", encoding="utf-8", newline="\n") as stream:
                json.dump(state, stream, ensure_ascii=False, indent=2, sort_keys=True)
                stream.write("\n")
            os.replace(temp_name, self.state_path)
        finally:
            if os.path.exists(temp_name):
                os.unlink(temp_name)


def query_index(state_path: Path, query: str) -> list[dict[str, Any]]:
    state = json.loads(state_path.read_text(encoding="utf-8"))
    needle = query.casefold()
    hits = []
    for entry in state.get("entries", {}).values():
        haystack = entry.get("content", "").casefold()
        aliases = entry.get("topic_alias_candidates", [])
        if needle in haystack or needle in aliases:
            hits.append({"path": entry["path"], "source_type": entry["source_type"], "indexed_at": entry["indexed_at"]})
    return hits

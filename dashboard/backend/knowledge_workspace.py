from __future__ import annotations

import base64
import hashlib
import json
import os
import re
import sqlite3
import threading
import uuid
from contextlib import closing
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def _field(text: str, key: str) -> str:
    match = re.search(rf"(?mi)^\s*(?:[-*]\s*)?{re.escape(key)}\s*[:=]\s*(.*?)\s*$", text)
    return match.group(1).strip(" `\"'") if match else ""


def _section(text: str, *names: str) -> str:
    for name in names:
        match = re.search(
            rf"(?mis)^##+\s*{re.escape(name)}\s*$\s*(.*?)(?=^##+\s|\Z)", text
        )
        if match:
            return match.group(1).strip()
    return ""


def _title(text: str, fallback: str) -> str:
    match = re.search(r"(?m)^#\s+(.+?)\s*$", text)
    return match.group(1).strip() if match else fallback


def _opaque_ref(relative_path: str) -> str:
    return "art_" + hashlib.sha256(relative_path.encode("utf-8")).hexdigest()[:24]


def _cursor_encode(offset: int) -> str:
    return base64.urlsafe_b64encode(f"v1:{offset}".encode()).decode().rstrip("=")


def _cursor_decode(value: str | None) -> int:
    if not value:
        return 0
    try:
        raw = base64.urlsafe_b64decode(value + "=" * (-len(value) % 4)).decode()
        prefix, offset = raw.split(":", 1)
        if prefix != "v1" or int(offset) < 0:
            raise ValueError
        return int(offset)
    except (ValueError, UnicodeError):
        raise ValueError("invalid cursor") from None


def _search_terms(query: str) -> str:
    # FTS5 trigram handles contiguous Traditional Chinese without relying on spaces.
    cleaned = re.sub(r"[^\w\u3400-\u9fff]+", " ", query, flags=re.UNICODE).strip()
    terms: list[str] = []
    for token in cleaned.split():
        if re.search(r"[\u3400-\u9fff]", token) and len(token) >= 3:
            terms.extend(token[index:index + 3] for index in range(len(token) - 2))
        elif token:
            terms.append(token)
    return " OR ".join('"' + term.replace('"', '""') + '"' for term in terms)


class KnowledgeIndex:
    """Rebuildable projection over canonical AgentOS artifacts.

    API reads query SQLite only. Filesystem reconciliation is explicit or periodic,
    so a browser refresh cannot trigger a full scan of the task tree.
    """

    SCHEMA_VERSION = "2"
    TASK_ARTIFACTS = (
        ("TASK.md", "task"),
        ("STATUS.md", "status"),
        ("OUTPUTS/RESULT.md", "result"),
        ("OUTPUTS/WORKER_STATUS.md", "worker_status"),
        ("OUTPUTS/REVIEW_FLOW_STATUS.md", "review_flow"),
        ("OUTPUTS/CLAUDE_REVIEW.md", "claude_review"),
        ("OUTPUTS/VERIFY_RESULT.md", "verify_result"),
    )

    def __init__(self, root: Path, db_path: Path | None = None) -> None:
        self.root = root.resolve()
        self.db_path = db_path or self.root / "data" / "dashboard_index" / "knowledge_workspace.sqlite3"
        self.tasks_dir = self.root / "data" / "codex_tasks"
        self.knowledge_dir = self.root / "data" / "knowledge_pool"
        self._lock = threading.RLock()
        self.scan_count = 0

    def connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.db_path, timeout=10)
        connection.row_factory = sqlite3.Row
        return connection

    def ensure(self) -> None:
        rebuild_required = not self.db_path.exists()
        if not rebuild_required:
            try:
                with closing(self.connect()) as connection:
                    row = connection.execute("SELECT value FROM meta WHERE key='schema_version'").fetchone()
                rebuild_required = not row or row[0] != self.SCHEMA_VERSION
            except sqlite3.DatabaseError:
                rebuild_required = True
        if rebuild_required:
            self.rebuild()

    def rebuild(self) -> dict[str, Any]:
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        temporary = self.db_path.with_name(f".{self.db_path.name}.{uuid.uuid4().hex}.tmp")
        with self._lock:
            self.scan_count += 1
            connection = sqlite3.connect(temporary)
            try:
                self._create_schema(connection)
                artifact_ids: dict[str, str] = {}
                tasks = self._scan_tasks(connection, artifact_ids)
                nodes = self._scan_nodes(connection, artifact_ids, tasks)
                connection.execute(
                    "INSERT INTO meta(key,value) VALUES('projection_as_of',?)", (_utc_now(),)
                )
                connection.execute(
                    "INSERT INTO meta(key,value) VALUES('schema_version',?)", (self.SCHEMA_VERSION,)
                )
                connection.execute(
                    "INSERT INTO meta(key,value) VALUES('source_signature',?)",
                    (self._source_signature(),),
                )
                connection.commit()
            finally:
                connection.close()
            os.replace(temporary, self.db_path)
        return {"tasks": len(tasks), "nodes": nodes, "projection_as_of": self.projection_as_of()}

    def reconcile(self) -> dict[str, Any]:
        # Stat-only incremental check skips unchanged artifacts. If anything
        # changed, an atomic deterministic rebuild is the reconciliation safety
        # net; the old projection remains readable until replacement completes.
        self.ensure()
        signature = self._source_signature()
        with closing(self.connect()) as connection:
            row = connection.execute("SELECT value FROM meta WHERE key='source_signature'").fetchone()
        if row and row[0] == signature:
            return {"updated": False, "projection_as_of": self.projection_as_of()}
        result = self.rebuild()
        result["updated"] = True
        return result

    def _source_signature(self) -> str:
        digest = hashlib.sha256()
        # Only canonical inputs consumed by _scan_tasks/_scan_nodes belong in
        # the signature.  The previous recursive rglob walked images, logs and
        # arbitrary nested Markdown under every historical task even though
        # none of those files could affect the projection.  On the real tree
        # that made disaster rebuilds exceed the verifier's bounded timeout.
        for path in self._iter_source_paths():
            try:
                stat = path.stat()
                relative = path.relative_to(self.root).as_posix()
            except (OSError, ValueError):
                # A concurrent rename must force the next reconciliation; it
                # must never be silently treated as an unchanged projection.
                digest.update(f"missing:{path}\n".encode("utf-8", errors="replace"))
                continue
            digest.update(relative.encode("utf-8"))
            digest.update(f":{stat.st_mtime_ns}:{stat.st_size}\n".encode())
        return digest.hexdigest().upper()

    def _iter_source_paths(self):
        paths: set[Path] = set()
        if self.tasks_dir.exists():
            for folder in self.tasks_dir.iterdir():
                if not folder.is_dir():
                    continue
                for relative, _kind in self.TASK_ARTIFACTS:
                    candidate = folder / Path(relative)
                    if candidate.is_file():
                        paths.add(candidate)
        if self.knowledge_dir.exists():
            paths.update(path for path in self.knowledge_dir.glob("*.md") if path.is_file())
        intake_dir = self.root / "data" / "url_intake"
        if intake_dir.exists():
            paths.update(path for path in intake_dir.glob("*/fetch/source.json") if path.is_file())
        yield from sorted(paths, key=lambda item: item.as_posix())

    @staticmethod
    def _create_schema(connection: sqlite3.Connection) -> None:
        connection.executescript(
            """
            PRAGMA journal_mode=DELETE;
            CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
            CREATE TABLE artifacts(
              ref TEXT PRIMARY KEY, relative_path TEXT UNIQUE NOT NULL, kind TEXT NOT NULL,
              dispatch_id TEXT NOT NULL, sha256 TEXT NOT NULL, mtime_ns INTEGER NOT NULL,
              size INTEGER NOT NULL
            );
            CREATE TABLE tasks(
              folder_id TEXT PRIMARY KEY, dispatch_id TEXT NOT NULL,
              title TEXT NOT NULL, normalized_status TEXT NOT NULL,
              mtime REAL NOT NULL, record_json TEXT NOT NULL
            );
            CREATE INDEX tasks_dispatch ON tasks(dispatch_id);
            CREATE TABLE nodes(
              dispatch_id TEXT PRIMARY KEY, title TEXT NOT NULL, summary TEXT NOT NULL,
              source_url TEXT NOT NULL, agentos_value TEXT NOT NULL,
              system_relationship TEXT NOT NULL, similarity_score TEXT NOT NULL,
              local_sync_status TEXT NOT NULL, notebooklm_sync_status TEXT NOT NULL,
              node_ref TEXT NOT NULL, task_folder_id TEXT NOT NULL,
              search_text TEXT NOT NULL, record_json TEXT NOT NULL
            );
            CREATE VIRTUAL TABLE node_search USING fts5(
              dispatch_id UNINDEXED, search_text, tokenize='trigram'
            );
            """
        )

    def _add_artifact(
        self, connection: sqlite3.Connection, path: Path, kind: str, dispatch_id: str
    ) -> str:
        if path.is_symlink() or (hasattr(os.path, "isjunction") and os.path.isjunction(path)):
            raise RuntimeError(f"linked artifact rejected: {path}")
        resolved = path.resolve(strict=True)
        try:
            relative = resolved.relative_to(self.root).as_posix()
        except ValueError as exc:
            raise RuntimeError(f"artifact escaped AgentOS root: {path}") from exc
        ref = _opaque_ref(relative)
        stat = resolved.stat()
        connection.execute(
            "INSERT OR REPLACE INTO artifacts VALUES(?,?,?,?,?,?,?)",
            (ref, relative, kind, dispatch_id, _sha256(resolved), stat.st_mtime_ns, stat.st_size),
        )
        return ref

    def _scan_tasks(
        self, connection: sqlite3.Connection, artifact_ids: dict[str, str]
    ) -> dict[str, dict[str, Any]]:
        tasks: dict[str, dict[str, Any]] = {}
        if not self.tasks_dir.exists():
            return tasks
        for folder in sorted(self.tasks_dir.iterdir()):
            if not folder.is_dir():
                continue
            task_path = folder / "TASK.md"
            if not task_path.is_file():
                continue
            task_text = task_path.read_text(encoding="utf-8", errors="replace")
            dispatch_id = _field(task_text, "dispatch_id") or folder.name
            texts: dict[str, str] = {}
            refs: list[dict[str, str]] = []
            candidates = [(folder / Path(relative), kind) for relative, kind in self.TASK_ARTIFACTS]
            mtimes = [folder.stat().st_mtime]
            for path, kind in candidates:
                if path.is_file():
                    texts[kind] = path.read_text(encoding="utf-8", errors="replace")
                    ref = self._add_artifact(connection, path, kind, dispatch_id)
                    artifact_ids[f"{dispatch_id}:{kind}"] = ref
                    refs.append({"kind": kind, "ref": ref})
                    mtimes.append(path.stat().st_mtime)
            combined = "\n".join(texts.values())
            status_value = next(
                (_field(combined, key) for key in (
                    "task_status", "pipeline_status", "dispatch_status", "codex_execution_status", "status"
                ) if _field(combined, key)),
                "unknown",
            )
            lowered = combined.lower()
            if any(marker in lowered for marker in ("task_status=blocked", "task_status: blocked", "review_status: fail")):
                normalized = "blocked"
            elif (folder / "OUTPUTS" / "RESULT.md").is_file():
                normalized = "completed"
            elif _field(task_text, "task_status").lower() == "processing":
                normalized = "processing"
            else:
                normalized = "ready"
            title = _title(task_text, folder.name)
            purpose = _section(task_text, "Objective", "Purpose") or title
            record = {
                "id": folder.name,
                "folder_id": folder.name,
                "dispatch_id": dispatch_id,
                "title": title,
                "purpose": purpose[:1200],
                "status": status_value,
                "normalized_status": normalized,
                "route_to": _field(task_text, "route_to") or _field(task_text, "assigned_to") or "unknown",
                "assigned_to": _field(task_text, "assigned_to"),
                "parent_dispatch_id": _field(task_text, "parent_dispatch_id"),
                "source_dispatch_id": _field(task_text, "source_dispatch_id"),
                "depends_on": _field(task_text, "depends_on"),
                "codex_mode": _field(task_text, "codex_mode"),
                "dispatch_status": _field(task_text, "dispatch_status"),
                "task_status": _field(task_text, "task_status"),
                "governance_version": _field(task_text, "governance_version") or "legacy",
                "governance_hash": _field(task_text, "governance_hash"),
                "workflow_version": _field(task_text, "workflow_version") or "1.1",
                "task_type": _field(task_text, "task_type") or "legacy",
                "risk_hits": _field(task_text, "risk_hits"),
                "escalation_status": _field(task_text, "escalation_status"),
                "review_status": _field(combined, "review_status"),
                "has_review_flow_status": "review_flow" in texts,
                "has_claude_review": "claude_review" in texts,
                "requires_josh_approval": _field(task_text, "requires_josh_approval").lower() in {"true", "yes", "1"},
                "approval": _field(task_text, "approval"),
                "pending_approval": False,
                "models_invoked": _field(combined, "models_invoked"),
                "external_actions_invoked": _field(combined, "external_actions_invoked"),
                "cleanup_executed": _field(combined, "cleanup_executed"),
                "failure_reason": _field(combined, "failure_reason") or _field(combined, "reason"),
                "has_result": "result" in texts,
                "result_preview": texts.get("result", "")[:500],
                "artifact_ref": artifact_ids.get(f"{dispatch_id}:task", ""),
                "result_ref": artifact_ids.get(f"{dispatch_id}:result", ""),
                "artifact_path": "",
                "result_path": "",
                "artifact_refs": refs,
                "evidence_files": [entry["kind"] for entry in refs],
                "mtime": max(mtimes),
                "mtime_str": datetime.fromtimestamp(max(mtimes)).strftime("%Y-%m-%d %H:%M"),
            }
            record["pending_approval"] = bool(
                record["requires_josh_approval"]
                and record["dispatch_status"].lower() not in {"ready_to_route", "completed", "approved"}
                and not record["approval"]
            )
            connection.execute(
                "INSERT INTO tasks VALUES(?,?,?,?,?,?)",
                (folder.name, dispatch_id, title, normalized, max(mtimes), json.dumps(record, ensure_ascii=False)),
            )
            tasks[dispatch_id] = record
        return tasks

    def _scan_nodes(
        self,
        connection: sqlite3.Connection,
        artifact_ids: dict[str, str],
        tasks: dict[str, dict[str, Any]],
    ) -> int:
        count = 0
        if not self.knowledge_dir.exists():
            return count
        for path in sorted(self.knowledge_dir.glob("*.md")):
            if path.name.lower() == "readme.md":
                continue
            text = path.read_text(encoding="utf-8", errors="replace")
            dispatch_id = _field(text, "dispatch_id") or path.stem
            title = _title(text, path.stem)
            summary = _section(text, "Summary", "摘要")
            source_url = _field(text, "source_url") or _field(text, "canonical_url")
            agentos_value = _section(text, "AgentOS Value", "AgentOS 價值") or _field(text, "agentos_value_summary")
            relationship = _section(text, "System Relationship", "系統關聯")
            similarity = _field(text, "similarity_score") or _field(text, "relation_confidence") or "unknown"
            notebook = _field(text, "notebooklm_sync_status") or "unknown"
            node_ref = self._add_artifact(connection, path, "knowledge_node", dispatch_id)
            task = tasks.get(dispatch_id, {})
            refs = [{"kind": "knowledge_node", "ref": node_ref}]
            for kind in ("task", "result", "review_flow", "claude_review", "verify_result"):
                ref = artifact_ids.get(f"{dispatch_id}:{kind}")
                if ref:
                    refs.append({"kind": kind, "ref": ref})
            # source.json is only accepted from this dispatch's own URL-intake directory.
            source_json = self.root / "data" / "url_intake" / dispatch_id / "fetch" / "source.json"
            if self._safe_dispatch_source(source_json, dispatch_id):
                refs.append({"kind": "source_json", "ref": self._add_artifact(connection, source_json, "source_json", dispatch_id)})
            record = {
                "dispatch_id": dispatch_id,
                "title": title,
                "summary": summary,
                "source_url": source_url,
                "agentos_value": agentos_value,
                "system_relationship": relationship,
                "similarity_score": similarity,
                "relationship_status": "suggested_similarity_only",
                "local_sync_status": "indexed",
                "notebooklm_sync_status": notebook,
                "task_folder_id": task.get("folder_id", ""),
                "artifact_refs": refs,
            }
            search_text = "\n".join((dispatch_id, title, summary, source_url, agentos_value, relationship, text))
            connection.execute(
                "INSERT INTO nodes VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (
                    dispatch_id, title, summary, source_url, agentos_value, relationship,
                    similarity, "indexed", notebook, node_ref, task.get("folder_id", ""),
                    search_text, json.dumps(record, ensure_ascii=False),
                ),
            )
            connection.execute("INSERT INTO node_search VALUES(?,?)", (dispatch_id, search_text))
            count += 1
        return count

    def _safe_dispatch_source(self, source_json: Path, dispatch_id: str) -> bool:
        expected = self.root / "data" / "url_intake" / dispatch_id / "fetch"
        if not source_json.is_file() or source_json.name != "source.json":
            return False
        current = source_json
        boundary = self.root / "data" / "url_intake"
        while True:
            if current.is_symlink() or (hasattr(os.path, "isjunction") and os.path.isjunction(current)):
                return False
            if current == boundary:
                break
            if boundary not in current.parents:
                return False
            current = current.parent
        try:
            source_json.resolve(strict=True).relative_to(expected.resolve(strict=True))
        except (ValueError, OSError):
            return False
        return source_json.resolve(strict=True).parent == expected.resolve(strict=True)

    def projection_as_of(self) -> str:
        self.ensure()
        with closing(self.connect()) as connection:
            row = connection.execute("SELECT value FROM meta WHERE key='projection_as_of'").fetchone()
            return row[0] if row else "unknown"

    def list_tasks(self) -> list[dict[str, Any]]:
        self.ensure()
        with closing(self.connect()) as connection:
            rows = connection.execute("SELECT record_json FROM tasks ORDER BY mtime DESC").fetchall()
        return [json.loads(row[0]) for row in rows]

    def task_detail(self, identifier: str) -> dict[str, Any] | None:
        self.ensure()
        with closing(self.connect()) as connection:
            row = connection.execute(
                "SELECT record_json FROM tasks WHERE folder_id=? OR dispatch_id=? ORDER BY folder_id LIMIT 1",
                (identifier, identifier),
            ).fetchone()
        return json.loads(row[0]) if row else None

    def list_nodes(self, cursor: str | None = None, limit: int = 30) -> dict[str, Any]:
        self.ensure()
        offset = _cursor_decode(cursor)
        limit = max(1, min(limit, 100))
        with closing(self.connect()) as connection:
            total = connection.execute("SELECT count(*) FROM nodes").fetchone()[0]
            rows = connection.execute(
                "SELECT record_json FROM nodes ORDER BY dispatch_id DESC LIMIT ? OFFSET ?", (limit, offset)
            ).fetchall()
        items = [json.loads(row[0]) for row in rows]
        next_offset = offset + len(items)
        return {
            "items": items,
            "total": total,
            "next_cursor": _cursor_encode(next_offset) if next_offset < total else None,
            "projection_as_of": self.projection_as_of(),
        }

    def search(self, query: str, cursor: str | None = None, limit: int = 30) -> dict[str, Any]:
        self.ensure()
        terms = _search_terms(query)
        if not terms:
            return self.list_nodes(cursor, limit)
        offset = _cursor_decode(cursor)
        limit = max(1, min(limit, 100))
        with closing(self.connect()) as connection:
            try:
                rows = connection.execute(
                    """SELECT n.record_json, bm25(node_search) AS rank
                       FROM node_search JOIN nodes n USING(dispatch_id)
                       WHERE node_search MATCH ? ORDER BY rank LIMIT ? OFFSET ?""",
                    (terms, limit + 1, offset),
                ).fetchall()
            except sqlite3.OperationalError:
                rows = []
            # The trigram tokenizer intentionally has no index entries shorter
            # than three characters. Exact LIKE fallback keeps common two-Han-
            # character searches useful without changing canonical artifacts.
            if not rows:
                rows = connection.execute(
                    "SELECT record_json, 0 AS rank FROM nodes WHERE search_text LIKE ? LIMIT ? OFFSET ?",
                    (f"%{query}%", limit + 1, offset),
                ).fetchall()
        has_more = len(rows) > limit
        items = []
        for row in rows[:limit]:
            record = json.loads(row[0])
            record["similarity_score"] = float(-row[1]) if row[1] is not None else 0.0
            record["relationship_status"] = "search_similarity_not_confirmed"
            items.append(record)
        return {
            "items": items,
            "next_cursor": _cursor_encode(offset + limit) if has_more else None,
            "projection_as_of": self.projection_as_of(),
        }

    def node_detail(self, dispatch_id: str) -> dict[str, Any] | None:
        self.ensure()
        with closing(self.connect()) as connection:
            row = connection.execute("SELECT record_json FROM nodes WHERE dispatch_id=?", (dispatch_id,)).fetchone()
            projection = connection.execute("SELECT value FROM meta WHERE key='projection_as_of'").fetchone()
        if not row:
            return None
        record = json.loads(row[0])
        record["projection_as_of"] = projection[0] if projection else "unknown"
        record["stale"] = self._node_is_stale(record)
        return record

    def _node_is_stale(self, record: dict[str, Any]) -> bool:
        node_ref = next((x["ref"] for x in record.get("artifact_refs", []) if x["kind"] == "knowledge_node"), "")
        if not node_ref:
            return True
        with closing(self.connect()) as connection:
            row = connection.execute("SELECT relative_path,mtime_ns,size FROM artifacts WHERE ref=?", (node_ref,)).fetchone()
        if not row:
            return True
        path = (self.root / row[0]).resolve()
        try:
            path.relative_to(self.root)
            stat = path.stat()
        except (ValueError, OSError):
            return True
        return stat.st_mtime_ns != row[1] or stat.st_size != row[2]

    def artifact(self, ref: str) -> dict[str, Any] | None:
        self.ensure()
        with closing(self.connect()) as connection:
            row = connection.execute(
                "SELECT relative_path,kind,dispatch_id,sha256,mtime_ns,size FROM artifacts WHERE ref=?", (ref,)
            ).fetchone()
        if not row:
            return None
        path = (self.root / row[0]).resolve()
        try:
            path.relative_to(self.root)
        except ValueError:
            return None
        if not path.is_file() or path.is_symlink():
            return None
        return {
            "ref": ref,
            "kind": row[1],
            "dispatch_id": row[2],
            "sha256": row[3],
            "mtime_ns": row[4],
            "size": row[5],
            "content": path.read_text(encoding="utf-8", errors="replace"),
        }

    def today(self, limit: int = 20) -> dict[str, Any]:
        nodes = self.list_nodes(limit=limit)
        tasks = self.list_tasks()[:limit]
        all_tasks = self.list_tasks()
        return {
            "knowledge_nodes": nodes["items"],
            "recent_tasks": tasks,
            "recent_completed": [item for item in all_tasks if item.get("normalized_status") == "completed"][:limit],
            "needs_josh": [item for item in all_tasks if item.get("pending_approval") or item.get("escalation_status") in {"pending", "awaiting_josh"}][:limit],
            "recoverable_failures": [item for item in all_tasks if item.get("normalized_status") == "blocked"][:limit],
            "projection_as_of": nodes["projection_as_of"],
        }


class DiscussionStore:
    """Append-only annotations isolated from canonical task and knowledge files."""

    SAFE_ID = re.compile(r"^[A-Za-z0-9_.-]{1,180}$")

    def __init__(self, root: Path) -> None:
        self.root = root.resolve()
        self.discussions_dir = self.root / "data" / "knowledge_discussions"
        self.candidates_dir = self.root / "data" / "knowledge_candidates"
        self._lock = threading.Lock()

    def _safe(self, value: str, label: str) -> str:
        if not self.SAFE_ID.fullmatch(value):
            raise ValueError(f"invalid {label}")
        return value

    @staticmethod
    def _is_reparse(path: Path) -> bool:
        try:
            stat = path.lstat()
        except FileNotFoundError:
            return False
        attributes = getattr(stat, "st_file_attributes", 0)
        return bool(
            path.is_symlink()
            or (hasattr(os.path, "isjunction") and os.path.isjunction(path))
            or attributes & 0x400  # FILE_ATTRIBUTE_REPARSE_POINT
        )

    def _prepare_storage_root(self, storage_root: Path) -> Path:
        # Create one component at a time and reject every existing reparse point.
        try:
            relative = storage_root.absolute().relative_to(self.root.absolute())
        except ValueError as exc:
            raise ValueError("storage root escaped AgentOS root") from exc
        current = self.root
        if self._is_reparse(current):
            raise ValueError("AgentOS root is a reparse point")
        for component in relative.parts:
            current = current / component
            current.mkdir(exist_ok=True)
            if self._is_reparse(current):
                raise ValueError("storage ancestor is a reparse point")
        resolved_root = storage_root.resolve(strict=True)
        try:
            resolved_root.relative_to(self.root.resolve(strict=True))
        except ValueError as exc:
            raise ValueError("storage root escaped AgentOS root") from exc
        return resolved_root

    def _validate_file(self, storage_root: Path, path: Path) -> None:
        resolved_root = self._prepare_storage_root(storage_root)
        if path.parent != storage_root:
            raise ValueError("nested storage paths are not allowed")
        if self._is_reparse(path):
            raise ValueError("storage file is a reparse point")
        if path.exists() and path.lstat().st_nlink != 1:
            raise ValueError("storage file has multiple hard links")
        try:
            path.parent.resolve(strict=True).relative_to(resolved_root)
        except ValueError as exc:
            raise ValueError("storage path escaped isolated root") from exc

    def _path(self, node_id: str, discussion_id: str, event_id: str) -> Path:
        node = self._safe(node_id, "node_id")
        discussion = self._safe(discussion_id, "discussion_id")
        event = self._safe(event_id, "event_id")
        return self.discussions_dir / f"{node}--{discussion}--{event}.json"

    def append(
        self,
        node_id: str,
        discussion_id: str,
        event_type: str,
        content: str,
        actor_id: str,
        auth_method: str,
        request_id: str,
        target: str = "",
    ) -> tuple[Path, dict[str, Any]]:
        if event_type not in {"discussion_created", "message", "feedback_annotation"}:
            raise ValueError("invalid event_type")
        if not content.strip() or len(content) > 20_000:
            raise ValueError("content must contain 1..20000 characters")
        event_id = str(uuid.uuid4())
        path = self._path(node_id, discussion_id, event_id)
        event = {
            "event_id": event_id,
            "timestamp": _utc_now(),
            "type": event_type,
            "node_id": node_id,
            "discussion_id": discussion_id,
            "content": content.strip(),
            "target": target.strip()[:500],
            "actor_id": actor_id,
            "auth_method": auth_method,
            "request_id": request_id,
        }
        self._validate_file(self.discussions_dir, path)
        payload = json.dumps(event, ensure_ascii=False, separators=(",", ":")) + "\n"
        with self._lock:
            self._validate_file(self.discussions_dir, path)
            descriptor = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
            try:
                self._validate_file(self.discussions_dir, path)
                if os.fstat(descriptor).st_nlink != 1:
                    raise ValueError("new event file has multiple hard links")
                os.write(descriptor, payload.encode("utf-8"))
                os.fsync(descriptor)
            finally:
                os.close(descriptor)
        return path, event

    def read(self, node_id: str, discussion_id: str | None = None) -> list[dict[str, Any]]:
        node = self._safe(node_id, "node_id")
        if not self.discussions_dir.exists():
            return []
        self._prepare_storage_root(self.discussions_dir)
        if discussion_id:
            discussion = self._safe(discussion_id, "discussion_id")
            paths = sorted(self.discussions_dir.glob(f"{node}--{discussion}--*.json"))
        else:
            paths = sorted(self.discussions_dir.glob(f"{node}--*.json"))
        events: list[dict[str, Any]] = []
        for path in paths:
            self._validate_file(self.discussions_dir, path)
            if not path.is_file():
                continue
            events.append(json.loads(path.read_text(encoding="utf-8", errors="strict")))
        return events

    def recent(self, limit: int = 20) -> list[dict[str, Any]]:
        if not self.discussions_dir.exists():
            return []
        self._prepare_storage_root(self.discussions_dir)
        events: list[dict[str, Any]] = []
        for path in sorted(self.discussions_dir.glob("*.json")):
            self._validate_file(self.discussions_dir, path)
            if path.is_file():
                events.append(json.loads(path.read_text(encoding="utf-8", errors="strict")))
        return sorted(events, key=lambda item: item.get("timestamp", ""), reverse=True)[:max(1, min(limit, 100))]

    def candidates(self, limit: int = 20) -> list[dict[str, Any]]:
        if not self.candidates_dir.exists():
            return []
        self._prepare_storage_root(self.candidates_dir)
        candidates: list[dict[str, Any]] = []
        for path in sorted(self.candidates_dir.glob("*.json")):
            self._validate_file(self.candidates_dir, path)
            if not path.is_file():
                continue
            payload = json.loads(path.read_text(encoding="utf-8", errors="strict"))
            candidates.append({
                "candidate_id": payload.get("candidate_id", path.stem),
                "node_id": payload.get("node_id", ""),
                "discussion_id": payload.get("discussion_id", ""),
                "title": payload.get("title", ""),
                "summary": payload.get("summary", ""),
                "status": payload.get("status", "candidate_only"),
                "created_at": payload.get("created_at", ""),
            })
        return sorted(candidates, key=lambda item: item.get("created_at", ""), reverse=True)[:max(1, min(limit, 100))]

    def export_candidate(
        self,
        node_id: str,
        discussion_id: str,
        title: str,
        summary: str,
        actor_id: str,
        auth_method: str,
        request_id: str,
    ) -> Path:
        node = self._safe(node_id, "node_id")
        discussion = self._safe(discussion_id, "discussion_id")
        candidate_id = f"candidate-{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S')}-{uuid.uuid4().hex[:8]}"
        path = self.candidates_dir / f"{node}--{candidate_id}.json"
        payload = {
            "schema": "agentos.knowledge_candidate.v1",
            "status": "candidate_only",
            "candidate_id": candidate_id,
            "node_id": node,
            "discussion_id": discussion,
            "title": title.strip()[:500],
            "summary": summary.strip()[:20_000],
            "discussion_events": self.read(node, discussion),
            "created_at": _utc_now(),
            "actor_id": actor_id,
            "auth_method": auth_method,
            "request_id": request_id,
            "dispatch_executed": False,
            "publish_executed": False,
        }
        self._validate_file(self.candidates_dir, path)
        temporary = path.with_suffix(".tmp")
        self._validate_file(self.candidates_dir, temporary)
        descriptor = os.open(temporary, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        try:
            self._validate_file(self.candidates_dir, temporary)
            if os.fstat(descriptor).st_nlink != 1:
                raise ValueError("candidate temp file has multiple hard links")
            os.write(descriptor, json.dumps(payload, ensure_ascii=False, indent=2).encode("utf-8"))
            os.fsync(descriptor)
        finally:
            os.close(descriptor)
        self._validate_file(self.candidates_dir, temporary)
        self._validate_file(self.candidates_dir, path)
        os.replace(temporary, path)
        self._validate_file(self.candidates_dir, path)
        return path

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
import uuid
from pathlib import Path
from unittest.mock import patch

from fastapi.testclient import TestClient


ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "dashboard" / "backend"
sys.path.insert(0, str(BACKEND))

import main as dashboard_main  # noqa: E402
from dashboard_security import DashboardSecurity  # noqa: E402
from knowledge_workspace import DiscussionStore, KnowledgeIndex  # noqa: E402


DISPATCH_ID = "telegram-telegram-1449022024-1354-20260720-115628-736386"
ORIGIN = "http://localhost:3000"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class KnowledgeWorkspaceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="agentos-knowledge-workspace-")
        self.root = Path(self.temp.name)
        self.task_dir = self.root / "data" / "codex_tasks" / f"2026-07-20-url-intake-{DISPATCH_ID}"
        self.task_dir.joinpath("OUTPUTS").mkdir(parents=True)
        self.task_dir.joinpath("TASK.md").write_text(
            "\n".join((
                "# URL Intake 1354",
                f"dispatch_id: {DISPATCH_ID}",
                "task_status: completed",
                "assigned_to: Codex Builder",
                "governance_version: 1.3.0",
                "## Objective",
                "建立可追溯的知識庫節點。",
            )),
            encoding="utf-8",
        )
        self.task_dir.joinpath("OUTPUTS", "RESULT.md").write_text(
            "# Result\n\nSummary\n\nLoreloom 將來源、人工知識與 AI Wiki 分層。\n",
            encoding="utf-8",
        )
        source = self.root / "data" / "url_intake" / DISPATCH_ID / "fetch" / "source.json"
        source.parent.mkdir(parents=True)
        source.write_text(json.dumps({"url": "https://example.test/loreloom", "text": "知識庫"}, ensure_ascii=False), encoding="utf-8")
        self.node_path = self.root / "data" / "knowledge_pool" / f"2026-07-20-{DISPATCH_ID}.md"
        self.node_path.parent.mkdir(parents=True)
        self.node_path.write_text(
            "\n".join((
                f"# Knowledge Node: {DISPATCH_ID}",
                f"dispatch_id: {DISPATCH_ID}",
                "source_url: https://example.test/loreloom",
                "notebooklm_sync_status: logged_out",
                "## Summary",
                "貼文介紹 Loreloom 個人知識庫，保留來源並降低錯誤摘要風險。",
                "## AgentOS Value",
                "讓每一筆繁體中文知識都能回到原始證據。",
                "## System Relationship",
                "僅為相似度建議，並非已確認關聯。",
            )),
            encoding="utf-8",
        )
        self.index = KnowledgeIndex(self.root)
        self.index.rebuild()

    def tearDown(self) -> None:
        self.temp.cleanup()

    def canonical_hashes(self) -> dict[str, str]:
        return {
            str(path.relative_to(self.root)): digest(path)
            for path in sorted((self.root / "data").rglob("*"))
            if path.is_file() and "dashboard_index" not in path.parts
            and "knowledge_discussions" not in path.parts and "knowledge_candidates" not in path.parts
        }

    def test_traditional_chinese_search_traces_1354_artifacts(self) -> None:
        result = self.index.search("繁體中文知識庫")
        node = next(item for item in result["items"] if item["dispatch_id"] == DISPATCH_ID)
        detail = self.index.node_detail(DISPATCH_ID)
        self.assertEqual(node["relationship_status"], "search_similarity_not_confirmed")
        self.assertEqual(detail["task_folder_id"], self.task_dir.name)
        kinds = {item["kind"] for item in detail["artifact_refs"]}
        self.assertTrue({"source_json", "result", "knowledge_node", "task"}.issubset(kinds))
        for item in detail["artifact_refs"]:
            artifact = self.index.artifact(item["ref"])
            self.assertIsNotNone(artifact)
            self.assertNotIn("relative_path", artifact)
        self.assertFalse(detail["stale"])
        self.assertTrue(any(
            item["dispatch_id"] == DISPATCH_ID for item in self.index.search("知識")["items"]
        ))

    def test_rebuild_is_deterministic_and_preserves_canonical_hashes(self) -> None:
        before = self.canonical_hashes()
        first_refs = self.index.node_detail(DISPATCH_ID)["artifact_refs"]
        self.index.db_path.unlink()
        self.index.rebuild()
        self.assertEqual(before, self.canonical_hashes())
        self.assertEqual(first_refs, self.index.node_detail(DISPATCH_ID)["artifact_refs"])

    def test_source_signature_tracks_only_canonical_index_inputs(self) -> None:
        initial = self.index._source_signature()
        indexed = {path.relative_to(self.root).as_posix() for path in self.index._iter_source_paths()}
        self.assertIn(
            f"data/codex_tasks/{self.task_dir.name}/TASK.md",
            indexed,
        )
        self.assertIn(
            f"data/url_intake/{DISPATCH_ID}/fetch/source.json",
            indexed,
        )

        irrelevant = self.task_dir / "fetch" / "images" / "large-evidence.bin"
        irrelevant.parent.mkdir(parents=True)
        irrelevant.write_bytes(b"not consumed by the index")
        self.assertNotIn(irrelevant.relative_to(self.root).as_posix(), indexed)
        self.assertEqual(initial, self.index._source_signature())

        with self.task_dir.joinpath("OUTPUTS", "RESULT.md").open("a", encoding="utf-8") as handle:
            handle.write("\ncanonical change\n")
        self.assertNotEqual(initial, self.index._source_signature())

    def test_refresh_reads_index_without_full_task_scan(self) -> None:
        scans = self.index.scan_count
        for _ in range(5):
            self.index.list_tasks()
            self.index.list_nodes()
            self.index.node_detail(DISPATCH_ID)
        self.assertEqual(scans, self.index.scan_count)
        reconciliation = self.index.reconcile()
        self.assertFalse(reconciliation["updated"])
        self.assertEqual(scans, self.index.scan_count)

    def test_feedback_persists_restart_and_isolated_from_canonical_node(self) -> None:
        before = digest(self.node_path)
        store = DiscussionStore(self.root)
        _, event = store.append(
            DISPATCH_ID, "feedback-1", "feedback_annotation", "我認可摘要，但想深究來源。",
            "owner\\josh", "local_owner_token", "req-1", "summary",
        )
        restarted = DiscussionStore(self.root)
        events = restarted.read(DISPATCH_ID, "feedback-1")
        self.assertEqual(events[0]["event_id"], event["event_id"])
        self.assertEqual(before, digest(self.node_path))
        candidate = restarted.export_candidate(
            DISPATCH_ID, "feedback-1", "深入 Loreloom", "只輸出候選包",
            "owner\\josh", "local_owner_token", "req-2",
        )
        payload = json.loads(candidate.read_text(encoding="utf-8"))
        self.assertEqual(payload["status"], "candidate_only")
        self.assertFalse(payload["dispatch_executed"])
        self.assertFalse(payload["publish_executed"])
        self.assertEqual(restarted.candidates()[0]["candidate_id"], payload["candidate_id"])
        self.assertEqual(restarted.recent()[0]["type"], "feedback_annotation")
        self.assertEqual(before, digest(self.node_path))
        with self.assertRaises(ValueError):
            restarted.append(DISPATCH_ID, "../../TASK", "message", "escape", "a", "m", "r")

    def test_today_contract_has_all_phase1_classifications(self) -> None:
        today = self.index.today()
        self.assertIn("recent_completed", today)
        self.assertIn("needs_josh", today)
        self.assertIn("recoverable_failures", today)
        self.assertTrue(any(item["dispatch_id"] == DISPATCH_ID for item in today["recent_completed"]))
        source = (ROOT / "dashboard" / "frontend" / "components" / "TodayWorkspace.tsx").read_text(encoding="utf-8")
        for label in ("未讀完成", "需要 Josh", "失敗可恢復", "待處理 Feedback", "草稿 Candidate", "最近知識"):
            self.assertIn(label, source)
        self.assertIn("localStorage", source)

    def test_notebooklm_logged_out_does_not_block_local_features(self) -> None:
        detail = self.index.node_detail(DISPATCH_ID)
        self.assertEqual(detail["notebooklm_sync_status"], "logged_out")
        self.assertTrue(self.index.search("原始證據")["items"])

    @unittest.skipUnless(os.name == "nt", "NTFS junction regression is Windows-only")
    def test_discussion_and_candidate_roots_reject_junction_escape(self) -> None:
        store = DiscussionStore(self.root)
        outside = self.root / "outside-storage"
        outside.mkdir()
        for storage_root, action in (
            (
                store.discussions_dir,
                lambda: store.append(
                    DISPATCH_ID, "junction-test", "message", "must not escape", "actor", "auth", "req"
                ),
            ),
            (
                store.candidates_dir,
                lambda: store.export_candidate(
                    DISPATCH_ID, "junction-test", "title", "must not escape", "actor", "auth", "req"
                ),
            ),
        ):
            storage_root.parent.mkdir(parents=True, exist_ok=True)
            completed = subprocess.run(
                ["cmd.exe", "/c", "mklink", "/J", str(storage_root), str(outside)],
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                check=False,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
            try:
                with self.assertRaises(ValueError):
                    action()
                self.assertEqual(list(outside.iterdir()), [])
            finally:
                os.rmdir(storage_root)
        # A malicious legacy per-node directory must also be inert: current
        # storage is flat and never traverses it.
        store.discussions_dir.mkdir()
        legacy_node = store.discussions_dir / DISPATCH_ID
        completed = subprocess.run(
            ["cmd.exe", "/c", "mklink", "/J", str(legacy_node), str(outside)],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        try:
            path, _ = store.append(
                DISPATCH_ID, "flat-storage", "message", "safe", "actor", "auth", "req"
            )
            self.assertEqual(path.parent, store.discussions_dir)
            self.assertEqual(list(outside.iterdir()), [])
        finally:
            os.rmdir(legacy_node)

    @unittest.skipUnless(os.name == "nt", "NTFS hard-link regression is Windows-only")
    def test_discussion_rejects_prepositioned_final_hard_link(self) -> None:
        store = DiscussionStore(self.root)
        store.discussions_dir.mkdir(parents=True)
        outside = self.root / "outside-hardlink-target.json"
        outside.write_text("ORIGINAL", encoding="utf-8")
        fixed = uuid.UUID("11111111-1111-4111-8111-111111111111")
        event_path = store._path(DISPATCH_ID, "hardlink-test", str(fixed))
        os.link(outside, event_path)
        try:
            with patch("knowledge_workspace.uuid.uuid4", return_value=fixed):
                with self.assertRaises(ValueError):
                    store.append(
                        DISPATCH_ID, "hardlink-test", "message", "ESCAPE", "actor", "auth", "req"
                    )
            self.assertEqual(outside.read_text(encoding="utf-8"), "ORIGINAL")
        finally:
            event_path.unlink()


class KnowledgeWorkspaceApiSecurityTests(KnowledgeWorkspaceTests):
    def setUp(self) -> None:
        super().setUp()
        self.old_auth = dashboard_main.AUTH
        self.old_index = dashboard_main.KNOWLEDGE_INDEX
        self.old_discussions = dashboard_main.DISCUSSIONS
        os.environ["AGENTOS_DASHBOARD_AUTH_DIR"] = str(self.root / "auth")
        os.environ["AGENTOS_DASHBOARD_MUTATIONS_ENABLED"] = "0"
        dashboard_main.AUTH = DashboardSecurity(self.root)
        dashboard_main.KNOWLEDGE_INDEX = self.index
        dashboard_main.DISCUSSIONS = DiscussionStore(self.root)
        self.context = TestClient(dashboard_main.app)
        self.client = self.context.__enter__()
        self.token = dashboard_main.AUTH.token_path.read_text(encoding="utf-8").splitlines()[0]

    def tearDown(self) -> None:
        self.context.__exit__(None, None, None)
        dashboard_main.AUTH = self.old_auth
        dashboard_main.KNOWLEDGE_INDEX = self.old_index
        dashboard_main.DISCUSSIONS = self.old_discussions
        os.environ.pop("AGENTOS_DASHBOARD_AUTH_DIR", None)
        os.environ.pop("AGENTOS_DASHBOARD_MUTATIONS_ENABLED", None)
        super().tearDown()

    def login(self) -> dict:
        response = self.client.post("/api/auth/login", headers={"Origin": ORIGIN}, json={"token": self.token})
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()

    def test_public_reads_and_protected_append_only_write(self) -> None:
        self.assertEqual(self.client.get("/api/v1/knowledge/search?q=知識庫").status_code, 200)
        today = self.client.get("/api/v1/today")
        self.assertEqual(today.status_code, 200)
        self.assertTrue({"recent_completed", "needs_josh", "recoverable_failures", "pending_feedback", "knowledge_candidates"}.issubset(today.json()))
        self.assertEqual(self.client.get(f"/api/v1/knowledge/{DISPATCH_ID}").status_code, 200)
        url = f"/api/v1/knowledge/{DISPATCH_ID}/feedback"
        self.assertEqual(self.client.post(url, headers={"Origin": ORIGIN}, json={"content": "x"}).status_code, 403)
        auth = self.login()
        self.assertEqual(self.client.post(url, headers={"Origin": ORIGIN}, json={"content": "x"}).status_code, 403)
        before = digest(self.node_path)
        response = self.client.post(
            url,
            headers={"Origin": ORIGIN, "X-CSRF-Token": auth["csrf_token"], "X-Request-ID": "phase1-api-test"},
            json={"content": "認可摘要", "target": "summary"},
        )
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(before, digest(self.node_path))
        audit = json.loads(dashboard_main.AUTH.audit_path.read_text(encoding="utf-8").splitlines()[-1])
        self.assertEqual(audit["actor_id"], dashboard_main.AUTH.owner_identity)
        self.assertEqual(audit["auth_method"], "local_owner_token")
        self.assertEqual(audit["request_id"], "phase1-api-test")

    def test_path_fields_are_rejected_and_domain_mutations_stay_off(self) -> None:
        auth = self.login()
        headers = {"Origin": ORIGIN, "X-CSRF-Token": auth["csrf_token"]}
        feedback = self.client.post(
            f"/api/v1/knowledge/{DISPATCH_ID}/feedback",
            headers=headers,
            json={"content": "x", "path": "../TASK.md"},
        )
        self.assertEqual(feedback.status_code, 422)
        domain_write = self.client.post("/api/decisions/layout", headers=headers, json={"positions": {}})
        self.assertEqual(domain_write.status_code, 403)


if __name__ == "__main__":
    unittest.main()

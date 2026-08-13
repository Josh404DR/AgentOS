from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from fastapi.testclient import TestClient


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "dashboard" / "backend"))

import main as dashboard_main  # noqa: E402
from dashboard_security import DashboardSecurity  # noqa: E402


class CiFixtureNamespaceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="agentos-ci-fixture-api-")
        dashboard_main.AUTH = DashboardSecurity(Path(self.temp.name))
        self.client_context = TestClient(dashboard_main.app)
        self.client = self.client_context.__enter__()

    def tearDown(self) -> None:
        self.client_context.__exit__(None, None, None)
        self.temp.cleanup()

    def test_tasks_hide_ci_fixture_by_default_and_allow_explicit_all(self) -> None:
        rows = [
            {"dispatch_id": "runtime-task", "folder_id": "runtime-task"},
            {"dispatch_id": "ci-smoke-queue-root", "folder_id": "ci-smoke-queue-root"},
        ]
        with patch.object(dashboard_main.KNOWLEDGE_INDEX, "list_tasks", return_value=rows):
            default = self.client.get("/api/tasks")
            include_all = self.client.get("/api/tasks?include_ci_fixtures=true")
        self.assertEqual(default.status_code, 200)
        self.assertEqual([row["dispatch_id"] for row in default.json()], ["runtime-task"])
        self.assertEqual(len(include_all.json()), 2)

    def test_task_detail_hides_ci_fixture_by_default_and_allows_explicit_all(self) -> None:
        row = {
            "dispatch_id": "ci-smoke-queue-root",
            "folder_id": "ci-smoke-queue-root",
            "artifact_refs": [],
        }
        with patch.object(
            dashboard_main.KNOWLEDGE_INDEX, "task_detail", return_value=row
        ) as task_detail:
            default = self.client.get("/api/tasks/ci-smoke-queue-root")
            task_detail.assert_not_called()
            include_all = self.client.get(
                "/api/tasks/ci-smoke-queue-root?include_ci_fixtures=true"
            )
        self.assertEqual(default.status_code, 200)
        self.assertEqual(default.json()["error"], "task not found")
        self.assertEqual(include_all.status_code, 200)
        self.assertEqual(include_all.json()["dispatch_id"], "ci-smoke-queue-root")
        task_detail.assert_called_once_with("ci-smoke-queue-root")

    def test_escalations_hide_ci_fixture_by_default_and_allow_explicit_all(self) -> None:
        rows = [
            {"task_id": "runtime-task", "josh_action_required": True},
            {"task_id": "ci-smoke-failure", "josh_action_required": True},
        ]
        with patch.object(dashboard_main, "_list_escalations", return_value=rows):
            default = self.client.get("/api/escalations")
            include_all = self.client.get("/api/escalations?include_ci_fixtures=true")
        self.assertEqual(default.status_code, 200)
        self.assertEqual(default.json()["total"], 1)
        self.assertEqual(default.json()["items"][0]["task_id"], "runtime-task")
        self.assertEqual(include_all.json()["total"], 2)


if __name__ == "__main__":
    unittest.main()

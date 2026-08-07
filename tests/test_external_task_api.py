"""Tests for the SCC external task API (dashboard/backend/external_task_api.py).

Run:  python -m unittest tests.test_external_task_api -v
(from E:\\AgentOS, with dashboard\\backend on sys.path — handled below)
"""
from __future__ import annotations

import hashlib
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "dashboard" / "backend"))

from fastapi import FastAPI  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

import external_task_api as api  # noqa: E402

TEST_KEY = "test-key-0123456789abcdef0123456789abcdef"  # >= 32 chars


class ExternalTaskApiTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        root = Path(self._tmp.name)
        self._orig = {
            "CODEX_TASKS_DIR": api.CODEX_TASKS_DIR,
            "ESCALATIONS_DIR": api.ESCALATIONS_DIR,
            "AGENTS_MD": api.AGENTS_MD,
            "GOVERNANCE_STATUS": api.GOVERNANCE_STATUS,
            "QUEUE_INDEX": api.QUEUE_INDEX,
        }
        api.CODEX_TASKS_DIR = root / "codex_tasks"
        api.CODEX_TASKS_DIR.mkdir()
        api.ESCALATIONS_DIR = root / "escalations"
        api.ESCALATIONS_DIR.mkdir()
        api.AGENTS_MD = root / "AGENTS.md"
        api.AGENTS_MD.write_text("governance test content v1", encoding="utf-8")
        live_hash = hashlib.sha256(api.AGENTS_MD.read_bytes()).hexdigest().upper()
        api.GOVERNANCE_STATUS = root / "governance_status.json"
        api.GOVERNANCE_STATUS.write_text(
            json.dumps({"governance_version": "9.9.9-test", "canonical_hash": live_hash}),
            encoding="utf-8",
        )
        api.QUEUE_INDEX = root / "ACTIVE_TASK_INDEX.json"

        self._env_before = os.environ.get(api.API_KEY_ENV)
        os.environ[api.API_KEY_ENV] = TEST_KEY

        app = FastAPI()
        app.include_router(api.router)
        self.client = TestClient(app)

    def tearDown(self) -> None:
        for name, value in self._orig.items():
            setattr(api, name, value)
        if self._env_before is None:
            os.environ.pop(api.API_KEY_ENV, None)
        else:
            os.environ[api.API_KEY_ENV] = self._env_before
        self._tmp.cleanup()

    # -- auth ---------------------------------------------------------------
    def test_unconfigured_key_fails_closed_503(self):
        os.environ[api.API_KEY_ENV] = ""  # empty => unconfigured (env set, no HKCU consult)
        r = self.client.post("/api/v1/external/tasks", json=self._body())
        self.assertEqual(r.status_code, 503)

    def test_short_key_fails_closed_503(self):
        os.environ[api.API_KEY_ENV] = "short"
        r = self.client.get(
            "/api/v1/external/tasks/whatever", headers={"X-AgentOS-API-Key": "short"}
        )
        self.assertEqual(r.status_code, 503)

    def test_wrong_key_401(self):
        r = self.client.post(
            "/api/v1/external/tasks",
            json=self._body(),
            headers={"X-AgentOS-API-Key": "wrong-key-wrong-key-wrong-key-wrong"},
        )
        self.assertEqual(r.status_code, 401)

    def test_missing_key_header_401(self):
        r = self.client.post("/api/v1/external/tasks", json=self._body())
        self.assertEqual(r.status_code, 401)

    # -- health -------------------------------------------------------------
    def test_health_requires_no_key(self):
        r = self.client.get("/api/v1/external/health")
        self.assertEqual(r.status_code, 200)
        self.assertTrue(r.json()["api_key_configured"])
        self.assertFalse(r.json()["queue_runner_alive"])

    # -- create -------------------------------------------------------------
    def test_create_writes_governed_task_md(self):
        r = self.client.post(
            "/api/v1/external/tasks",
            json=self._body(client_ref="SCC-42"),
            headers=self._auth(),
        )
        self.assertEqual(r.status_code, 200, r.text)
        dispatch_id = r.json()["dispatch_id"]
        self.assertTrue(dispatch_id.startswith("scc-"))
        task_md = (api.CODEX_TASKS_DIR / dispatch_id / "TASK.md").read_text(encoding="utf-8")
        self.assertIn("dispatch_status: ready_to_route", task_md)
        self.assertIn("route_to: Codex", task_md)
        self.assertIn("client_ref: SCC-42", task_md)
        self.assertIn("governance_version: 9.9.9-test", task_md)
        live_hash = hashlib.sha256(api.AGENTS_MD.read_bytes()).hexdigest().upper()
        self.assertIn(f"governance_hash: {live_hash}", task_md)
        self.assertIn("RISK_RULES", task_md)  # governance clause present
        prompt = api.CODEX_TASKS_DIR / dispatch_id / "PROMPT_FOR_CODEX.md"
        self.assertTrue(prompt.is_file())
        self.assertIn(dispatch_id, prompt.read_text(encoding="utf-8"))

    def test_create_rejects_multiline_metadata(self):
        for field in ("title", "client_ref"):
            body = self._body()
            body[field] = "safe\ninjected: value"
            r = self.client.post(
                "/api/v1/external/tasks", json=body, headers=self._auth()
            )
            self.assertEqual(r.status_code, 400, field)

    def test_create_rejects_bad_route_and_mode(self):
        bad_route = self._body()
        bad_route["route_to"] = "Ollama"
        r = self.client.post("/api/v1/external/tasks", json=bad_route, headers=self._auth())
        self.assertEqual(r.status_code, 400)
        bad_mode = self._body()
        bad_mode["codex_mode"] = "yolo"
        r = self.client.post("/api/v1/external/tasks", json=bad_mode, headers=self._auth())
        self.assertEqual(r.status_code, 400)

    def test_create_accepts_valid_workspace_root(self):
        with tempfile.TemporaryDirectory() as target:
            r = self.client.post(
                "/api/v1/external/tasks",
                json=self._body(route_to="Claude CLI", workspace_root=target),
                headers=self._auth(),
            )
            self.assertEqual(r.status_code, 200, r.text)
            dispatch_id = r.json()["dispatch_id"]
            task_md = (api.CODEX_TASKS_DIR / dispatch_id / "TASK.md").read_text(encoding="utf-8")
            self.assertIn(f"workspace_root: {target}", task_md)

    def test_create_defaults_workspace_root_to_none(self):
        r = self.client.post(
            "/api/v1/external/tasks", json=self._body(), headers=self._auth()
        )
        self.assertEqual(r.status_code, 200, r.text)
        dispatch_id = r.json()["dispatch_id"]
        task_md = (api.CODEX_TASKS_DIR / dispatch_id / "TASK.md").read_text(encoding="utf-8")
        self.assertIn("workspace_root: none", task_md)

    def test_create_rejects_nonexistent_workspace_root(self):
        bad = self._body(workspace_root=r"E:\this-directory-should-not-exist-12345")
        r = self.client.post("/api/v1/external/tasks", json=bad, headers=self._auth())
        self.assertEqual(r.status_code, 400)

    def test_create_rejects_relative_workspace_root(self):
        with tempfile.TemporaryDirectory() as target:
            bad = self._body(workspace_root=Path(target).name)
            r = self.client.post("/api/v1/external/tasks", json=bad, headers=self._auth())
            self.assertEqual(r.status_code, 400)

    def test_governance_drift_blocks_intake_503(self):
        api.AGENTS_MD.write_text("governance content CHANGED", encoding="utf-8")
        r = self.client.post("/api/v1/external/tasks", json=self._body(), headers=self._auth())
        self.assertEqual(r.status_code, 503)
        self.assertIn("drift", r.json()["detail"])

    # -- status / result ----------------------------------------------------
    def test_path_traversal_rejected(self):
        for bad in ("..%2F..%2FAGENTS.md", "a%5Cb", ".hidden"):
            r = self.client.get(f"/api/v1/external/tasks/{bad}", headers=self._auth())
            self.assertIn(r.status_code, (400, 404), bad)

    def test_status_and_result_flow(self):
        created = self.client.post(
            "/api/v1/external/tasks",
            json=self._body(client_ref="someone-none-else"),
            headers=self._auth(),
        ).json()
        did = created["dispatch_id"]

        status = self.client.get(f"/api/v1/external/tasks/{did}", headers=self._auth())
        self.assertEqual(status.status_code, 200)
        payload = status.json()
        self.assertEqual(payload["dispatch_status"], "ready_to_route")
        self.assertEqual(payload["client_ref"], "someone-none-else")
        self.assertFalse(payload["result_available"])
        self.assertFalse(payload["escalation_pending"])

        r = self.client.get(f"/api/v1/external/tasks/{did}/result", headers=self._auth())
        self.assertEqual(r.status_code, 409)

        outputs = api.CODEX_TASKS_DIR / did / "OUTPUTS"
        outputs.mkdir()
        (outputs / "RESULT.md").write_text("# done\nstatus: completed\n", encoding="utf-8")
        r = self.client.get(f"/api/v1/external/tasks/{did}/result", headers=self._auth())
        self.assertEqual(r.status_code, 200)
        self.assertIn("# done", r.json()["result_markdown"])
        self.assertEqual(r.json()["output_files"], ["RESULT.md"])

        (api.ESCALATIONS_DIR / did).mkdir()
        status = self.client.get(f"/api/v1/external/tasks/{did}", headers=self._auth()).json()
        self.assertTrue(status["escalation_pending"])

        verify_outputs = api.CODEX_TASKS_DIR / f"{did}-codex-verify" / "OUTPUTS"
        verify_outputs.mkdir(parents=True)
        for verdict in ("PASS", "FAIL", "NEEDS_HUMAN_DECISION"):
            (verify_outputs / "VERIFY_RESULT.md").write_text(
                f"verify_verdict: {verdict}\n", encoding="utf-8"
            )
            status = self.client.get(
                f"/api/v1/external/tasks/{did}", headers=self._auth()
            ).json()
            self.assertEqual(status["verify_verdict"], f"verify_verdict: {verdict}")

    def test_unknown_task_404(self):
        r = self.client.get("/api/v1/external/tasks/scc-nope", headers=self._auth())
        self.assertEqual(r.status_code, 404)

    # -- helpers ------------------------------------------------------------
    @staticmethod
    def _auth() -> dict[str, str]:
        return {"X-AgentOS-API-Key": TEST_KEY}

    @staticmethod
    def _body(**overrides) -> dict:
        body = {
            "title": "SCC test job",
            "instructions": "Read docs/ARCHITECTURE.md and summarize section 1 only.",
            "route_to": "Codex CLI",
            "codex_mode": "verify",
        }
        body.update(overrides)
        return body


if __name__ == "__main__":
    unittest.main()

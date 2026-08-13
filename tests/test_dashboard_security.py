from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from dataclasses import replace
from pathlib import Path
from unittest.mock import patch

from fastapi.testclient import TestClient


ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "dashboard" / "backend"
sys.path.insert(0, str(BACKEND))

os.environ.setdefault("AGENTOS_DASHBOARD_MUTATIONS_ENABLED", "1")
os.environ.setdefault("AGENTOS_DASHBOARD_TOKEN_TTL_SECONDS", "60")
os.environ.setdefault("AGENTOS_DASHBOARD_SESSION_TTL_SECONDS", "60")

import main as dashboard_main  # noqa: E402
from dashboard_security import DashboardSecurity, SESSION_COOKIE  # noqa: E402


ORIGIN = "http://localhost:3000"


class DashboardSecurityTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="agentos-dashboard-security-")
        self.root = Path(self.temp.name)
        os.environ["AGENTOS_DASHBOARD_AUTH_DIR"] = str(self.root / "auth")
        os.environ["AGENTOS_DASHBOARD_MUTATIONS_ENABLED"] = "1"
        dashboard_main.AUTH = DashboardSecurity(self.root)
        dashboard_main.DECISIONS_DIR = self.root / "decisions"
        dashboard_main.DECISIONS_LAYOUT = dashboard_main.DECISIONS_DIR / "_layout.json"
        dashboard_main.ESCALATIONS_DIR = self.root / "escalations"
        self.client_context = TestClient(dashboard_main.app)
        self.client = self.client_context.__enter__()
        self.token = dashboard_main.AUTH.token_path.read_text(encoding="utf-8").splitlines()[0]

    def tearDown(self) -> None:
        self.client_context.__exit__(None, None, None)
        self.temp.cleanup()

    def login(self) -> dict:
        response = self.client.post(
            "/api/auth/login",
            headers={"Origin": ORIGIN},
            json={"token": self.token},
        )
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()

    def post_layout(self, csrf: str | None = None, origin: str = ORIGIN):
        headers = {"Origin": origin}
        if csrf is not None:
            headers["X-CSRF-Token"] = csrf
        return self.client.post(
            "/api/decisions/layout",
            headers=headers,
            json={"positions": {}},
        )

    def test_read_only_endpoints_remain_public(self) -> None:
        for path in ("/api/health", "/api/workflows", "/api/decisions"):
            response = self.client.get(path)
            self.assertEqual(response.status_code, 200, f"{path}: {response.text}")

    def test_dashboard_and_knowledge_text_is_strict_utf8_without_mojibake(self) -> None:
        paths = [
            ROOT / "dashboard" / "backend" / "main.py",
            ROOT / "dashboard" / "backend" / "dashboard_security.py",
            ROOT / "dashboard" / "start.ps1",
            ROOT / "dashboard" / "DASHBOARD_SCOPE.md",
            *ROOT.joinpath("dashboard", "frontend", "app").rglob("*.tsx"),
            *ROOT.joinpath("dashboard", "frontend", "components").rglob("*.tsx"),
            *ROOT.joinpath("dashboard", "frontend", "lib").rglob("*.ts"),
            ROOT / "data" / "knowledge_pool" / "README.md",
        ]
        for path in paths:
            text = path.read_bytes().decode("utf-8", errors="strict")
            self.assertNotIn("\ufffd", text, str(path))
            for marker in ("銝", "嚗", "蝺", "憭", "撌", "摰", "閮"):
                self.assertNotIn(marker, text, f"{path}: suspicious mojibake marker {marker}")

    def test_invalid_login_and_unauthenticated_write_fail(self) -> None:
        bad = self.client.post(
            "/api/auth/login", headers={"Origin": ORIGIN}, json={"token": "wrong"}
        )
        self.assertEqual(bad.status_code, 403)
        self.assertIn("Owner token 錯誤", bad.json()["detail"])
        self.assertEqual(self.post_layout().status_code, 403)

    def test_expired_login_reports_expiry_and_remains_forbidden(self) -> None:
        self.assertEqual(dashboard_main.AUTH.token_ttl_seconds, 60)
        dashboard_main.AUTH._token_expires_at = time.time() - 1
        response = self.client.post(
            "/api/auth/login",
            headers={"Origin": ORIGIN},
            json={"token": self.token},
        )
        self.assertEqual(response.status_code, 403)
        detail = response.json()["detail"]
        self.assertIn("Owner token 已過期", detail)
        self.assertIn("expires_at=", detail)
        self.assertIn("重啟 backend", detail)

    def test_default_owner_token_and_session_ttls(self) -> None:
        with patch.dict(os.environ, {}, clear=False):
            previous_token = os.environ.pop("AGENTOS_DASHBOARD_TOKEN_TTL_SECONDS", None)
            previous_session = os.environ.pop("AGENTOS_DASHBOARD_SESSION_TTL_SECONDS", None)
            try:
                security = DashboardSecurity(self.root / "ttl-default")
            finally:
                if previous_token is not None:
                    os.environ["AGENTOS_DASHBOARD_TOKEN_TTL_SECONDS"] = previous_token
                if previous_session is not None:
                    os.environ["AGENTOS_DASHBOARD_SESSION_TTL_SECONDS"] = previous_session
        self.assertEqual(security.token_ttl_seconds, 43200)
        self.assertEqual(security.session_ttl_seconds, 14400)

    def test_default_ttl_runtime_windows_and_env_overrides(self) -> None:
        with patch.dict(os.environ, {}, clear=False):
            previous_token = os.environ.pop("AGENTOS_DASHBOARD_TOKEN_TTL_SECONDS", None)
            previous_session = os.environ.pop("AGENTOS_DASHBOARD_SESSION_TTL_SECONDS", None)
            try:
                security = DashboardSecurity(self.root / "ttl-runtime")
                before = time.time()
                security.start()
                after = time.time()
                token_lines = security.token_path.read_text(encoding="utf-8").splitlines()
                token = token_lines[0]
                expires_at = next(line.split("=", 1)[1] for line in token_lines if line.startswith("expires_at="))
                token_expiry = __import__("datetime").datetime.fromisoformat(expires_at).timestamp()
                _, context = security.login(token)
            finally:
                if previous_token is not None:
                    os.environ["AGENTOS_DASHBOARD_TOKEN_TTL_SECONDS"] = previous_token
                if previous_session is not None:
                    os.environ["AGENTOS_DASHBOARD_SESSION_TTL_SECONDS"] = previous_session
        self.assertGreaterEqual(token_expiry - before, 43200 - 2)
        self.assertLessEqual(token_expiry - after, 43200 + 2)
        self.assertGreaterEqual(context.expires_at - before, 14400 - 2)
        self.assertLessEqual(context.expires_at - after, 14400 + 2)

        with patch.dict(
            os.environ,
            {
                "AGENTOS_DASHBOARD_TOKEN_TTL_SECONDS": "1234",
                "AGENTOS_DASHBOARD_SESSION_TTL_SECONDS": "5678",
            },
        ):
            overridden = DashboardSecurity(self.root / "ttl-overridden")
        self.assertEqual(overridden.token_ttl_seconds, 1234)
        self.assertEqual(overridden.session_ttl_seconds, 5678)

    def test_origin_csrf_and_expired_session_fail(self) -> None:
        auth = self.login()
        self.assertEqual(self.post_layout().status_code, 403)
        self.assertEqual(
            self.post_layout(auth["csrf_token"], "http://attacker.invalid").status_code,
            403,
        )
        dashboard_main.AUTH._sessions = {
            key: replace(value, expires_at=time.time() - 1)
            for key, value in dashboard_main.AUTH._sessions.items()
        }
        self.assertEqual(self.post_layout(auth["csrf_token"]).status_code, 403)

    def test_non_owner_session_fails(self) -> None:
        auth = self.login()
        dashboard_main.AUTH._sessions = {
            key: replace(value, actor_id="untrusted\\other")
            for key, value in dashboard_main.AUTH._sessions.items()
        }
        self.assertEqual(self.post_layout(auth["csrf_token"]).status_code, 403)

    def test_authenticated_write_has_real_actor_audit(self) -> None:
        auth = self.login()
        response = self.post_layout(auth["csrf_token"])
        self.assertEqual(response.status_code, 200, response.text)
        event = json.loads(dashboard_main.AUTH.audit_path.read_text(encoding="utf-8").splitlines()[-1])
        self.assertEqual(event["actor_id"], dashboard_main.AUTH.owner_identity)
        self.assertEqual(event["auth_method"], "local_owner_token")
        self.assertTrue(event["request_id"])
        self.assertIsNone(event["before_hash"])
        self.assertEqual(len(event["after_hash"]), 64)
        self.assertEqual(event["before_state"], "absent")
        self.assertEqual(event["after_state"], "saved:0")
        self.assertEqual(event["artifact_hash"], event["after_hash"])
        self.assertNotEqual(event["actor_id"], "Josh")

    def test_owner_session_receipt_is_verifiable_by_powershell_consumer(self) -> None:
        auth = self.login()
        context = dashboard_main.AUTH.authenticate(
            self.client.cookies.get(SESSION_COOKIE, ""),
            auth["csrf_token"],
            "dashboard-receipt-contract",
        )
        task_id = "dashboard-receipt-contract"
        escalation_dir = self.root / "data" / "escalations" / task_id
        escalation_dir.mkdir(parents=True)
        receipt = dashboard_main.AUTH.issue_escalation_decision_receipt(
            context, task_id, "approve", escalation_dir
        )
        validator = ROOT / "scripts" / "escalation_receipt_validation.ps1"
        command = (
            f". '{validator}'; "
            f"$r=Test-AgentOSEscalationReceipt -AgentOSRoot '{self.root}' "
            f"-TaskId '{task_id}' -Decision 'approve' -ActorId '{context.actor_id}' "
            f"-AuthMethod '{context.auth_method}' -RequestId '{context.request_id}' "
            f"-ReceiptPath '{receipt}'; $r | ConvertTo-Json -Compress"
        )
        completed = subprocess.run(
            ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            check=True,
        )
        result = json.loads(completed.stdout.strip().splitlines()[-1])
        self.assertTrue(result["Valid"], result)
        self.assertEqual(result["Reason"], "verified")

    def test_owner_decision_path_works_with_domain_mutations_disabled(self) -> None:
        task_id = "owner-decision-api-contract"
        (dashboard_main.ESCALATIONS_DIR / task_id).mkdir(parents=True)
        unauthenticated = self.client.post(
            f"/api/approvals/{task_id}/decision",
            headers={"Origin": ORIGIN},
            json={"decision": "approve", "note": "contract"},
        )
        self.assertEqual(unauthenticated.status_code, 403)
        auth = self.login()
        os.environ["AGENTOS_DASHBOARD_MUTATIONS_ENABLED"] = "0"
        try:
            with patch.object(
                dashboard_main,
                "_run_control_script",
                return_value={"ok": True, "output": "escalation_decision_status=recorded"},
            ) as runner:
                response = self.client.post(
                    f"/api/approvals/{task_id}/decision",
                    headers={
                        "Origin": ORIGIN,
                        "X-CSRF-Token": auth["csrf_token"],
                        "X-Request-ID": "owner-decision-api-contract",
                    },
                    json={"decision": "approve", "note": "contract"},
                )
        finally:
            os.environ["AGENTOS_DASHBOARD_MUTATIONS_ENABLED"] = "1"
        self.assertEqual(response.status_code, 200, response.text)
        decider_call = next(
            call for call in runner.call_args_list if call.args[0] == "decide_escalation.ps1"
        )
        arguments = decider_call.args[1]
        receipt_path = Path(arguments[arguments.index("-ReceiptPath") + 1])
        self.assertTrue(receipt_path.is_file())
        receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
        self.assertEqual(receipt["task_id"], task_id)
        self.assertEqual(receipt["request_id"], "owner-decision-api-contract")

    def test_decision_note_rejects_mojibake_and_preserves_utf8(self) -> None:
        task_id = "owner-decision-note-encoding"
        (dashboard_main.ESCALATIONS_DIR / task_id).mkdir(parents=True)
        auth = self.login()
        headers = {
            "Origin": ORIGIN,
            "X-CSRF-Token": auth["csrf_token"],
            "X-Request-ID": "owner-decision-note-encoding",
        }
        for note in ("????", "\ufffd\ufffd"):
            with patch.object(dashboard_main, "_run_control_script") as runner:
                response = self.client.post(
                    f"/api/approvals/{task_id}/decision",
                    headers=headers,
                    json={"decision": "modify", "note": note},
                )
            self.assertEqual(response.status_code, 400)
            self.assertIn("encoding invalid", response.json()["detail"])
            runner.assert_not_called()

        note = "請補上驗證證據"
        with patch.object(
            dashboard_main,
            "_run_control_script",
            return_value={"ok": True, "output": "escalation_decision_status=recorded"},
        ) as runner:
            response = self.client.post(
                f"/api/approvals/{task_id}/decision",
                headers=headers,
                json={"decision": "modify", "note": note},
            )
        self.assertEqual(response.status_code, 200, response.text)
        decider_call = next(call for call in runner.call_args_list if call.args[0] == "decide_escalation.ps1")
        arguments = decider_call.args[1]
        self.assertEqual(arguments[arguments.index("-Note") + 1], note)

    def test_legacy_unreceipted_owner_resolution_remains_awaiting_josh(self) -> None:
        task_id = "legacy-model-signed-resolution"
        escalation_dir = dashboard_main.ESCALATIONS_DIR / task_id
        escalation_dir.mkdir(parents=True)
        event_path = escalation_dir / "EVENT.json"
        event_path.write_text(
            json.dumps(
                {
                    "task_id": task_id,
                    "source": "complex_fail",
                    "reason": "fixture",
                    "created_at": "2026-07-20T00:00:00+08:00",
                    "status": "awaiting_josh",
                }
            ),
            encoding="utf-8",
        )
        (escalation_dir / "DECISION-legacy.json").write_text(
            json.dumps(
                {
                    "task_id": task_id,
                    "decision": "approve",
                    "decided_by": "Josh",
                    "authentication_method": "current_chat_explicit_instruction",
                    "request_id": "legacy",
                    "decided_at": "2026-07-20T00:00:01+08:00",
                }
            ),
            encoding="utf-8",
        )
        (escalation_dir / "RESOLUTION.json").write_text(
            json.dumps(
                {
                    "task_id": task_id,
                    "resolution_type": "owner_decision",
                    "josh_action_required": False,
                    "recommended_status": "resolved",
                }
            ),
            encoding="utf-8",
        )
        dashboard_main.ESCALATIONS_DIR.joinpath("ESCALATION_INDEX.jsonl").write_text(
            json.dumps(
                {
                    "task_id": task_id,
                    "source": "complex_fail",
                    "reason": "fixture",
                    "artifact_path": str(event_path),
                    "created_at": "2026-07-20T00:00:00+08:00",
                    "status": "awaiting_josh",
                }
            )
            + "\n",
            encoding="utf-8",
        )
        item = dashboard_main._list_escalations()[0]
        self.assertTrue(item["josh_action_required"])
        self.assertEqual(item["status"], "awaiting_josh")
        self.assertFalse(item["has_resolution"])

    def test_pending_escalation_is_visible_from_approvals_endpoint(self) -> None:
        task_id = "dashboard-visible-pending-approval"
        escalation_dir = dashboard_main.ESCALATIONS_DIR / task_id
        escalation_dir.mkdir(parents=True)
        event_path = escalation_dir / "EVENT.json"
        event = {
            "task_id": task_id,
            "source": "ux-contract",
            "reason": "owner action required",
            "summary_for_josh": "測試待決策項",
            "created_at": "2026-07-21T00:00:00+08:00",
            "status": "awaiting_josh",
        }
        event_path.write_text(json.dumps(event, ensure_ascii=False), encoding="utf-8")
        dashboard_main.ESCALATIONS_DIR.joinpath("ESCALATION_INDEX.jsonl").write_text(
            json.dumps({**event, "artifact_path": str(event_path)}, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
        response = self.client.get("/api/approvals")
        self.assertEqual(response.status_code, 200, response.text)
        payload = response.json()
        self.assertEqual(payload["total"], 1)
        self.assertEqual(payload["items"][0]["task_id"], task_id)
        self.assertEqual(payload["items"][0]["summary_for_josh"], "測試待決策項")

    def test_new_escalation_is_not_hidden_by_old_verified_decision(self) -> None:
        task_id = "repeated-task-new-escalation"
        escalation_dir = dashboard_main.ESCALATIONS_DIR / task_id
        escalation_dir.mkdir(parents=True)
        old_created_at = "2026-07-27T00:00:00+08:00"
        new_created_at = "2026-07-28T00:00:00+08:00"
        old_event_path = escalation_dir / "OLD.json"
        new_event_path = escalation_dir / "NEW.json"
        old_event_path.write_text(
            json.dumps(
                {
                    "task_id": task_id,
                    "reason": "old",
                    "created_at": old_created_at,
                    "status": "awaiting_josh",
                }
            ),
            encoding="utf-8",
        )
        new_event_path.write_text(
            json.dumps(
                {
                    "task_id": task_id,
                    "reason": "new",
                    "created_at": new_created_at,
                    "status": "awaiting_josh",
                }
            ),
            encoding="utf-8",
        )
        dashboard_main.ESCALATIONS_DIR.joinpath("ESCALATION_INDEX.jsonl").write_text(
            "\n".join(
                [
                    json.dumps(
                        {
                            "task_id": task_id,
                            "reason": "old",
                            "artifact_path": str(old_event_path),
                            "created_at": old_created_at,
                            "status": "awaiting_josh",
                        }
                    ),
                    json.dumps(
                        {
                            "task_id": task_id,
                            "reason": "new",
                            "artifact_path": str(new_event_path),
                            "created_at": new_created_at,
                            "status": "awaiting_josh",
                        }
                    ),
                ]
            )
            + "\n",
            encoding="utf-8",
        )
        (escalation_dir / "DECISION-old.json").write_text(
            json.dumps(
                {
                    "task_id": task_id,
                    "decision": "approve",
                    "decided_at": "2026-07-27T00:01:00+08:00",
                    "escalation_created_at": old_created_at,
                    "receipt": {},
                }
            ),
            encoding="utf-8",
        )
        (escalation_dir / "RESOLUTION.json").write_text(
            json.dumps(
                {
                    "task_id": task_id,
                    "resolution_type": "verified_owner_decision",
                    "josh_action_required": False,
                    "recommended_status": "resolved",
                }
            ),
            encoding="utf-8",
        )

        with patch.object(
            dashboard_main.AUTH,
            "verify_escalation_decision_record",
            return_value=True,
        ):
            response = self.client.get("/api/approvals")

        self.assertEqual(response.status_code, 200, response.text)
        payload = response.json()
        self.assertEqual(payload["total"], 1)
        self.assertEqual(payload["items"][0]["task_id"], task_id)
        self.assertEqual(payload["items"][0]["reason"], "new")
        self.assertEqual(payload["items"][0]["created_at"], new_created_at)
        self.assertFalse(payload["items"][0]["has_resolution"])

    def test_mutation_feature_flag_defaults_closed(self) -> None:
        auth = self.login()
        os.environ["AGENTOS_DASHBOARD_MUTATIONS_ENABLED"] = "0"
        try:
            response = self.post_layout(auth["csrf_token"])
        finally:
            os.environ["AGENTOS_DASHBOARD_MUTATIONS_ENABLED"] = "1"
        self.assertEqual(response.status_code, 403)
        self.assertFalse(dashboard_main.DECISIONS_LAYOUT.exists())

    @unittest.skipUnless(os.name == "nt", "NTFS ACL assertion is Windows-only")
    def test_owner_token_acl_has_no_broad_read_principal(self) -> None:
        for protected_path in (
            dashboard_main.AUTH.token_path,
            dashboard_main.AUTH.decision_receipt_key_path,
        ):
            completed = subprocess.run(
                ["icacls.exe", str(protected_path)],
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                check=True,
            )
            acl = completed.stdout.lower()
            self.assertIn(dashboard_main.AUTH.owner_identity.lower(), acl)
            for broad in ("everyone", "authenticated users", "builtin\\users", "users:("):
                self.assertNotIn(broad, acl, str(protected_path))


if __name__ == "__main__":
    unittest.main()

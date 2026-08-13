from __future__ import annotations

import asyncio
import base64
import importlib.util
import json
import os
import shutil
import subprocess
import tempfile
import types
import unittest
from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
PLUGIN_PATH = ROOT / "integrations" / "hermes_plugins" / "agentos-typed-dispatch" / "__init__.py"
PYTHON = os.environ.get("PYTHON", "python")


def load_plugin():
    spec = importlib.util.spec_from_file_location("agentos_typed_dispatch_test", PLUGIN_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class Adapter:
    def __init__(self):
        self.messages: list[tuple[str, str]] = []

    async def send_message(self, chat_id: str, text: str):
        self.messages.append((chat_id, text))


class TelegramConfirmationTests(unittest.TestCase):
    def setUp(self):
        self.plugin = load_plugin()
        self.temp = tempfile.TemporaryDirectory(prefix="agentos-telegram-confirm-")
        self.root = Path(self.temp.name)
        (self.root / "scripts").mkdir()
        shutil.copy2(ROOT / "scripts" / "decide_escalation.ps1", self.root / "scripts")
        shutil.copy2(ROOT / "scripts" / "escalation_receipt_validation.ps1", self.root / "scripts")
        auth_dir = self.root / "data" / "dashboard_auth"
        auth_dir.mkdir(parents=True)
        (auth_dir / "decision-receipt.key").write_text(
            base64.b64encode(bytes(range(32))).decode("ascii") + "\n", encoding="utf-8"
        )
        self.plugin.AGENTOS_ROOT = self.root
        self.plugin.ESCALATION_INDEX = self.root / "data" / "escalations" / "ESCALATION_INDEX.jsonl"
        self.plugin.TELEGRAM_CONFIRMATIONS_DIR = auth_dir / "telegram_confirmations"
        self.plugin.DECISION_RECEIPT_KEY = auth_dir / "decision-receipt.key"
        self.plugin.DECIDE_ESCALATION = self.root / "scripts" / "decide_escalation.ps1"
        self.plugin._restrict_file_to_owner = mock.Mock()
        os.environ["AGENTOS_OWNER_TELEGRAM_ID"] = "123456789"
        os.environ["AGENTOS_DASHBOARD_AUTH_DIR"] = str(auth_dir)

    def tearDown(self):
        os.environ.pop("AGENTOS_OWNER_TELEGRAM_ID", None)
        os.environ.pop("AGENTOS_DASHBOARD_AUTH_DIR", None)
        self.temp.cleanup()

    def make_escalation(self, task_id: str, summary: str = "summary") -> Path:
        escalation_dir = self.root / "data" / "escalations" / task_id
        escalation_dir.mkdir(parents=True, exist_ok=True)
        artifact = escalation_dir / "EVENT.json"
        artifact.write_text(json.dumps({
            "task_id": task_id,
            "created_at": "2026-07-21T10:00:00+08:00",
            "summary_for_josh": summary,
        }), encoding="utf-8")
        self.plugin.ESCALATION_INDEX.parent.mkdir(parents=True, exist_ok=True)
        with self.plugin.ESCALATION_INDEX.open("a", encoding="utf-8") as stream:
            stream.write(json.dumps({
                "task_id": task_id, "reason": "fixture_reason", "status": "awaiting_josh",
                "created_at": "2026-07-21T10:00:00+08:00", "artifact_path": str(artifact),
            }) + "\n")
        return escalation_dir

    def event(self, text: str, chat_id: str):
        return types.SimpleNamespace(
            text=text,
            source=types.SimpleNamespace(platform="telegram", chat_id=chat_id, message_id="m1"),
        )

    def test_wrong_or_missing_owner_falls_through_without_escalation_reply(self):
        self.make_escalation("secret-task", "do not leak")
        adapter = Adapter()
        gateway = types.SimpleNamespace(adapters={"telegram": adapter})

        async def fake_chat(gateway_arg, event_arg, text_arg):
            await self.plugin._send_reply(gateway_arg, event_arg, "ordinary chat")

        for command in ("[待核准]", "[確認 secret-task approve 123456]"):
            for owner_value, chat_id in (("", "123456789"), ("123456789", "999")):
                if owner_value:
                    os.environ["AGENTOS_OWNER_TELEGRAM_ID"] = owner_value
                else:
                    os.environ.pop("AGENTOS_OWNER_TELEGRAM_ID", None)
                adapter.messages.clear()
                with mock.patch.object(self.plugin, "_complete_lite_chat", fake_chat):
                    result = asyncio.run(self.plugin._pre_gateway_dispatch_async(
                        event=self.event(command, chat_id), gateway=gateway
                    ))
                self.assertEqual(result["reason"], "hermes_lite_chat:groq_no_tools")
                self.assertEqual(adapter.messages, [(chat_id, "ordinary chat")])
                self.assertNotIn("secret-task", adapter.messages[0][1])

    def test_pending_list_generates_unique_owner_protected_codes(self):
        self.make_escalation("task-one", "one")
        self.make_escalation("task-two", "two")
        reply = self.plugin._create_pending_approval_reply()
        first = json.loads((self.plugin.TELEGRAM_CONFIRMATIONS_DIR / "task-one.json").read_text(encoding="utf-8"))
        second = json.loads((self.plugin.TELEGRAM_CONFIRMATIONS_DIR / "task-two.json").read_text(encoding="utf-8"))
        self.assertIn("task_id=task-one", reply)
        self.assertIn("summary_for_josh=two", reply)
        self.assertRegex(first["code"], r"^\d{6}$")
        self.assertNotEqual(first["code"], second["code"])
        self.assertEqual(self.plugin._restrict_file_to_owner.call_count, 4)

    def test_bad_expired_and_consumed_codes_are_rejected(self):
        self.make_escalation("task-codes")
        self.plugin._create_pending_approval_reply()
        path = self.plugin.TELEGRAM_CONFIRMATIONS_DIR / "task-codes.json"
        payload = json.loads(path.read_text(encoding="utf-8"))
        ok, output = self.plugin._confirm_approval("task-codes", "delete", payload["code"], "123456789")
        self.assertFalse(ok)
        self.assertEqual(output, "reason=decision_invalid")
        ok, output = self.plugin._confirm_approval("task-codes", "approve", "000000", "123456789")
        self.assertFalse(ok)
        self.assertEqual(output, "reason=confirmation_code_invalid")
        payload["expires_at"] = self.plugin._utc_iso(self.plugin._utc_now() - timedelta(seconds=1))
        self.plugin._write_owner_json(path, payload)
        ok, output = self.plugin._confirm_approval("task-codes", "approve", payload["code"], "123456789")
        self.assertFalse(ok)
        self.assertEqual(output, "reason=confirmation_expired")
        payload["expires_at"] = self.plugin._utc_iso(self.plugin._utc_now() + timedelta(minutes=5))
        payload["consumed"] = True
        self.plugin._write_owner_json(path, payload)
        ok, output = self.plugin._confirm_approval("task-codes", "approve", payload["code"], "123456789")
        self.assertFalse(ok)
        self.assertEqual(output, "reason=confirmation_already_consumed")

    def test_e2e_receipt_existing_validators_and_decision_outputs(self):
        escalation_dir = self.make_escalation("task-e2e")
        self.plugin._create_pending_approval_reply()
        confirmation = json.loads(
            (self.plugin.TELEGRAM_CONFIRMATIONS_DIR / "task-e2e.json").read_text(encoding="utf-8")
        )
        ok, output = self.plugin._confirm_approval(
            "task-e2e", "approve", confirmation["code"], "123456789"
        )
        self.assertTrue(ok, output)
        decision_path = next(escalation_dir.glob("DECISION-*.json"))
        resolution = json.loads((escalation_dir / "RESOLUTION.json").read_text(encoding="utf-8"))
        decision = json.loads(decision_path.read_text(encoding="utf-8"))
        self.assertFalse(resolution["josh_action_required"])
        self.assertEqual(resolution["authentication_method"], "telegram_one_time_confirmation")
        self.assertEqual(decision["receipt"]["type"], "telegram_one_time_confirmation")

        validator = self.root / "scripts" / "escalation_receipt_validation.ps1"
        command = (
            f". '{validator}'; "
            f"$d=[IO.File]::ReadAllText('{decision_path}',[Text.Encoding]::UTF8)|ConvertFrom-Json; "
            f"$receipt=Test-AgentOSEscalationReceipt -AgentOSRoot '{self.root}' "
            "-TaskId ([string]$d.task_id) -Decision ([string]$d.decision) "
            "-ActorId ([string]$d.decided_by) -AuthMethod ([string]$d.authentication_method) "
            "-RequestId ([string]$d.request_id) -ReceiptPath ([string]$d.receipt.path); "
            f"$record=Test-AgentOSEscalationDecisionRecord -AgentOSRoot '{self.root}' -DecisionRecord $d; "
            "[ordered]@{ReceiptValid=$receipt.Valid;ReceiptReason=$receipt.Reason;RecordValid=$record.Valid;RecordReason=$record.Reason}|ConvertTo-Json -Compress"
        )
        completed = subprocess.run(
            ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command],
            capture_output=True, text=True, encoding="utf-8", errors="replace", check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)
        validation = json.loads(completed.stdout.strip())
        self.assertTrue(validation["ReceiptValid"], validation)
        self.assertEqual(validation["ReceiptReason"], "verified")
        self.assertTrue(validation["RecordValid"], validation)
        self.assertEqual(validation["RecordReason"], "verified")

        ok, replay = self.plugin._confirm_approval(
            "task-e2e", "approve", confirmation["code"], "123456789"
        )
        self.assertFalse(ok)
        self.assertEqual(replay, "reason=confirmation_already_consumed")

    def test_parallel_confirmation_claim_allows_only_one_consumer(self):
        self.make_escalation("task-race")
        self.plugin._create_pending_approval_reply()
        confirmation = json.loads(
            (self.plugin.TELEGRAM_CONFIRMATIONS_DIR / "task-race.json").read_text(encoding="utf-8")
        )

        def attempt():
            return self.plugin._confirm_approval(
                "task-race", "approve", confirmation["code"], "123456789"
            )

        with mock.patch.object(self.plugin, "_run_process", return_value=(True, "escalation_decision_status=recorded")):
            with ThreadPoolExecutor(max_workers=2) as executor:
                results = list(executor.map(lambda _: attempt(), range(2)))
        self.assertEqual(sum(1 for ok, _ in results if ok), 1, results)
        self.assertEqual(sum(1 for ok, _ in results if not ok), 1, results)
        self.assertIn(
            next(output for ok, output in results if not ok),
            {"reason=confirmation_busy", "reason=confirmation_already_consumed"},
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)

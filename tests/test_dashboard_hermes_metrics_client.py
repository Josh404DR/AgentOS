from __future__ import annotations

import os
import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

import httpx


ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "dashboard" / "backend"
sys.path.insert(0, str(BACKEND))

import hermes_metrics_client as metrics_client  # noqa: E402
import main as dashboard_main  # noqa: E402


class HermesMetricsClientTests(unittest.TestCase):
    def setUp(self) -> None:
        self.environment = patch.dict(
            os.environ,
            {
                "API_SERVER_KEY": "unit-test-secret",
                "API_SERVER_HOST": "127.0.0.1",
                "API_SERVER_PORT": "8642",
            },
            clear=False,
        )
        self.environment.start()

    def tearDown(self) -> None:
        self.environment.stop()

    @staticmethod
    def response(status: int, payload=None, text: str | None = None):
        request = httpx.Request("GET", "http://127.0.0.1:8642/test")
        if text is not None:
            return httpx.Response(status, text=text, request=request)
        return httpx.Response(status, json=payload, request=request)

    @staticmethod
    def usage_envelope() -> dict:
        return {
            "schema_version": "1",
            "generated_at": "2026-07-29T12:34:56.000000Z",
            "total": {"session_count": 1},
            "window_5h": {"session_count": 1},
            "window_7d": {"session_count": 1},
            "recent_sessions": [{"id": "session"}],
            "current_model": "gpt-5",
        }

    @patch("hermes_metrics_client.httpx.get")
    def test_usage_200_preserves_frontend_dto_and_uses_two_second_timeout(self, get):
        get.return_value = self.response(200, self.usage_envelope())

        result = dashboard_main._read_db_usage()

        self.assertEqual(
            set(result),
            {
                "total",
                "window_5h",
                "window_7d",
                "recent_sessions",
                "current_model",
            },
        )
        self.assertNotIn("schema_version", result)
        self.assertNotIn("generated_at", result)
        self.assertNotIn("unit-test-secret", repr(result))
        self.assertEqual(
            get.call_args.kwargs["timeout"],
            metrics_client.REQUEST_TIMEOUT_SECONDS,
        )
        self.assertEqual(metrics_client.REQUEST_TIMEOUT_SECONDS, 2.0)
        self.assertEqual(get.call_count, 1)

    @patch("hermes_metrics_client.httpx.get")
    def test_401_and_503_are_explicitly_unavailable_without_key_leak(self, get):
        for status in (401, 503):
            with self.subTest(status=status):
                get.return_value = self.response(
                    status,
                    {
                        "error": {
                            "code": "private",
                            "message": "unit-test-secret",
                            "retryable": True,
                        }
                    },
                )
                self.assertEqual(
                    dashboard_main._read_db_usage(),
                    {"error": "usage database unavailable"},
                )
                self.assertEqual(
                    dashboard_main._context_window_pct()["note"],
                    "usage database unavailable",
                )

    @patch("hermes_metrics_client.httpx.get")
    def test_timeout_has_no_retry_and_returns_unavailable_note(self, get):
        get.side_effect = httpx.ReadTimeout("bounded timeout")

        self.assertEqual(
            dashboard_main._read_db_usage(),
            {"error": "usage database unavailable"},
        )
        self.assertEqual(get.call_count, 1)

    @patch("hermes_metrics_client.httpx.get")
    def test_malformed_json_returns_existing_query_failure_semantics(self, get):
        get.return_value = self.response(200, text="<not-json>")

        self.assertEqual(
            dashboard_main._read_db_usage(),
            {"error": "usage query failed"},
        )
        self.assertEqual(
            dashboard_main._context_window_pct()["note"],
            "usage query failed",
        )

    @patch("hermes_metrics_client.httpx.get")
    def test_500_returns_existing_query_failure_semantics(self, get):
        get.return_value = self.response(
            500,
            {
                "error": {
                    "code": "internal_error",
                    "message": "unit-test-secret internal detail",
                    "retryable": False,
                }
            },
        )

        result = dashboard_main._read_db_usage()

        self.assertEqual(result, {"error": "usage query failed"})
        self.assertNotIn("unit-test-secret", repr(result))

    @patch("main.fetch_context_window_source")
    def test_context_notes_and_known_model_calculation_are_unchanged(self, fetch):
        fetch.return_value = None
        self.assertEqual(
            dashboard_main._context_window_pct(),
            {
                "pct": None,
                "used": None,
                "total": None,
                "model": None,
                "note": "no recorded session",
            },
        )

        fetch.return_value = {
            "model": "private-model",
            "input_tokens": 10,
            "output_tokens": 20,
            "cache_read_tokens": 30,
            "cache_write_tokens": 999,
        }
        self.assertEqual(
            dashboard_main._context_window_pct(),
            {
                "pct": None,
                "used": 60,
                "total": None,
                "model": "private-model",
                "note": "unknown model context limit",
            },
        )

        fetch.return_value = {
            "model": "gpt-5",
            "input_tokens": 64_000,
            "output_tokens": 32_000,
            "cache_read_tokens": 32_000,
            "cache_write_tokens": 50_000,
        }
        self.assertEqual(
            dashboard_main._context_window_pct(),
            {
                "pct": 100.0,
                "used": 128_000,
                "total": 128_000,
                "input": 64_000,
                "output": 32_000,
                "cache": 32_000,
                "model": "gpt-5",
                "note": "last session",
            },
        )

    @patch("hermes_metrics_client.httpx.get")
    def test_missing_key_fails_closed_before_request(self, get):
        with patch.dict(os.environ, {"API_SERVER_KEY": ""}, clear=False):
            self.assertEqual(
                dashboard_main._read_db_usage(),
                {"error": "usage database unavailable"},
            )
        get.assert_not_called()

    @patch("hermes_metrics_client.httpx.get")
    def test_non_loopback_host_fails_closed_before_key_is_sent(self, get):
        for host in ("0.0.0.0", "::", "[::]", "metrics.example.invalid", ""):
            with self.subTest(host=host), patch.dict(
                os.environ,
                {"API_SERVER_HOST": host},
                clear=False,
            ):
                self.assertEqual(
                    dashboard_main._read_db_usage(),
                    {"error": "usage database unavailable"},
                )
        get.assert_not_called()

    @patch("hermes_metrics_client.httpx.get")
    def test_rejected_host_is_validated_before_key_is_read(self, get):
        for host in ("0.0.0.0", "::", "[::]", "metrics.example.invalid", ""):
            accessed = []

            def read_environment(name, default=None):
                accessed.append(name)
                return host if name == "API_SERVER_HOST" else "unit-test-secret"

            with self.subTest(host=host), patch(
                "hermes_metrics_client.os.environ.get",
                side_effect=read_environment,
            ):
                with self.assertRaises(metrics_client.HermesMetricsUnavailable):
                    metrics_client._request_json("/v1/metrics/usage")
                self.assertEqual(accessed, ["API_SERVER_HOST"])

        get.assert_not_called()

    @patch("hermes_metrics_client.httpx.get")
    def test_only_approved_loopback_hosts_are_allowed(self, get):
        get.return_value = self.response(200, self.usage_envelope())

        for host, expected_host in (
            ("127.0.0.1", "127.0.0.1"),
            ("LOCALHOST", "localhost"),
            ("::1", "[::1]"),
        ):
            with self.subTest(host=host), patch.dict(
                os.environ,
                {"API_SERVER_HOST": host},
                clear=False,
            ):
                dashboard_main._read_db_usage()
                self.assertIn(expected_host, str(get.call_args.args[0]))

        self.assertEqual(get.call_count, 3)

    def test_client_does_not_log_or_persist_bearer_key(self):
        source = (BACKEND / "hermes_metrics_client.py").read_text(encoding="utf-8")
        self.assertNotIn("logging", source)
        self.assertNotIn("unit-test-secret", source)
        self.assertNotIn("retry", source.lower().replace("no retry", ""))


if __name__ == "__main__":
    unittest.main()

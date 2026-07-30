"""Small fail-closed client for the Hermes-owned metrics API."""

from __future__ import annotations

import os
from typing import Any

import httpx

try:
    import winreg
except ImportError:  # pragma: no cover - Windows is the deployed platform.
    winreg = None


REQUEST_TIMEOUT_SECONDS = 2.0
_USAGE_PATH = "/v1/metrics/usage"
_CONTEXT_PATH = "/v1/metrics/context-window-source"


class HermesMetricsUnavailable(RuntimeError):
    """The authenticated Hermes metrics service is currently unavailable."""


class HermesMetricsResponseError(RuntimeError):
    """Hermes returned an invalid or unprocessable metrics response."""


def _setting(name: str, default: str = "") -> str:
    value = os.environ.get(name)
    if value is not None:
        return value
    if winreg is not None:
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as key:
                value, _ = winreg.QueryValueEx(key, name)
                if isinstance(value, str):
                    return value
        except OSError:
            pass
    return default


def _base_url() -> str:
    host = _setting("API_SERVER_HOST", "127.0.0.1").strip().lower()
    if host not in {"127.0.0.1", "localhost", "::1"}:
        raise HermesMetricsUnavailable(
            "Hermes metrics host must be loopback"
        )
    port = _setting("API_SERVER_PORT", "8642").strip() or "8642"
    url_host = "[::1]" if host == "::1" else host
    return f"http://{url_host}:{port}"


def _request_json(path: str) -> dict[str, Any]:
    base_url = _base_url()
    api_key = _setting("API_SERVER_KEY")
    if not api_key:
        raise HermesMetricsUnavailable("Hermes metrics credentials unavailable")

    try:
        response = httpx.get(
            f"{base_url}{path}",
            headers={"Authorization": f"Bearer {api_key}"},
            timeout=REQUEST_TIMEOUT_SECONDS,
        )
    except (httpx.TimeoutException, httpx.RequestError) as exc:
        raise HermesMetricsUnavailable("Hermes metrics service unavailable") from exc

    if response.status_code in {401, 503}:
        raise HermesMetricsUnavailable("Hermes metrics service unavailable")
    if response.status_code != 200:
        raise HermesMetricsResponseError("Hermes metrics request failed")

    try:
        payload = response.json()
    except (ValueError, TypeError) as exc:
        raise HermesMetricsResponseError("Hermes metrics response is not JSON") from exc
    if not isinstance(payload, dict):
        raise HermesMetricsResponseError("Hermes metrics response must be an object")
    if payload.get("schema_version") != "1":
        raise HermesMetricsResponseError("Unsupported Hermes metrics schema")
    if not isinstance(payload.get("generated_at"), str):
        raise HermesMetricsResponseError("Hermes metrics timestamp missing")
    return payload


def fetch_usage_metrics() -> dict[str, Any]:
    """Fetch the B2 usage envelope once, with no retry."""
    payload = _request_json(_USAGE_PATH)
    required = {
        "total": dict,
        "window_5h": dict,
        "window_7d": dict,
        "recent_sessions": list,
    }
    if any(not isinstance(payload.get(key), kind) for key, kind in required.items()):
        raise HermesMetricsResponseError("Hermes usage response shape invalid")
    if "current_model" not in payload:
        raise HermesMetricsResponseError("Hermes usage model field missing")
    return payload


def fetch_context_window_source() -> dict[str, Any] | None:
    """Fetch the latest-session source DTO once, with no retry."""
    payload = _request_json(_CONTEXT_PATH)
    if "latest_session" not in payload:
        raise HermesMetricsResponseError("Hermes context response shape invalid")
    latest_session = payload["latest_session"]
    if latest_session is not None and not isinstance(latest_session, dict):
        raise HermesMetricsResponseError("Hermes latest session must be an object")
    return latest_session

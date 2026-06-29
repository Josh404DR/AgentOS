"""AgentOS deterministic dispatch and background Threads intake for Hermes."""

from __future__ import annotations

import asyncio
import logging
import re
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Any, Optional

logger = logging.getLogger(__name__)

PLUGIN_VERSION = "0.2.1"
AGENTOS_ROOT = Path(r"E:\AgentOS")
ENTRYPOINT = AGENTOS_ROOT / "scripts" / "telegram_typed_dispatch_entry.ps1"
THREADS_PIPELINE = AGENTOS_ROOT / "scripts" / "threads_url_intake.ps1"
TYPE_PATTERN = re.compile(r"\[\s*TYPE\s*:\s*([A-Z0-9_\-]+)\s*\]", re.IGNORECASE)
THREADS_URL_PATTERN = re.compile(
    r"https://(?:www\.)?threads\.(?:com|net)/[^\s<>\]]+",
    re.IGNORECASE,
)
MAX_REPLY_CHARS = 3200
_background_tasks: set[asyncio.Task] = set()


def _text_from_event(event: Any) -> str:
    text = getattr(event, "text", "")
    return text if isinstance(text, str) else ""


def _source_value(source: Any, field: str, default: str = "unknown") -> str:
    value = getattr(source, field, None)
    if hasattr(value, "value"):
        value = value.value
    if value is None or value == "":
        return default
    return str(value)


def _build_dispatch_id(source: Any) -> str:
    platform = _source_value(source, "platform", "telegram")
    chat = _source_value(source, "chat_id", "chat")
    message_id = _source_value(source, "message_id", "msg")
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    safe_chat = re.sub(r"[^A-Za-z0-9_.-]+", "-", chat)[-40:]
    safe_message = re.sub(r"[^A-Za-z0-9_.-]+", "-", message_id)[-40:]
    return f"telegram-{platform}-{safe_chat}-{safe_message}-{stamp}"


def _extract_threads_url(text: str) -> Optional[str]:
    match = THREADS_URL_PATTERN.search(text)
    if not match:
        return None
    return match.group(0).rstrip(".,;:!?)]}>\"'")


def _is_threads_intake(text: str) -> tuple[bool, Optional[str]]:
    url = _extract_threads_url(text)
    if not url:
        return False, None
    type_match = TYPE_PATTERN.search(text)
    if type_match and type_match.group(1).upper() != "URL_INTAKE":
        return False, None
    return True, url


def _summarize_output(raw: str) -> str:
    keep = []
    for line in raw.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        lower = stripped.lower()
        if lower.startswith(
            (
                "dispatch_id=",
                "route_to=",
                "dispatch_status=",
                "approval_required=",
                "models_invoked=",
                "external_services_invoked=",
                "output_dir=",
                "reason=",
            )
        ):
            keep.append(stripped)
    if not keep:
        keep = ["dispatch_status=completed_no_key_value_output"]
    text = "AgentOS typed dispatch accepted.\n" + "\n".join(keep)
    return text[:MAX_REPLY_CHARS]


def _run_process(cmd: list[str], timeout: int) -> tuple[bool, str]:
    try:
        result = subprocess.run(
            cmd,
            cwd=str(AGENTOS_ROOT),
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        return False, "pipeline_status=blocked\nreason=timeout"
    except Exception as exc:
        return False, f"pipeline_status=blocked\nreason=exception:{type(exc).__name__}"

    combined = "\n".join(part for part in (result.stdout, result.stderr) if part)
    if result.returncode != 0:
        return False, f"pipeline_status=blocked\nreason=exit_{result.returncode}\n{combined}"
    return True, combined


def _run_dispatch(message_text: str, dispatch_id: str) -> tuple[bool, str]:
    if not ENTRYPOINT.exists():
        return False, "dispatch_status=blocked\nreason=missing_entrypoint"
    return _run_process(
        [
            "powershell.exe",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(ENTRYPOINT),
            "-MessageText",
            message_text,
            "-DispatchId",
            dispatch_id,
        ],
        timeout=45,
    )


def _run_threads_pipeline(url: str, message_text: str, dispatch_id: str) -> tuple[bool, str]:
    if not THREADS_PIPELINE.exists():
        return False, "pipeline_status=blocked\nreason=missing_threads_pipeline"
    return _run_process(
        [
            "powershell.exe",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(THREADS_PIPELINE),
            "-Url",
            url,
            "-DispatchId",
            dispatch_id,
            "-RawMessage",
            message_text,
        ],
        timeout=420,
    )


def _output_field(raw: str, key: str) -> str:
    prefix = f"{key}="
    for line in reversed(raw.splitlines()):
        stripped = line.strip()
        if stripped.lower().startswith(prefix.lower()):
            return stripped[len(prefix) :].strip()
    return ""


def _threads_completion_reply(ok: bool, raw: str) -> str:
    dispatch_id = _output_field(raw, "dispatch_id")
    fetch_status = _output_field(raw, "fetch_status")
    result_path = _output_field(raw, "result_path")
    status = "completed" if ok else "blocked"
    lines = [
        "AgentOS Threads intake finished.",
        f"pipeline_status={status}",
        f"dispatch_id={dispatch_id or 'unknown'}",
        f"fetch_status={fetch_status or 'unknown'}",
    ]
    if result_path:
        lines.append(f"result_path={result_path}")
        try:
            result = Path(result_path).read_text(encoding="utf-8").strip()
            if result:
                lines.extend(["", result])
        except OSError:
            lines.append("result_read_status=failed")
    if not ok:
        reason = _output_field(raw, "reason")
        lines.append(f"reason={reason or 'pipeline_failed'}")
    reply = "\n".join(lines)
    if len(reply) > MAX_REPLY_CHARS:
        reply = reply[: MAX_REPLY_CHARS - 20] + "\n...truncated"
    return reply


async def _send_reply(gateway: Any, event: Any, text: str) -> None:
    source = getattr(event, "source", None)
    if source is None:
        return
    platform = getattr(source, "platform", None)
    platform_key = getattr(platform, "value", platform)
    adapters = getattr(gateway, "adapters", {}) or {}
    adapter = adapters.get(platform_key) or adapters.get(platform)
    if adapter is None:
        return

    candidates = [
        ("send_message", (source, text), {}),
        ("send", (source, text), {}),
        ("send_message", (_source_value(source, "chat_id"), text), {}),
        ("send", (_source_value(source, "chat_id"), text), {}),
    ]
    for method_name, args, kwargs in candidates:
        method = getattr(adapter, method_name, None)
        if method is None:
            continue
        try:
            maybe = method(*args, **kwargs)
            if asyncio.iscoroutine(maybe):
                await maybe
            return
        except TypeError:
            continue
        except Exception as exc:
            logger.debug("AgentOS reply failed via %s: %s", method_name, exc)
            return


async def _complete_threads_intake(
    gateway: Any,
    event: Any,
    url: str,
    text: str,
    dispatch_id: str,
) -> None:
    ok, output = await asyncio.to_thread(
        _run_threads_pipeline,
        url,
        text,
        dispatch_id,
    )
    await _send_reply(gateway, event, _threads_completion_reply(ok, output))
    if ok:
        logger.info("AgentOS Threads intake completed: %s", dispatch_id)
    else:
        logger.warning("AgentOS Threads intake blocked: %s output=%s", dispatch_id, output[:500])


def _retain_background_task(task: asyncio.Task) -> None:
    _background_tasks.add(task)
    task.add_done_callback(_background_tasks.discard)


async def _pre_gateway_dispatch(
    event: Any = None,
    gateway: Any = None,
    **_: Any,
) -> Optional[dict]:
    text = _text_from_event(event)
    if not text:
        return {"action": "allow"}

    source = getattr(event, "source", None)
    is_threads, threads_url = _is_threads_intake(text)
    if is_threads and threads_url:
        dispatch_id = _build_dispatch_id(source)
        if gateway is not None:
            await _send_reply(
                gateway,
                event,
                "\n".join(
                    [
                        "AgentOS Threads intake accepted.",
                        f"dispatch_id={dispatch_id}",
                        "pipeline_status=processing",
                        "route_to=Codex",
                    ]
                ),
            )
            task = asyncio.create_task(
                _complete_threads_intake(
                    gateway,
                    event,
                    threads_url,
                    text,
                    dispatch_id,
                )
            )
            _retain_background_task(task)
        return {"action": "skip", "reason": f"agentos_threads_intake:{dispatch_id}"}

    if not TYPE_PATTERN.search(text):
        return {"action": "allow"}

    dispatch_id = _build_dispatch_id(source)
    ok, output = await asyncio.to_thread(_run_dispatch, text, dispatch_id)
    if gateway is not None:
        await _send_reply(gateway, event, _summarize_output(output))
    reason = f"agentos_typed_dispatch:{dispatch_id}"
    if not ok:
        logger.warning("AgentOS typed dispatch blocked: %s output=%s", reason, output[:500])
    else:
        logger.info("AgentOS typed dispatch handled: %s", reason)
    return {"action": "skip", "reason": reason}


def register(ctx) -> None:
    ctx.register_hook("pre_gateway_dispatch", _pre_gateway_dispatch)
    logger.info(
        "AgentOS typed dispatch plugin v%s registered from %s",
        PLUGIN_VERSION,
        __file__,
    )

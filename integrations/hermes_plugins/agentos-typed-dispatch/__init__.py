"""AgentOS low-cost chat, deterministic dispatch, and URL intake for Hermes."""

from __future__ import annotations

import asyncio
import json
import logging
import os
import re
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Any, Optional

logger = logging.getLogger(__name__)

PLUGIN_VERSION = "0.7.1"
PLUGIN_MODE = os.getenv("AGENTOS_PLUGIN_MODE", "task_dispatch").strip().lower()
AGENTOS_ROOT = Path(r"E:\AgentOS")
ENTRYPOINT = AGENTOS_ROOT / "scripts" / "telegram_typed_dispatch_entry.ps1"
THREADS_PIPELINE = AGENTOS_ROOT / "scripts" / "threads_url_intake.ps1"
FREE_MODEL_WINDOW = AGENTOS_ROOT / "scripts" / "free_model_window.ps1"
URL_TASK_PACKET = AGENTOS_ROOT / "scripts" / "url_intake_task_packet.ps1"
URL_WORKER = AGENTOS_ROOT / "scripts" / "url_intake_worker.ps1"
KNOWLEDGE_PUBLISHER = AGENTOS_ROOT / "scripts" / "publish_url_knowledge.ps1"
LOCAL_FILE_WORKER = AGENTOS_ROOT / "scripts" / "local_file_task_worker.ps1"
WORKFLOW_SUPERVISOR = AGENTOS_ROOT / "scripts" / "workflow_supervisor.ps1"
TYPE_PATTERN = re.compile(r"\[\s*TYPE\s*:\s*([A-Z0-9_\-]+)\s*\]", re.IGNORECASE)
URL_PATTERN = re.compile(r"https?://[^\s<>\]]+", re.IGNORECASE)
THREADS_URL_PATTERN = re.compile(
    r"https://(?:www\.)?threads\.(?:com|net)/[^\s<>\]]+",
    re.IGNORECASE,
)
CODEX_NATURAL_PATTERN = re.compile(
    r"(?:請|交給|讓)\s*Codex|Codex\s*(?:讀取|處理|檢查|執行|修改|更新)",
    re.IGNORECASE,
)
WORK_TASK_PATTERN = re.compile(
    r"(?:請執行\s*AgentOS\s*工單)"
    r"|(?:請對.{0,80}?(?:進行|執行|做).{0,12}?(?:稽核|盤點|診斷|分析|驗證|整理|收斂))"
    r"|(?:(?:請|幫我|麻煩|需要|希望).{0,32}"
    r"(?:建立|新增|修改|更新|修正|整理|分析|規劃|實作|執行|驗證|部署|刪除|上傳|同步|重啟|檢查|稽核|盤點|診斷|收斂))"
    r"|^(?:建立|新增|修改|更新|修正|整理|分析|規劃|實作|執行|驗證|部署|刪除|上傳|同步|重啟|檢查|稽核|盤點|診斷|收斂)",
    re.IGNORECASE,
)
LOCAL_FILE_PATTERN = re.compile(
    r"(?:[A-Z]:\\[^\r\n<>:\"|?*]+\.(?:md|txt)|"
    r"(?:prompts|docs|data|scripts|config|agents|workflows)[\\/]"
    r"[^\r\n<>:\"|?*]+\.(?:md|txt))",
    re.IGNORECASE,
)
# Fixed-prefix shortcuts from hermes_intake_menu.md
WORK_ORDER_PATTERN = re.compile(r"^\s*\[工單\]", re.IGNORECASE)
RAW_INTAKE_PATTERN = re.compile(r"^\s*\[成形\]", re.IGNORECASE)
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


def _extract_url(text: str) -> Optional[str]:
    match = URL_PATTERN.search(text)
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
            "-TelegramHookInvoked",
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


def _run_lite_chat(message_text: str) -> tuple[bool, str]:
    if not FREE_MODEL_WINDOW.exists():
        return False, "lite_chat_status=blocked\nreason=missing_free_model_window"
    return _run_process(
        [
            "powershell.exe",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(FREE_MODEL_WINDOW),
            "-Provider",
            "groq",
            "-Message",
            message_text,
            "-MaxTokens",
            "180",
            "-Invoke",
        ],
        timeout=60,
    )


def _run_local_file_task(message_text: str, dispatch_id: str) -> tuple[bool, str]:
    if not LOCAL_FILE_WORKER.exists():
        return False, "local_file_task_status=blocked\nreason=missing_worker"
    return _run_process(
        [
            "powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass",
            "-File", str(LOCAL_FILE_WORKER),
            "-MessageText", message_text,
            "-DispatchId", dispatch_id,
        ],
        timeout=720,
    )


def _run_raw_intake(message_text: str, dispatch_id: str) -> tuple[bool, str]:
    """Create a raw intake draft with status: awaiting_josh_approval.

    Does not invoke any AI model or script.  The draft is the artefact that
    a future Claude shaping session (36_RAW_INTAKE.md §2) will work from.
    """
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    is_fixture = "is_fixture" in message_text.lower()
    prefix = "fixture" if is_fixture else "draft"
    safe_id = re.sub(r"[^A-Za-z0-9_.-]+", "-", dispatch_id)[:40]
    draft_dir = AGENTOS_ROOT / "data" / "tasks" / f"{prefix}-{stamp}-{safe_id}"
    try:
        draft_dir.mkdir(parents=True, exist_ok=True)
        task_path = draft_dir / "TASK.md"
        draft_id = draft_dir.name
        task_path.write_text(
            "\n".join([
                "status: awaiting_josh_approval",
                f"draft_created_at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
                f"dispatch_id: {dispatch_id}",
                f"draft_id: {draft_id}",
                f"is_fixture: {'true' if is_fixture else 'false'}",
                "intake_type: raw_intake",
                "shaping_ref: docs\\claude_ops\\36_RAW_INTAKE.md",
                "",
                "## 原始毛坯（Josh 原文）",
                "",
                message_text,
                "",
                "## 待成形步驟",
                "",
                "依 docs\\claude_ops\\36_RAW_INTAKE.md §2 由 Claude 執行五步成形後回報。",
                "Josh 明確核准前不得進入實作。",
            ]),
            encoding="utf-8",
        )
        return True, (
            f"task_intake_status=raw_intake_accepted\n"
            f"draft_path={task_path}\n"
            f"status=awaiting_josh_approval\n"
            f"is_fixture={'true' if is_fixture else 'false'}\n"
            f"models_invoked=false\n"
            f"dispatch_id={dispatch_id}"
        )
    except OSError as exc:
        return False, f"task_intake_status=blocked\nreason=draft_write_failed:{exc}"


def _run_workflow_supervisor(dispatch_id: str) -> tuple[bool, str]:
    if not WORKFLOW_SUPERVISOR.exists():
        return False, "supervisor_status=blocked\nreason=missing_supervisor"
    return _run_process(
        [
            "powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass",
            "-File", str(WORKFLOW_SUPERVISOR),
            "-RootDispatchId", dispatch_id,
        ],
        timeout=90,
    )


def _run_generic_url_pipeline(url: str, message_text: str, dispatch_id: str) -> tuple[bool, str]:
    typed_text = f"[TYPE: URL_INTAKE]\nURL: {url}\nOriginal message:\n{message_text}"
    ok, dispatch_output = _run_dispatch(typed_text, dispatch_id)
    if not ok:
        return False, dispatch_output
    if not URL_TASK_PACKET.exists():
        return False, "pipeline_status=blocked\nreason=missing_url_task_packet"
    routing_path = (
        AGENTOS_ROOT
        / "data"
        / "routing_decisions"
        / dispatch_id
        / "ROUTING_DECISION.md"
    )
    ok, packet_output = _run_process(
        [
            "powershell.exe",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(URL_TASK_PACKET),
            "-DispatchId",
            dispatch_id,
            "-RoutingDecisionPath",
            str(routing_path),
            "-RawMessage",
            message_text,
            "-Urls",
            url,
        ],
        timeout=45,
    )
    combined = "\n".join((dispatch_output, packet_output))
    if not ok:
        return False, combined
    task_path = _output_field(packet_output, "task_path")
    if not task_path:
        return False, combined + "\npipeline_status=blocked\nreason=task_path_missing"
    if not URL_WORKER.exists():
        return False, combined + "\npipeline_status=blocked\nreason=missing_url_worker"
    ok, worker_output = _run_process(
        [
            "powershell.exe",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(URL_WORKER),
            "-TaskPath",
            task_path,
        ],
        timeout=240,
    )
    output = "\n".join((combined, worker_output))
    if not ok:
        return False, output
    return _publish_knowledge(output)


def _publish_knowledge(pipeline_output: str) -> tuple[bool, str]:
    task_path = _output_field(pipeline_output, "task_path")
    if not task_path or not KNOWLEDGE_PUBLISHER.exists():
        return False, pipeline_output + "\nreason=knowledge_publisher_unavailable"
    ok, publish_output = _run_process(
        [
            "powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass",
            "-File", str(KNOWLEDGE_PUBLISHER), "-TaskPath", task_path,
        ],
        timeout=900,
    )
    return ok, "\n".join((pipeline_output, publish_output))


def _decode_lite_response(raw: str) -> str:
    import base64

    match = re.search(
        r"(?ms)^response_base64_begin\s*\r?\n(.+?)\r?\nresponse_base64_end\s*$",
        raw,
    )
    if match:
        try:
            return base64.b64decode(match.group(1).strip()).decode("utf-8").strip()
        except (ValueError, UnicodeDecodeError):
            pass

    match = re.search(
        r"(?ms)^response_begin\s*\r?\n(.*?)\r?\nresponse_end\s*$",
        raw,
    )
    return match.group(1).strip() if match else ""


def _lite_completion_reply(ok: bool, raw: str) -> str:
    response = _decode_lite_response(raw)
    if ok and response:
        return f"Hermes Lite (Groq, no tools).\n{response}"[:MAX_REPLY_CHARS]
    reason = _output_field(raw, "error") or _output_field(raw, "reason")
    return "\n".join(
        [
            "Hermes Lite unavailable.",
            "lite_chat_status=blocked",
            f"reason={reason or 'provider_failed'}",
        ]
    )[:MAX_REPLY_CHARS]


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
    publish_status = _output_field(raw, "knowledge_publish_status")
    if publish_status:
        lines.append(f"knowledge_publish_status={publish_status}")
    if publish_status == "duplicate":
        lines.append("已傳過重複類型知識")
    if not ok:
        reason = _output_field(raw, "reason")
        lines.append(f"reason={reason or 'pipeline_failed'}")
    reply = "\n".join(lines)
    if len(reply) > MAX_REPLY_CHARS:
        reply = reply[: MAX_REPLY_CHARS - 20] + "\n...truncated"
    return reply


def _url_completion_reply(ok: bool, raw: str) -> str:
    dispatch_id = _output_field(raw, "dispatch_id")
    result_path = _output_field(raw, "result_path")
    execution = _output_field(raw, "codex_execution_status")
    lines = [
        "AgentOS URL intake finished.",
        f"pipeline_status={'completed' if ok else 'blocked'}",
        f"dispatch_id={dispatch_id or 'unknown'}",
        f"codex_execution_status={execution or 'blocked'}",
    ]
    if result_path:
        lines.append(f"result_path={result_path}")
        try:
            result = Path(result_path).read_text(encoding="utf-8").strip()
            if result:
                lines.extend(["", result])
        except OSError:
            lines.append("result_read_status=failed")
    publish_status = _output_field(raw, "knowledge_publish_status")
    if publish_status:
        lines.append(f"knowledge_publish_status={publish_status}")
    if publish_status == "duplicate":
        lines.append("已傳過重複類型知識")
    if not ok:
        reason = _output_field(raw, "reason")
        lines.append(f"reason={reason or 'pipeline_failed'}")
    reply = "\n".join(lines)
    if len(reply) > MAX_REPLY_CHARS:
        reply = reply[: MAX_REPLY_CHARS - 20] + "\n...truncated"
    return reply


def _local_file_completion_reply(
    ok: bool,
    raw: str,
    fallback_dispatch_id: str = "",
) -> str:
    result_path = _output_field(raw, "result_path")
    worker_status = _output_field(raw, "local_file_task_status")
    if worker_status == "escalation_required":
        return "\n".join(
            [
                "AgentOS 工單需要 Josh 決策。",
                "task_status=escalation_required",
                f"dispatch_id={_output_field(raw, 'dispatch_id') or fallback_dispatch_id or 'unknown'}",
                f"task_type={_output_field(raw, 'task_type') or 'unknown'}",
                f"escalation_path={_output_field(raw, 'escalation_path') or 'unknown'}",
                "models_invoked=false",
            ]
        )[:MAX_REPLY_CHARS]
    lines = [
        "AgentOS 單一步驟已完成，Supervisor 持續追蹤。" if ok else "AgentOS 工作區任務受阻。",
        f"task_status={'supervising' if ok else 'blocked'}",
        f"dispatch_id={_output_field(raw, 'dispatch_id') or fallback_dispatch_id or 'unknown'}",
    ]
    if result_path:
        lines.append(f"result_path={result_path}")
        try:
            result = Path(result_path).read_text(encoding="utf-8").strip()
            if result:
                lines.extend(["", result])
        except OSError:
            lines.append("result_read_status=failed")
            lines.append("結果檔案無法讀取。")
    if not ok:
        lines.append(f"reason={_output_field(raw, 'reason') or 'worker_failed'}")
        lines.append("請依照上述原因檢查工單或 worker 記錄。")
    return "\n".join(lines)[:MAX_REPLY_CHARS]


def _raw_intake_completion_reply(ok: bool, raw: str, dispatch_id: str = "") -> str:
    draft_path = _output_field(raw, "draft_path")
    lines = [
        "AgentOS [成形] 需求成形草稿已建立，待 Josh 核准。" if ok else "AgentOS [成形] 需求成形草稿建立失敗。",
        f"task_intake_status={'raw_intake_accepted' if ok else 'blocked'}",
        f"dispatch_id={dispatch_id or _output_field(raw, 'dispatch_id') or 'unknown'}",
        "status=awaiting_josh_approval",
        "models_invoked=false",
    ]
    if draft_path:
        lines.append(f"draft_path={draft_path}")
    if not ok:
        reason = _output_field(raw, "reason")
        lines.append(f"reason={reason or 'draft_creation_failed'}")
    lines.append("Josh 明確回覆核准前不進入實作。")
    return "\n".join(lines)[:MAX_REPLY_CHARS]


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

    chat_id = _source_value(source, "chat_id")
    candidates = [
        ("send_message", (chat_id, text), {}),
        ("send", (chat_id, text), {}),
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
            logger.warning("AgentOS reply failed via %s: %s", method_name, exc)
            continue


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
    if ok:
        ok, output = await asyncio.to_thread(_publish_knowledge, output)
    await _send_reply(gateway, event, _threads_completion_reply(ok, output))
    if ok:
        logger.info("AgentOS Threads intake completed: %s", dispatch_id)
    else:
        logger.warning("AgentOS Threads intake blocked: %s output=%s", dispatch_id, output[:500])


async def _complete_lite_chat(gateway: Any, event: Any, text: str) -> None:
    ok, output = await asyncio.to_thread(_run_lite_chat, text)
    await _send_reply(gateway, event, _lite_completion_reply(ok, output))
    if ok:
        logger.info("Hermes Lite chat completed via guarded Groq window")
    else:
        logger.warning("Hermes Lite chat blocked: %s", output[:500])


async def _complete_generic_url_intake(
    gateway: Any,
    event: Any,
    url: str,
    text: str,
    dispatch_id: str,
) -> None:
    ok, output = await asyncio.to_thread(
        _run_generic_url_pipeline,
        url,
        text,
        dispatch_id,
    )
    await _send_reply(gateway, event, _url_completion_reply(ok, output))
    if ok:
        logger.info("AgentOS URL intake completed: %s", dispatch_id)
    else:
        logger.warning("AgentOS URL intake blocked: %s output=%s", dispatch_id, output[:500])


async def _complete_local_file_task(
    gateway: Any,
    event: Any,
    text: str,
    dispatch_id: str,
) -> None:
    ok, output = await asyncio.to_thread(_run_local_file_task, text, dispatch_id)
    if ok:
        supervisor_ok, supervisor_output = await asyncio.to_thread(
            _run_workflow_supervisor,
            dispatch_id,
        )
        if supervisor_output:
            output = output + "\n" + supervisor_output
        ok = ok and supervisor_ok
    await _send_reply(
        gateway,
        event,
        _local_file_completion_reply(ok, output, dispatch_id),
    )
    if ok:
        monitor = asyncio.create_task(
            _monitor_workflow_completion(gateway, event, dispatch_id)
        )
        _retain_background_task(monitor)
        logger.info("AgentOS workflow supervision started: %s", dispatch_id)
    else:
        logger.warning("AgentOS local file task blocked: %s output=%s", dispatch_id, output[:500])


async def _complete_raw_intake(
    gateway: Any,
    event: Any,
    text: str,
    dispatch_id: str,
) -> None:
    ok, output = await asyncio.to_thread(_run_raw_intake, text, dispatch_id)
    await _send_reply(gateway, event, _raw_intake_completion_reply(ok, output, dispatch_id))
    if ok:
        logger.info("AgentOS raw intake draft created: %s", dispatch_id)
    else:
        logger.warning("AgentOS raw intake blocked: %s output=%s", dispatch_id, output[:500])


async def _monitor_workflow_completion(
    gateway: Any,
    event: Any,
    dispatch_id: str,
) -> None:
    status_path = (
        AGENTOS_ROOT / "data" / "codex_tasks" / dispatch_id /
        "OUTPUTS" / "WORKFLOW_STATUS.json"
    )
    for _ in range(720):
        await asyncio.sleep(10)
        if not status_path.exists():
            await asyncio.to_thread(_run_workflow_supervisor, dispatch_id)
            continue
        try:
            payload = json.loads(status_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        if payload.get("workflow_status") != "completed":
            continue
        await _send_reply(
            gateway,
            event,
            "\n".join(
                [
                    "AgentOS 工單真正完成。",
                    "workflow_status=completed",
                    f"dispatch_id={dispatch_id}",
                    f"final_verify_verdict={payload.get('final_verify_verdict', 'unknown')}",
                    f"final_verify_dispatch_id={payload.get('final_verify_dispatch_id', 'unknown')}",
                    f"workflow_status_path={status_path}",
                ]
            )[:MAX_REPLY_CHARS],
        )
        return


def _retain_background_task(task: asyncio.Task) -> None:
    _background_tasks.add(task)
    task.add_done_callback(_background_tasks.discard)


async def _pre_gateway_dispatch_async(
    event: Any = None,
    gateway: Any = None,
    dispatch_id: Optional[str] = None,
    **_: Any,
) -> Optional[dict]:
    text = _text_from_event(event)
    if not text:
        return {"action": "allow"}

    source = getattr(event, "source", None)
    dispatch_id = dispatch_id or _build_dispatch_id(source)
    if PLUGIN_MODE == "chat_only":
        if gateway is not None:
            task = asyncio.create_task(_complete_lite_chat(gateway, event, text))
            _retain_background_task(task)
        return {"action": "skip", "reason": "hermes_lite_chat:chat_only"}

    # [工單] fixed prefix → executable work order (same path as 請執行 AgentOS 工單：)
    if WORK_ORDER_PATTERN.match(text):
        if gateway is not None:
            await _send_reply(
                gateway,
                event,
                "\n".join(
                    [
                        "AgentOS [工單] 已接受。",
                        f"dispatch_id={dispatch_id}",
                        "task_status=processing",
                        "route_to=RuleBasedClassifier",
                    ]
                ),
            )
            task = asyncio.create_task(
                _complete_local_file_task(gateway, event, text, dispatch_id)
            )
            _retain_background_task(task)
        return {"action": "skip", "reason": f"agentos_work_order:{dispatch_id}"}

    # [成形] fixed prefix → raw intake draft, awaiting_josh_approval, no implementation
    if RAW_INTAKE_PATTERN.match(text):
        if gateway is not None:
            await _send_reply(
                gateway,
                event,
                "\n".join(
                    [
                        "AgentOS [成形] 需求成形已接受。",
                        f"dispatch_id={dispatch_id}",
                        "task_intake_status=raw_intake_processing",
                        "status=awaiting_josh_approval",
                        "models_invoked=false",
                    ]
                ),
            )
            task = asyncio.create_task(
                _complete_raw_intake(gateway, event, text, dispatch_id)
            )
            _retain_background_task(task)
        return {"action": "skip", "reason": f"agentos_raw_intake:{dispatch_id}"}

    if CODEX_NATURAL_PATTERN.search(text) or WORK_TASK_PATTERN.search(text):
        if gateway is not None:
            await _send_reply(
                gateway,
                event,
                "\n".join(
                    [
                        "AgentOS 工作區任務已接受。",
                        f"dispatch_id={dispatch_id}",
                        "task_status=processing",
                        "route_to=RuleBasedClassifier",
                    ]
                ),
            )
            task = asyncio.create_task(
                _complete_local_file_task(gateway, event, text, dispatch_id)
            )
            _retain_background_task(task)
        return {"action": "skip", "reason": f"agentos_local_file_task:{dispatch_id}"}

    is_threads, threads_url = _is_threads_intake(text)
    if is_threads and threads_url:
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

    if TYPE_PATTERN.search(text):
        ok, output = await asyncio.to_thread(_run_dispatch, text, dispatch_id)
        if gateway is not None:
            await _send_reply(gateway, event, _summarize_output(output))
        reason = f"agentos_typed_dispatch:{dispatch_id}"
        if not ok:
            logger.warning("AgentOS typed dispatch blocked: %s output=%s", reason, output[:500])
        else:
            logger.info("AgentOS typed dispatch handled: %s", reason)
        return {"action": "skip", "reason": reason}

    url = _extract_url(text)
    if url:
        if gateway is not None:
            await _send_reply(
                gateway,
                event,
                "\n".join(
                    [
                        "AgentOS URL intake accepted.",
                        f"dispatch_id={dispatch_id}",
                        "pipeline_status=processing",
                        "route_to=Codex",
                    ]
                ),
            )
            task = asyncio.create_task(
                _complete_generic_url_intake(
                    gateway,
                    event,
                    url,
                    text,
                    dispatch_id,
                )
            )
            _retain_background_task(task)
        return {"action": "skip", "reason": f"agentos_url_intake:{dispatch_id}"}

    if PLUGIN_MODE not in {"chat_only", "task_only"} and text.lstrip().startswith("/"):
        return {"action": "allow"}

    if PLUGIN_MODE == "task_only":
        if gateway is not None:
            await _send_reply(
                gateway,
                event,
                "\n".join(
                    [
                        "AgentOS 工單入口未識別為可執行工單。",
                        "task_intake_status=not_recognized",
                        "action=請使用「[工單]」、「[成形]」或「請執行 AgentOS 工單：」開頭，或改到 @TWLunaXBot 一般聊天。",
                        "models_invoked=false",
                    ]
                ),
            )
        return {"action": "skip", "reason": "agentos_task_only:not_recognized"}

    if gateway is not None:
        task = asyncio.create_task(_complete_lite_chat(gateway, event, text))
        _retain_background_task(task)
    return {"action": "skip", "reason": "hermes_lite_chat:groq_no_tools"}


def _pre_gateway_dispatch(
    event: Any = None,
    gateway: Any = None,
    **_: Any,
) -> Optional[dict]:
    """Synchronously classify messages for Hermes' synchronous hook runner.

    Hermes invokes plugin hooks without awaiting coroutine callbacks.  Return
    the routing decision immediately and retain the async work separately so a
    URL or plain message can never fall through into the full agent session.
    """
    text = _text_from_event(event)
    if not text:
        return {"action": "allow"}

    if PLUGIN_MODE not in {"chat_only", "task_only"} and text.lstrip().startswith("/"):
        return {"action": "allow"}

    source = getattr(event, "source", None)
    dispatch_id = _build_dispatch_id(source)

    if PLUGIN_MODE == "chat_only":
        task = asyncio.create_task(
            _pre_gateway_dispatch_async(
                event=event,
                gateway=gateway,
                dispatch_id=dispatch_id,
            )
        )
        _retain_background_task(task)
        return {"action": "skip", "reason": "hermes_lite_chat:chat_only"}

    if PLUGIN_MODE == "task_only":
        task = asyncio.create_task(
            _pre_gateway_dispatch_async(
                event=event,
                gateway=gateway,
                dispatch_id=dispatch_id,
            )
        )
        _retain_background_task(task)
        return {"action": "skip", "reason": "agentos_task_only:classifying"}

    is_threads, threads_url = _is_threads_intake(text)

    task = asyncio.create_task(
        _pre_gateway_dispatch_async(
            event=event,
            gateway=gateway,
            dispatch_id=dispatch_id,
        )
    )
    _retain_background_task(task)

    if WORK_ORDER_PATTERN.match(text):
        reason = f"agentos_work_order:{dispatch_id}"
    elif RAW_INTAKE_PATTERN.match(text):
        reason = f"agentos_raw_intake:{dispatch_id}"
    elif CODEX_NATURAL_PATTERN.search(text) or WORK_TASK_PATTERN.search(text):
        reason = f"agentos_local_file_task:{dispatch_id}"
    elif is_threads and threads_url:
        reason = f"agentos_threads_intake:{dispatch_id}"
    elif TYPE_PATTERN.search(text):
        reason = f"agentos_typed_dispatch:{dispatch_id}"
    elif _extract_url(text):
        reason = f"agentos_url_intake:{dispatch_id}"
    else:
        reason = "agentos_task_only:not_recognized" if PLUGIN_MODE == "task_only" else "hermes_lite_chat:groq_no_tools"
    return {"action": "skip", "reason": reason}


def register(ctx) -> None:
    ctx.register_hook("pre_gateway_dispatch", _pre_gateway_dispatch)
    logger.info(
        "AgentOS typed dispatch plugin v%s registered from %s",
        PLUGIN_VERSION,
        __file__,
    )

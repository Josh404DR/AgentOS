"""
AgentOS Dashboard Backend
FastAPI server that exposes AgentOS data for the dashboard UI.
"""
from __future__ import annotations

import asyncio
import ctypes
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import AsyncGenerator
from urllib.parse import quote


from fastapi import FastAPI, HTTPException, Request, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from dashboard_security import (
    SESSION_COOKIE,
    AuthContext,
    DashboardSecurity,
    file_sha256,
)
from knowledge_workspace import DiscussionStore, KnowledgeIndex
from external_task_api import router as external_task_router
from hermes_metrics_client import (
    HermesMetricsResponseError,
    HermesMetricsUnavailable,
    fetch_context_window_source,
    fetch_usage_metrics,
)

# ---------------------------------------------------------------------------
# Paths — all resolved relative to this file's location (dashboard/backend/)
# ---------------------------------------------------------------------------
BACKEND_DIR = Path(__file__).parent
DASHBOARD_DIR = BACKEND_DIR.parent
AGENTOS_ROOT = DASHBOARD_DIR.parent

def _load_runtime_config() -> dict:
    config_path = AGENTOS_ROOT / "config" / "runtime.local.json"
    if not config_path.is_file():
        raise RuntimeError(f"AgentOS runtime config not found: {config_path}")
    try:
        config = json.loads(config_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise RuntimeError(f"AgentOS runtime config is invalid JSON: {config_path}. {exc}") from exc

    if not config.get("schema_version"):
        raise RuntimeError("AgentOS runtime config field is missing or empty: schema_version")
    hermes = config.get("hermes")
    if not isinstance(hermes, dict):
        raise RuntimeError("AgentOS runtime config field is missing: hermes")
    environment_overrides = {
        "root": "AGENTOS_HERMES_ROOT",
        "executable": "AGENTOS_HERMES_EXECUTABLE",
        "python": "AGENTOS_HERMES_PYTHON",
        "state_db": "AGENTOS_HERMES_STATE_DB",
    }
    for field, environment_name in environment_overrides.items():
        environment_value = os.environ.get(environment_name)
        if environment_value is not None:
            hermes[field] = environment_value
    for field in ("root", "executable", "python", "state_db"):
        value = hermes.get(field)
        if not isinstance(value, str) or not value.strip():
            raise RuntimeError(f"AgentOS runtime config field is missing or empty: hermes.{field}")
        if not Path(value).is_absolute():
            raise RuntimeError(
                f"AgentOS runtime config path must be absolute: hermes.{field}={value}"
            )
    if not Path(hermes["root"]).is_dir():
        raise RuntimeError(f"Hermes root not found: {hermes['root']}")
    for field in ("executable", "python"):
        if not Path(hermes[field]).is_file():
            raise RuntimeError(f"Hermes {field} not found: {hermes[field]}")
    if not Path(hermes["state_db"]).is_file():
        raise RuntimeError(f"Hermes state_db not found: {hermes['state_db']}")
    return config


_RUNTIME_CONFIG = _load_runtime_config()
HERMES_ROOT = Path(_RUNTIME_CONFIG["hermes"]["root"])
HERMES_EXE = Path(_RUNTIME_CONFIG["hermes"]["executable"])

LOGS_DIR = AGENTOS_ROOT / "logs"
LIVE_BRIDGE_DIR = AGENTOS_ROOT / "data" / "live_bridge"
CODEX_TASKS_DIR = AGENTOS_ROOT / "data" / "codex_tasks"
ESCALATIONS_DIR = AGENTOS_ROOT / "data" / "escalations"
ESCALATION_CLASSIFICATION_INDEX = ESCALATIONS_DIR / "ESCALATION_INDEX_CLASSIFICATION.jsonl"
QUEUE_RUNS_DIR = AGENTOS_ROOT / "data" / "queue_runs"
WORKFLOW_CONTROL_DIR = AGENTOS_ROOT / "data" / "workflow_control"
LEADS_DIR = AGENTOS_ROOT / "data" / "leads"
PROPOSALS_DIR = AGENTOS_ROOT / "data" / "proposals"
USAGE_DIR = AGENTOS_ROOT / "data" / "usage"
OBSIDIAN_VAULT_DIR = AGENTOS_ROOT / "exports" / "obsidian_agentos"
GOVERNANCE_STATUS = AGENTOS_ROOT / "data" / "governance" / "governance_status.json"
GOVERNANCE_SYNC = AGENTOS_ROOT / "scripts" / "sync_shared_governance.ps1"
RUNTIME_REGISTRY = AGENTOS_ROOT / "config" / "runtime_registry.json"
RUNTIME_STATUS = AGENTOS_ROOT / "data" / "observability" / "runtime_status.json"
RUNTIME_HISTORY = AGENTOS_ROOT / "data" / "observability" / "runtime_status_history.jsonl"
OBSERVABILITY_EVENTS_DIR = AGENTOS_ROOT / "data" / "observability" / "events"
AUTH = DashboardSecurity(AGENTOS_ROOT)
KNOWLEDGE_INDEX = KnowledgeIndex(AGENTOS_ROOT)
DISCUSSIONS = DiscussionStore(AGENTOS_ROOT)
_reconciliation_task: asyncio.Task | None = None

app = FastAPI(title="AgentOS Dashboard API", version="1.0.0")
app.include_router(external_task_router)

app.add_middleware(
    CORSMiddleware,
    allow_origins=list(AUTH.allowed_origins),
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type", "X-CSRF-Token", "X-Request-ID"],
)


class WorkflowControlRequest(BaseModel):
    action: str


class EscalationDecisionRequest(BaseModel):
    decision: str
    note: str = ""


class OwnerLoginRequest(BaseModel):
    token: str


class DiscussionWriteRequest(BaseModel):
    discussion_id: str = ""
    content: str
    target: str = ""

    class Config:
        extra = "forbid"


class CandidateExportRequest(BaseModel):
    discussion_id: str
    title: str = ""
    summary: str = ""

    class Config:
        extra = "forbid"


@app.on_event("startup")
def start_dashboard_security() -> None:
    AUTH.start()
    KNOWLEDGE_INDEX.ensure()


async def _periodic_knowledge_reconciliation() -> None:
    import logging
    import threading
    import time

    logger = logging.getLogger("uvicorn.error")
    reconcile_lock = getattr(_periodic_knowledge_reconciliation, "_reconcile_lock", None)
    if reconcile_lock is None:
        reconcile_lock = threading.Lock()
        _periodic_knowledge_reconciliation._reconcile_lock = reconcile_lock

    def reconcile_once() -> None:
        if not reconcile_lock.acquire(blocking=False):
            logger.warning(
                "Knowledge reconciliation skipped because a previous run is still active."
            )
            return

        started_at = time.monotonic()
        started_cpu = time.thread_time()
        try:
            KNOWLEDGE_INDEX.reconcile()
        except Exception:
            logger.exception("Knowledge reconciliation failed.")
        finally:
            elapsed_seconds = time.monotonic() - started_at
            cpu_seconds = time.thread_time() - started_cpu
            logger.info(
                "Knowledge reconciliation finished in %.3f seconds "
                "(worker thread CPU %.3f seconds).",
                elapsed_seconds,
                cpu_seconds,
            )
            reconcile_lock.release()

    while True:
        await asyncio.sleep(max(60, int(os.environ.get("AGENTOS_KNOWLEDGE_RECONCILE_SECONDS", "300"))))
        await asyncio.to_thread(reconcile_once)


@app.on_event("startup")
async def start_knowledge_reconciliation() -> None:
    global _reconciliation_task
    _reconciliation_task = asyncio.create_task(_periodic_knowledge_reconciliation())


@app.on_event("shutdown")
async def stop_knowledge_reconciliation() -> None:
    global _reconciliation_task
    if _reconciliation_task:
        _reconciliation_task.cancel()
        try:
            await _reconciliation_task
        except asyncio.CancelledError:
            pass
        _reconciliation_task = None


def _local_client(request: Request) -> bool:
    host = request.client.host if request.client else ""
    return host in {"127.0.0.1", "::1", "localhost", "testclient"}


def _mutations_enabled() -> bool:
    return os.environ.get("AGENTOS_DASHBOARD_MUTATIONS_ENABLED", "").strip().lower() in {
        "1", "true", "yes", "on"
    }


@app.middleware("http")
async def protect_dashboard_mutations(request: Request, call_next):
    if request.method in {"GET", "HEAD", "OPTIONS"}:
        return await call_next(request)
    if not _local_client(request):
        return JSONResponse(status_code=403, content={"detail": "local requests only"})
    if request.url.path.startswith("/api/v1/external/"):
        # SCC machine-to-machine surface: authenticated per-request via
        # X-AgentOS-API-Key inside external_task_api (fail-closed), not via
        # the browser session/origin model. Still localhost-only (checked
        # above). No approval/control operations exist on this surface.
        return await call_next(request)
    origin = request.headers.get("origin", "")
    if origin not in AUTH.allowed_origins:
        return JSONResponse(status_code=403, content={"detail": "origin not allowed"})
    if request.url.path == "/api/auth/login":
        return await call_next(request)
    try:
        context = AUTH.authenticate(
            request.cookies.get(SESSION_COOKIE, ""),
            request.headers.get("x-csrf-token", ""),
            request.headers.get("x-request-id"),
        )
    except PermissionError as exc:
        return JSONResponse(status_code=403, content={"detail": str(exc)})
    request.state.auth = context
    append_only_path = request.url.path.startswith("/api/v1/knowledge/") and (
        request.url.path.endswith("/feedback")
        or "/discussions" in request.url.path
        or request.url.path.endswith("/candidate")
    )
    owner_decision_path = (
        request.url.path.startswith("/api/approvals/")
        and request.url.path.endswith("/decision")
    )
    if (
        request.url.path != "/api/auth/logout"
        and not append_only_path
        and not owner_decision_path
        and not _mutations_enabled()
    ):
        return JSONResponse(status_code=403, content={"detail": "dashboard mutations are disabled"})
    return await call_next(request)


@app.get("/api/auth/status", tags=["public-read"])
def auth_status(request: Request):
    return AUTH.session_status(request.cookies.get(SESSION_COOKIE, ""))


@app.post("/api/auth/login", tags=["owner-control"])
def owner_login(body: OwnerLoginRequest):
    try:
        session_id, context = AUTH.login(body.token)
    except PermissionError as exc:
        if "expired" in str(exc).lower():
            expires_at = "unknown"
            try:
                for line in AUTH.token_path.read_text(encoding="utf-8").splitlines():
                    if line.startswith("expires_at="):
                        expires_at = line.split("=", 1)[1]
                        break
            except OSError:
                pass
            detail = f"Owner token 已過期（expires_at={expires_at}）；請重啟 backend 取得新 token。"
        else:
            detail = "Owner token 錯誤；請確認使用目前 backend 產生的 token。"
        raise HTTPException(status_code=403, detail=detail) from exc
    response = JSONResponse(
        {
            "authenticated": True,
            "actor_id": context.actor_id,
            "auth_method": context.auth_method,
            "expires_at": datetime.fromtimestamp(context.expires_at, tz=timezone.utc).isoformat(),
            "csrf_token": context.csrf_token,
        }
    )
    response.set_cookie(
        SESSION_COOKIE,
        session_id,
        httponly=True,
        samesite="strict",
        secure=False,
        max_age=AUTH.session_ttl_seconds,
        path="/",
    )
    return response


@app.post("/api/auth/logout", tags=["owner-control"])
def owner_logout(request: Request):
    AUTH.logout(request.cookies.get(SESSION_COOKIE, ""))
    response = JSONResponse({"ok": True})
    response.delete_cookie(SESSION_COOKIE, path="/")
    return response


def _require_local_request(request: Request) -> None:
    host = request.client.host if request.client else ""
    if host not in {"127.0.0.1", "::1", "localhost"}:
        raise HTTPException(status_code=403, detail="local requests only")


def _auth_context(request: Request) -> AuthContext:
    context = getattr(request.state, "auth", None)
    if not isinstance(context, AuthContext):
        raise HTTPException(status_code=403, detail="authenticated owner session required")
    return context


def _run_control_script(script_name: str, arguments: list[str]) -> dict:
    script = AGENTOS_ROOT / "scripts" / script_name
    completed = subprocess.run(
        [
            "powershell.exe",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(script),
            *arguments,
            "-AgentOSRoot",
            str(AGENTOS_ROOT),
        ],
        cwd=str(AGENTOS_ROOT),
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=60,
        check=False,
    )
    if completed.returncode != 0:
        raise HTTPException(
            status_code=500,
            detail=(completed.stderr or completed.stdout or "control script failed").strip(),
        )
    return {"ok": True, "output": completed.stdout.strip()}


def _write_if_changed(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_text(encoding="utf-8", errors="replace") == content:
        return
    path.write_text(content, encoding="utf-8")


def _yaml_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def _sync_obsidian_task_note(
    item: Path,
    task_text: str,
    result_text: str,
    task: dict,
) -> tuple[str, str]:
    """Write an Obsidian-compatible derivative note; task artifacts remain canonical."""
    note_path = OBSIDIAN_VAULT_DIR / "工單" / f"{item.name}.md"
    status_label = {
        "ready": "等待中",
        "processing": "進行中",
        "completed": "已完成",
        "blocked": "受阻",
    }.get(task["normalized_status"], "未標示")
    route = task["route_to"]
    source_task = item / "TASK.md"
    source_result = item / "OUTPUTS" / "RESULT.md"
    content = f"""---
type: agentos-task
dispatch_id: {_yaml_string(task["dispatch_id"])}
status: {_yaml_string(status_label)}
route_to: {_yaml_string(route)}
governance_version: {_yaml_string(task["governance_version"])}
updated_at: {_yaml_string(task["mtime_str"])}
source_of_truth: {_yaml_string(str(source_task))}
generated_read_only: true
---

# {task["title"]}

> [!warning] 衍生檢視
> 本筆記由 AgentOS 自動產生。唯一真相來源是 `{source_task}`，請勿以本筆記反向覆寫工單。

## 宇宙連結

- 中心：[[AgentOS 工單宇宙]]
- 狀態：[[狀態/{status_label}]]
- 路由：[[角色/{route}]]
- 治理：[[共同治理 v{task["governance_version"]}]]

## 工單資料

- 工單號：`{task["dispatch_id"]}`
- 狀態：{status_label}
- 路由：{route}
- 更新時間：{task["mtime_str"]}
- 原始工單：`{source_task}`
- 結果檔案：`{source_result}`

## 原始工單

{task_text or "尚無 TASK.md 內容。"}

## 進度與實際變更

{result_text or "尚未產生 RESULT.md。"}
"""
    _write_if_changed(note_path, content)
    absolute = str(note_path.resolve())
    return absolute, f"obsidian://open?path={quote(absolute, safe='')}"


def _sync_obsidian_index(tasks: list[dict]) -> None:
    OBSIDIAN_VAULT_DIR.mkdir(parents=True, exist_ok=True)
    _write_if_changed(
        OBSIDIAN_VAULT_DIR / ".obsidian" / "app.json",
        json.dumps({"showInlineTitle": True}, ensure_ascii=False, indent=2),
    )
    lines = [
        "---",
        "type: agentos-task-universe",
        "generated_read_only: true",
        "---",
        "",
        "# AgentOS 工單宇宙",
        "",
        "> 本 Vault 是 AgentOS 工單的唯讀衍生圖。請回到原始工單修改內容。",
        "",
        "## 共同中心",
        "",
        "- [[共同治理 v1.1.0]]",
        "- [[角色/Codex]]",
        "- [[角色/Claude]]",
        "- [[角色/Hermes]]",
        "",
        "## 工單節點",
        "",
    ]
    for task in tasks:
        status_label = {
            "ready": "等待中",
            "processing": "進行中",
            "completed": "已完成",
            "blocked": "受阻",
        }.get(task["normalized_status"], "未標示")
        lines.append(
            f"- [[工單/{task['id']}|{task['dispatch_id']}]]"
            f" — {status_label} — {task['route_to']}"
        )

    recent_dates: list[str] = []
    for task in tasks:
        match = re.match(r"^(\d{4}-\d{2}-\d{2})", task["id"])
        if match and match.group(1) not in recent_dates:
            recent_dates.append(match.group(1))
        if len(recent_dates) == 2:
            break
    for task in tasks:
        if not any(task["id"].startswith(date) for date in recent_dates):
            continue
        message_match = re.search(
            r"telegram-telegram-\d+-(\d+)-", task["dispatch_id"]
        )
        if message_match:
            short_name = f"TG-{message_match.group(1)}"
        else:
            compact = re.sub(r"[^A-Za-z0-9_-]+", "-", task["dispatch_id"]).strip("-")
            short_name = compact[-28:] or task["id"][-28:]
        status_label = {
            "ready": "等待中",
            "processing": "進行中",
            "completed": "已完成",
            "blocked": "受阻",
        }.get(task["normalized_status"], "未標示")
        view_content = f"""---
type: agentos-universe-view
dispatch_id: {_yaml_string(task["dispatch_id"])}
status: {_yaml_string(status_label)}
route_to: {_yaml_string(task["route_to"])}
generated_read_only: true
---

# {short_name}

- 完整工單：[[工單/{task["id"]}|{task["dispatch_id"]}]]
- 狀態：[[狀態/{status_label}]]
- 路由：[[角色/{task["route_to"]}]]
- 治理：[[共同治理 v{task["governance_version"]}]]
- 宇宙中心：[[AgentOS 工單宇宙]]
"""
        _write_if_changed(
            OBSIDIAN_VAULT_DIR / "視圖節點" / f"{short_name}.md",
            view_content,
        )
    _write_if_changed(
        OBSIDIAN_VAULT_DIR / "AgentOS 工單宇宙.md",
        "\n".join(lines) + "\n",
    )
    _write_if_changed(
        OBSIDIAN_VAULT_DIR / "共同治理 v1.1.0.md",
        "# 共同治理 v1.1.0\n\n來源：`E:\\AgentOS\\AGENTS.md`\n\n[[AgentOS 工單宇宙]]\n",
    )
    for status in ("等待中", "進行中", "已完成", "受阻"):
        _write_if_changed(
            OBSIDIAN_VAULT_DIR / "狀態" / f"{status}.md",
            f"# 狀態：{status}\n\n[[AgentOS 工單宇宙]]\n",
        )
    for role in ("Codex", "Claude", "Hermes", "Ollama", "未標示"):
        _write_if_changed(
            OBSIDIAN_VAULT_DIR / "角色" / f"{role}.md",
            f"# 角色：{role}\n\n[[AgentOS 工單宇宙]]\n",
        )


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _read_db_usage() -> dict:
    """Read token usage totals through the Hermes-owned metrics API."""
    try:
        payload = fetch_usage_metrics()
        return {
            "total": payload["total"],
            "window_5h": payload["window_5h"],
            "window_7d": payload["window_7d"],
            "recent_sessions": payload["recent_sessions"],
            "current_model": payload["current_model"],
        }
    except HermesMetricsUnavailable:
        return {"error": "usage database unavailable"}
    except (HermesMetricsResponseError, KeyError, TypeError):
        return {"error": "usage query failed"}


def _list_bridge_sessions() -> list[dict]:
    """List all live_bridge sessions sorted newest first."""
    if not LIVE_BRIDGE_DIR.exists():
        return []
    sessions = []
    for item in sorted(LIVE_BRIDGE_DIR.iterdir(), reverse=True):
        if item.is_dir():
            files = [f.name for f in item.iterdir() if f.is_file()]
            mtime = item.stat().st_mtime
            sessions.append({
                "id": item.name,
                "files": files,
                "mtime": mtime,
                "mtime_str": datetime.fromtimestamp(mtime).strftime("%Y-%m-%d %H:%M"),
            })
    return sessions


def _read_bridge_session(session_id: str) -> dict:
    """Read all files in a live_bridge session."""
    session_dir = LIVE_BRIDGE_DIR / session_id
    if not session_dir.exists():
        return {"error": "session not found"}
    result = {"id": session_id, "files": {}}
    for f in sorted(session_dir.iterdir()):
        if f.is_file():
            try:
                result["files"][f.name] = f.read_text(encoding="utf-8", errors="replace")
            except Exception:
                result["files"][f.name] = "[unreadable]"
    return result


def _read_text(path: Path) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8", errors="replace")


def _field(text: str, name: str) -> str:
    match = re.search(rf"(?mi)^{re.escape(name)}\s*[:=]\s*(.+?)\s*$", text)
    return match.group(1).strip() if match else ""


def _flag(text: str, name: str) -> bool | None:
    value = _field(text, name).lower()
    if value in {"true", "yes", "1"}:
        return True
    if value in {"false", "no", "0"}:
        return False
    return None


def _first_field(texts: list[str], names: list[str]) -> str:
    for text in texts:
        for name in names:
            value = _field(text, name)
            if value:
                return value
    return ""


def _extract_task_purpose(task_text: str, fallback: str) -> str:
    """Return a short, deterministic human summary from the task ticket."""
    for heading in ("Josh Request", "Objective", "Goal", "Task"):
        match = re.search(
            rf"(?mis)^##\s+{re.escape(heading)}\s*$\n(.*?)(?=^##\s+|\Z)",
            task_text,
        )
        if not match:
            continue
        lines = []
        for raw_line in match.group(1).splitlines():
            line = raw_line.strip()
            if not line or line.startswith("```"):
                continue
            line = re.sub(r"^[-*]\s+", "", line)
            lines.append(line)
            if len(" ".join(lines)) >= 220 or len(lines) >= 4:
                break
        if lines:
            return " ".join(lines)[:280]
    return fallback


def _extract_review_status(texts: list[str]) -> str:
    for text in texts:
        value = _field(text, "verify_verdict") or _field(text, "verification_status")
        if value:
            return value.strip("`* ").upper()
        value = _field(text, "review_status")
        if value:
            return value.strip("`* ").lower()
    combined = "\n".join(texts).lower()
    if "blocked_review_disagreement" in combined:
        return "blocked_review_disagreement"
    if "changes_requested" in combined:
        return "changes_requested"
    if "claude approved" in combined:
        return "approved"
    return ""


def _extract_failure_reason(texts: list[str]) -> str:
    combined = "\n".join(texts)
    for pattern in (
        r"(?mi)^(?:failure_reason|blocked_reason|error|error_message)\s*[:=]\s*(.+?)\s*$",
        r"(?mi)^##\s+(?:Caveats|Unresolved Risks|未解風險)\s*$\n+(.+?)(?:\n##|\Z)",
    ):
        match = re.search(pattern, combined, flags=re.S)
        if match:
            return " ".join(match.group(1).strip().split())[:240]
    lowered = combined.lower()
    if "blocked_review_disagreement" in lowered:
        return "review loop reached blocked_review_disagreement"
    if re.search(r"(?mi)\b(?:failed|error|blocked)\b", combined):
        return "failure or blocked marker found in task artifacts"
    return ""


def _list_codex_tasks() -> list[dict]:
    """List codex tasks from local artifacts only."""
    if not CODEX_TASKS_DIR.exists():
        return []
    tasks = []
    for item in sorted(CODEX_TASKS_DIR.iterdir(), reverse=True):
        if not item.is_dir():
            continue
        status_file = item / "STATUS.md"
        task_file = item / "TASK.md"
        result_file = item / "OUTPUTS" / "RESULT.md"
        worker_status_file = item / "OUTPUTS" / "WORKER_STATUS.md"
        review_flow_file = item / "OUTPUTS" / "REVIEW_FLOW_STATUS.md"
        claude_review_file = item / "OUTPUTS" / "CLAUDE_REVIEW.md"
        status = "unknown"
        title = item.name
        task_text = _read_text(task_file)
        result_text = _read_text(result_file)
        worker_text = _read_text(worker_status_file)
        status_text = _read_text(status_file)
        review_flow_text = _read_text(review_flow_file)
        claude_review_text = _read_text(claude_review_file)
        artifact_texts = [
            result_text,
            worker_text,
            review_flow_text,
            claude_review_text,
            status_text,
            task_text,
        ]
        if status_text:
            for line in status_text.splitlines():
                if "status" in line.lower() or "COMPLETE" in line or "PENDING" in line:
                    status = line.strip()
                    break
        if task_text:
            for line in task_text.splitlines():
                if line.startswith("# "):
                    title = line[2:].strip()
                    break
        purpose = _extract_task_purpose(task_text, title)

        combined = "\n".join(artifact_texts)
        status_value = _first_field(
            artifact_texts,
            ["task_status", "pipeline_status", "dispatch_status", "status", "codex_execution_status"],
        )
        review_status = _extract_review_status(
            [review_flow_text, result_text, claude_review_text, worker_text]
        )
        failure_reason = _extract_failure_reason(artifact_texts)
        if re.search(
            r"(?mi)^(?:task_status|pipeline_status|status|codex_execution_status)"
            r"\s*[:=]\s*(?:blocked|failed|blocked_review_disagreement)\s*$",
            combined,
        ) or review_status in {"blocked", "blocked_review_disagreement", "FAIL", "NEEDS_HUMAN_DECISION"}:
            normalized_status = "blocked"
        elif result_file.exists() and re.search(
            r"(?mi)^(?:task_status|pipeline_status|status|codex_execution_status)"
            r"\s*[:=]\s*completed\s*$",
            combined,
        ):
            normalized_status = "completed"
        elif result_file.exists():
            normalized_status = "completed"
        elif re.search(
            r"(?mi)^(?:task_status|pipeline_status)\s*[:=]\s*processing\s*$",
            task_text,
        ):
            normalized_status = "processing"
        else:
            normalized_status = "ready"

        requires_approval = _flag(task_text, "requires_josh_approval")
        dispatch_status = _field(task_text, "dispatch_status")
        approval = _field(task_text, "approval")
        pending_approval = (
            requires_approval is True
            and dispatch_status.lower() not in {"ready_to_route", "completed", "approved"}
            and not approval
        )
        evidence_files = [
            str(path.relative_to(item))
            for path in (task_file, status_file, result_file, worker_status_file, review_flow_file, claude_review_file)
            if path.exists()
        ]
        artifact_mtime = max(
            (
                path.stat().st_mtime
                for path in (
                    item,
                    task_file,
                    status_file,
                    result_file,
                    worker_status_file,
                    review_flow_file,
                    claude_review_file,
                )
                if path.exists()
            ),
            default=item.stat().st_mtime,
        )

        task_record = {
            "id": item.name,
            "title": title,
            "purpose": purpose,
            "status": status_value or status,
            "normalized_status": normalized_status,
            "route_to": _field(task_text, "route_to") or _field(task_text, "assigned_to") or "未標示",
            "assigned_to": _field(task_text, "assigned_to"),
            "dispatch_id": _field(task_text, "dispatch_id") or item.name,
            "parent_dispatch_id": _field(task_text, "parent_dispatch_id"),
            "source_dispatch_id": _field(task_text, "source_dispatch_id"),
            "depends_on": _field(task_text, "depends_on"),
            "codex_mode": _field(task_text, "codex_mode"),
            "dispatch_status": dispatch_status,
            "task_status": _field(task_text, "task_status"),
            "governance_version": _field(task_text, "governance_version") or "legacy",
            "governance_hash": _field(task_text, "governance_hash"),
            "workflow_version": _field(task_text, "workflow_version") or "1.1",
            "task_type": _field(task_text, "task_type") or "legacy",
            "risk_hits": _field(task_text, "risk_hits"),
            "escalation_status": _field(task_text, "escalation_status"),
            "review_status": review_status,
            "has_review_flow_status": review_flow_file.exists(),
            "has_claude_review": bool(claude_review_text),
            "requires_josh_approval": requires_approval,
            "approval": approval,
            "pending_approval": pending_approval,
            "models_invoked": _first_field(artifact_texts, ["models_invoked"]),
            "external_actions_invoked": _first_field(artifact_texts, ["external_actions_invoked"]),
            "cleanup_executed": _first_field(artifact_texts, ["cleanup_executed"]),
            "failure_reason": failure_reason,
            "has_result": result_file.exists(),
            "result_preview": result_text[:500],
            "artifact_path": str(task_file.resolve()) if task_file.exists() else str(item.resolve()),
            "result_path": str(result_file.resolve()) if result_file.exists() else "",
            "evidence_files": evidence_files,
            "mtime": artifact_mtime,
            "mtime_str": datetime.fromtimestamp(artifact_mtime).strftime("%Y-%m-%d %H:%M"),
        }
        obsidian_path = OBSIDIAN_VAULT_DIR / "工單" / f"{item.name}.md"
        task_record["obsidian_path"] = str(obsidian_path.resolve())
        task_record["obsidian_uri"] = f"obsidian://open?path={quote(str(obsidian_path.resolve()), safe='')}"
        tasks.append(task_record)
    return tasks


def _list_workflows() -> list[dict]:
    """Aggregate root tickets and descendants into deterministic supervisor views."""
    tasks = KNOWLEDGE_INDEX.list_tasks()
    by_dispatch = {task["dispatch_id"]: task for task in tasks}
    escalations = _list_escalations()
    unresolved = {
        item["task_id"]: item
        for item in escalations
        if item.get("josh_action_required")
    }

    def root_id(task: dict) -> str:
        current = task
        visited: set[str] = set()
        while current["dispatch_id"] not in visited:
            visited.add(current["dispatch_id"])
            parent = current.get("parent_dispatch_id") or current.get("source_dispatch_id")
            if not parent or parent == current["dispatch_id"] or parent not in by_dispatch:
                return current["dispatch_id"]
            current = by_dispatch[parent]
        return task["dispatch_id"]

    grouped: dict[str, list[dict]] = {}
    for task in tasks:
        grouped.setdefault(root_id(task), []).append(task)

    workflows = []
    for dispatch_id, nodes in grouped.items():
        root = by_dispatch.get(dispatch_id)
        if not root:
            continue
        nodes.sort(key=lambda item: (item["mtime"], item["dispatch_id"]))
        workers = [node for node in nodes if node.get("assigned_to") == "Claude Worker"]
        verifiers = [
            node for node in nodes
            if node.get("codex_mode") == "verify" or "Verify" in node.get("assigned_to", "")
        ]
        verdicts = [
            node.get("review_status")
            for node in verifiers
            if node.get("review_status")
        ]
        active = [node for node in nodes if node["normalized_status"] == "processing"]
        blocked_nodes = [node for node in nodes if node["normalized_status"] == "blocked"]
        pending_workers = [node for node in workers if not node["has_result"]]
        pending_verifiers = [node for node in verifiers if not node["has_result"]]
        root_escalations = [
            item for task_id, item in unresolved.items()
            if task_id == dispatch_id or task_id.startswith(dispatch_id + "-")
        ]

        if root_escalations:
            supervisor_status = "waiting_josh"
            current_stage = "人工決策"
        elif active:
            supervisor_status = "processing"
            current_stage = "驗證中" if any(node in verifiers for node in active) else "執行中"
        elif blocked_nodes and "PASS" not in verdicts:
            supervisor_status = "blocked"
            current_stage = "執行受阻"
        elif "PASS" in verdicts and not pending_workers and not pending_verifiers:
            supervisor_status = "completed"
            current_stage = "完成"
        elif any(value in {"FAIL", "NEEDS_HUMAN_DECISION", "blocked"} for value in verdicts):
            supervisor_status = "blocked"
            current_stage = "驗證受阻"
        elif pending_workers:
            supervisor_status = "planned" if root["has_result"] else "queued"
            current_stage = "等待實作"
        elif workers and pending_verifiers:
            supervisor_status = "verifying"
            current_stage = "等待驗證"
        elif root["has_result"] and not workers:
            supervisor_status = "step_completed"
            current_stage = "單一步驟完成"
        else:
            supervisor_status = "queued"
            current_stage = "等待排程"

        stages = [
            {"key": "intake", "label": "Hermes 收件", "state": "completed"},
            {
                "key": "plan",
                "label": "Codex 規劃",
                # Derive from node status so the stage bar can never disagree
                # with the Execution nodes list below it.
                "state": (
                    "blocked" if root["normalized_status"] == "blocked"
                    else "completed" if root["has_result"]
                    else "pending"
                ),
            },
            {
                "key": "worker",
                "label": "Claude 實作",
                "state": (
                    "processing" if any(node["normalized_status"] == "processing" for node in workers)
                    else "blocked" if any(node["normalized_status"] == "blocked" for node in workers)
                    else "completed" if workers and not pending_workers
                    else "pending"
                ),
            },
            {
                "key": "verify",
                "label": "Codex 驗證",
                "state": (
                    "processing" if any(node["normalized_status"] == "processing" for node in verifiers)
                    else "blocked" if (verdicts and verdicts[-1] in {"FAIL", "NEEDS_HUMAN_DECISION", "blocked"})
                    or any(node["normalized_status"] == "blocked" for node in verifiers)
                    else "completed" if verdicts and verdicts[-1] == "PASS"
                    else "pending"
                ),
            },
            {
                "key": "decision",
                "label": "Josh 決策",
                "state": "blocked" if root_escalations else "skipped",
            },
            {
                "key": "done",
                "label": "Hermes 關帳",
                "state": "completed" if supervisor_status == "completed" else "pending",
            },
        ]
        queue_state = {}
        queue_state_path = QUEUE_RUNS_DIR / f"{dispatch_id}.json"
        if queue_state_path.exists():
            try:
                queue_state = json.loads(
                    queue_state_path.read_text(encoding="utf-8", errors="replace")
                )
            except Exception:
                queue_state = {}
        queue_pid = int(queue_state.get("process_id") or 0)
        queue_process_alive = False
        if queue_pid and os.name == "nt":
            handle = ctypes.windll.kernel32.OpenProcess(0x1000, False, queue_pid)
            if handle:
                queue_process_alive = True
                ctypes.windll.kernel32.CloseHandle(handle)
        queue_stdout = QUEUE_RUNS_DIR / f"{dispatch_id}.stdout.log"
        last_queue_event = ""
        if queue_stdout.exists():
            lines = queue_stdout.read_text(encoding="utf-8", errors="replace").splitlines()
            last_queue_event = next(
                (line for line in reversed(lines) if line.strip()),
                "",
            )
        control = {}
        control_path = WORKFLOW_CONTROL_DIR / dispatch_id / "CONTROL.json"
        if control_path.exists():
            try:
                control = json.loads(
                    control_path.read_text(encoding="utf-8", errors="replace")
                )
            except Exception:
                control = {}
        # Ticket creation time: the dispatch id embeds the Telegram intake
        # timestamp as -YYYYMMDD-HHMMSS- (e.g. ...-20260712-224256-818149).
        created_at = ""
        id_time = re.search(r"-(\d{8})-(\d{6})-\d+$", dispatch_id)
        if id_time:
            raw_date, raw_time = id_time.group(1), id_time.group(2)
            created_at = (
                f"{raw_date[0:4]}-{raw_date[4:6]}-{raw_date[6:8]} "
                f"{raw_time[0:2]}:{raw_time[2:4]}:{raw_time[4:6]}"
            )
        workflows.append({
            "dispatch_id": dispatch_id,
            "created_at": created_at,
            "queue_started_at": str(queue_state.get("started_at", "")),
            "queue_finished_at": str(queue_state.get("finished_at", "")),
            "title": root["title"],
            "task_type": root["task_type"],
            "supervisor_status": supervisor_status,
            "current_stage": current_stage,
            "latest_verdict": verdicts[-1] if verdicts else "",
            "node_count": len(nodes),
            "worker_count": len(workers),
            "verify_count": len(verifiers),
            "pending_worker_count": len(pending_workers),
            "pending_verify_count": len(pending_verifiers),
            "escalation_count": len(root_escalations),
            "failure_reason": next(
                (node["failure_reason"] for node in reversed(nodes) if node["failure_reason"]),
                "",
            ),
            "result_path": root["result_path"],
            "control_state": control.get("state", "running"),
            "last_control_action": (
                "retry" if control.get("retry_requested")
                else "pause" if control.get("state") == "pause_requested"
                else "resume" if control
                else ""
            ),
            "last_control_at": control.get("updated_at", ""),
            "queue_status": queue_state.get("status", "not_started"),
            "queue_process_id": queue_pid or None,
            "queue_process_alive": queue_process_alive,
            "queue_detail": queue_state.get("detail", ""),
            "last_queue_event": last_queue_event,
            "updated_at": max(node["mtime"] for node in nodes),
            "stages": stages,
            "nodes": [
                {
                    "id": node["id"],
                    "dispatch_id": node["dispatch_id"],
                    "route_to": node["route_to"],
                    "status": node["normalized_status"],
                    "review_status": node["review_status"],
                    "result_path": node["result_path"],
                    "mtime": node["mtime"],
                    "mtime_str": node["mtime_str"],
                }
                for node in nodes
            ],
        })
    return sorted(workflows, key=lambda item: item["updated_at"], reverse=True)


def _read_codex_task(task_id: str) -> dict:
    task_dir = CODEX_TASKS_DIR / task_id
    if not task_dir.exists():
        task_dir = next(
            (
                path for path in CODEX_TASKS_DIR.iterdir()
                if path.is_dir()
                and (path / "TASK.md").exists()
                and _field((path / "TASK.md").read_text(encoding="utf-8", errors="replace"), "dispatch_id") == task_id
            ),
            task_dir,
        )
    if not task_dir.exists():
        return {"error": "task not found", "id": task_id, "files": {}}
    result = {"id": task_id, "files": {}}
    for f in task_dir.rglob("*.md"):
        rel = str(f.relative_to(task_dir))
        try:
            result["files"][rel] = f.read_text(encoding="utf-8", errors="replace")
        except Exception:
            result["files"][rel] = "[unreadable]"
    return result


def _load_escalation_environments() -> dict[str, str]:
    """Load append-only classification metadata; invalid/unknown values fail safe to runtime."""
    environments: dict[str, str] = {}
    if not ESCALATION_CLASSIFICATION_INDEX.exists():
        return environments
    for line in ESCALATION_CLASSIFICATION_INDEX.read_text(
        encoding="utf-8", errors="replace"
    ).splitlines():
        try:
            classification = json.loads(line)
        except Exception:
            continue
        task_id = classification.get("task_id")
        environment = classification.get("environment")
        if task_id and environment in {"ci", "runtime"}:
            environments[str(task_id)] = environment
    return environments


def _load_escalation_fixtures() -> dict[str, bool]:
    """Load append-only classification metadata for is_fixture; independent of environment."""
    fixtures: dict[str, bool] = {}
    if not ESCALATION_CLASSIFICATION_INDEX.exists():
        return fixtures
    for line in ESCALATION_CLASSIFICATION_INDEX.read_text(
        encoding="utf-8", errors="replace"
    ).splitlines():
        try:
            classification = json.loads(line)
        except Exception:
            continue
        task_id = classification.get("task_id")
        is_fixture = classification.get("is_fixture")
        if task_id and isinstance(is_fixture, bool):
            fixtures[str(task_id)] = is_fixture
    return fixtures


def _normalize_iso_fraction(value: str) -> str:
    """Truncate/pad an ISO-8601 timestamp's fractional-seconds component to
    exactly 6 digits (microseconds) so datetime.fromisoformat() can parse it
    regardless of the source's precision. PowerShell/.NET commonly emits
    7-digit fractional seconds (100-nanosecond ticks), which datetime.
    fromisoformat() rejects on Python versions before 3.11 -- and is not
    guaranteed to accept even on newer versions -- so we normalize instead of
    relying on interpreter-specific leniency.
    """
    match = re.match(r"^(.*T\d{2}:\d{2}:\d{2})\.(\d+)(.*)$", value)
    if not match:
        return value
    whole, frac, rest = match.groups()
    frac = (frac + "000000")[:6]
    return f"{whole}.{frac}{rest}"


def _same_instant(a: object, b: object) -> bool:
    """Compare two ISO-8601 timestamp strings as the same instant, tolerant of
    differing fractional-second precision (e.g. no fractional seconds vs.
    7-digit fractional seconds). Falls back to raw string equality if either
    value is missing or fails to parse, so unexpected formats fail closed
    (no match) rather than silently matching everything.
    """
    if not isinstance(a, str) or not isinstance(b, str):
        return a == b
    if a == b:
        return True
    try:
        return (
            datetime.fromisoformat(_normalize_iso_fraction(a))
            == datetime.fromisoformat(_normalize_iso_fraction(b))
        )
    except ValueError:
        return False


def _list_escalations() -> list[dict]:
    """List all escalations from ESCALATION_INDEX.jsonl, enriched with resolution status."""
    index_path = ESCALATIONS_DIR / "ESCALATION_INDEX.jsonl"
    if not index_path.exists():
        return []
    classified_environments = _load_escalation_environments()
    classified_fixtures = _load_escalation_fixtures()
    results = []
    seen = set()
    # ESCALATION_INDEX is append-only. Walk it newest-first so a later event
    # for the same task_id is not hidden by an older, already-resolved event.
    index_lines = index_path.read_text(encoding="utf-8", errors="replace").splitlines()
    for line in reversed(index_lines):
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except Exception:
            continue
        task_id = entry.get("task_id", "")
        environment = entry.get("environment")
        if environment not in {"ci", "runtime"}:
            environment = classified_environments.get(task_id, "runtime")
        entry_is_fixture = entry.get("is_fixture")
        if isinstance(entry_is_fixture, bool):
            is_fixture = entry_is_fixture
        elif task_id in classified_fixtures:
            is_fixture = classified_fixtures[task_id]
        else:
            is_fixture = environment == "ci"
        # De-duplicate: reversed traversal keeps the latest appended event.
        if task_id in seen:
            continue
        seen.add(task_id)

        # Check for a RESOLUTION.json in the task's escalation directory
        safe_id = re.sub(r"[^A-Za-z0-9_.\-]+", "-", task_id)
        resolution_path = ESCALATIONS_DIR / safe_id / "RESOLUTION.json"
        resolution = None
        if resolution_path.exists():
            try:
                resolution = json.loads(resolution_path.read_text(encoding="utf-8", errors="replace"))
            except Exception:
                pass
        escalation_dir = ESCALATIONS_DIR / safe_id
        verified_decision = None
        verified_decision_path = None
        for decision_path in sorted(escalation_dir.glob("DECISION-*.json"), reverse=True):
            try:
                candidate = json.loads(decision_path.read_text(encoding="utf-8"))
            except Exception:
                continue
            # A decision is bound to one escalation event. A valid decision
            # for an earlier generation of the same task_id must not resolve
            # a later append-only event.
            # NOTE: compare as parsed instants, not raw strings -- the index
            # writes created_at without fractional seconds (e.g.
            # "2026-07-26T16:49:26+08:00") while DECISION-*.json's
            # escalation_created_at is written with 7-digit fractional
            # seconds (e.g. "2026-07-26T16:49:26.0000000+08:00"). Same
            # instant, different string, so a raw `!=` always mismatched and
            # a verified decision could never resolve its escalation.
            if not _same_instant(candidate.get("escalation_created_at"), entry.get("created_at")):
                continue
            if AUTH.verify_escalation_decision_record(candidate, escalation_dir):
                verified_decision = candidate
                verified_decision_path = decision_path
                break
        if verified_decision is not None:
            resolution = {
                "resolution_type": "verified_owner_decision",
                "decision": verified_decision.get("decision"),
                "resolved_at": verified_decision.get("decided_at"),
                "resolved_by": verified_decision.get("decided_by"),
                "authentication_method": verified_decision.get("authentication_method"),
                "request_id": verified_decision.get("request_id"),
                "decision_path": str(verified_decision_path),
                "receipt_path": verified_decision.get("receipt", {}).get("path"),
                "suspicious_fast_decision": verified_decision.get("suspicious_fast_decision", False),
                "josh_action_required": False,
                "recommended_status": "stopped" if verified_decision.get("decision") == "stop" else "resolved",
            }
        elif resolution and resolution.get("resolution_type") in {
            "owner_decision", "verified_owner_decision"
        }:
            # Legacy/model-authored owner resolutions are not evidence. Keep
            # them on disk, but display the escalation as awaiting Josh.
            resolution = None
        artifact = {}
        artifact_path = Path(entry.get("artifact_path", ""))
        if artifact_path.exists():
            try:
                artifact = json.loads(artifact_path.read_text(encoding="utf-8", errors="replace"))
            except Exception:
                pass

        display_status = resolution.get("recommended_status", "resolved_by_evidence") if resolution else entry.get("status", "awaiting_josh")
        results.append({
            "task_id": task_id,
            "environment": environment,
            "is_fixture": is_fixture,
            "source": entry.get("source", ""),
            "reason": entry.get("reason", ""),
            "status": display_status,
            "index_status": entry.get("status", ""),
            "created_at": entry.get("created_at", ""),
            "artifact_path": entry.get("artifact_path", ""),
            "summary_for_josh": artifact.get("summary_for_josh", ""),
            "decision_type": artifact.get("decision_type", ""),
            "options": artifact.get("options", []),
            "evidence": artifact.get("evidence", []),
            "has_resolution": resolution is not None,
            "resolution": resolution,
            "josh_action_required": resolution.get("josh_action_required", True) if resolution else True,
            "category": resolution.get("category", "live") if resolution else "live",
        })
    results.sort(key=lambda x: x["created_at"], reverse=True)
    return results


def _list_leads() -> list[dict]:
    if not LEADS_DIR.exists():
        return []
    leads = []
    for f in sorted(LEADS_DIR.glob("*.md"), reverse=True):
        leads.append({
            "id": f.stem,
            "filename": f.name,
            "mtime": f.stat().st_mtime,
            "preview": f.read_text(encoding="utf-8", errors="replace")[:300],
        })
    return leads


def _list_proposals() -> list[dict]:
    if not PROPOSALS_DIR.exists():
        return []
    props = []
    for f in sorted(PROPOSALS_DIR.glob("*.md"), reverse=True):
        props.append({
            "id": f.stem,
            "filename": f.name,
            "mtime": f.stat().st_mtime,
            "preview": f.read_text(encoding="utf-8", errors="replace")[:300],
        })
    return props


def _get_latest_usage_summary() -> dict:
    daily_dir = USAGE_DIR / "daily_token_cost_summary"
    if not daily_dir.exists():
        return {}
    files = sorted(daily_dir.glob("*.md"), reverse=True)
    if not files:
        return {}
    try:
        return {"filename": files[0].name, "content": files[0].read_text(encoding="utf-8", errors="replace")}
    except Exception:
        return {}


async def _tail_log_file(path: Path, ws: WebSocket, lines: int = 50):
    """Send last N lines of a log file, then stream new lines."""
    if not path.exists():
        await ws.send_text(json.dumps({"type": "error", "message": f"Log not found: {path.name}"}))
        return

    # Send history
    text = path.read_text(encoding="utf-8", errors="replace")
    history = text.splitlines()[-lines:]
    for line in history:
        await ws.send_text(json.dumps({"type": "history", "line": line}))

    # Stream new content
    size = path.stat().st_size
    while True:
        await asyncio.sleep(1)
        try:
            new_size = path.stat().st_size
            if new_size > size:
                with open(path, encoding="utf-8", errors="replace") as f:
                    f.seek(size)
                    new_content = f.read()
                size = new_size
                for line in new_content.splitlines():
                    if line:
                        await ws.send_text(json.dumps({"type": "new", "line": line}))
        except Exception:
            break


def _latest_agent_output(route: str) -> Path | None:
    """Resolve the newest task output for a route without changing artifacts."""
    candidates: list[Path] = []
    if not CODEX_TASKS_DIR.exists():
        return None
    route_pattern = re.compile(
        rf"(?mi)^(?:route_to|assigned_to)\s*:\s*{re.escape(route)}(?:\s+\w+)?\s*$"
    )
    for task_path in CODEX_TASKS_DIR.glob("*/TASK.md"):
        try:
            task_text = task_path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        if not route_pattern.search(task_text):
            continue
        outputs = task_path.parent / "OUTPUTS"
        for name in ("AGENT_OUTPUT.md", "RESULT.md", "CODEX_CONSOLE.log"):
            candidate = outputs / name
            if candidate.is_file():
                candidates.append(candidate)
                break
    return max(candidates, key=lambda path: path.stat().st_mtime) if candidates else None


def _resolve_live_source(source: str) -> Path | None:
    if source == "hermes":
        for name in ("hermes-gateway.stderr.log", "hermes-gateway.stdout.log"):
            path = LOGS_DIR / name
            if path.is_file() and path.stat().st_size > 0:
                return path
        return LOGS_DIR / "hermes-gateway.stderr.log"
    if source == "codex":
        return _latest_agent_output("Codex")
    if source == "claude":
        return _latest_agent_output("Claude")
    return None


async def _tail_live_source(source: str, websocket: WebSocket, lines: int = 60):
    """Follow a logical agent source and switch when a newer task appears."""
    active_path: Path | None = None
    previous_text = ""
    while True:
        await asyncio.sleep(1)
        path = _resolve_live_source(source)
        if path is None or not path.exists():
            if active_path is None:
                await websocket.send_text(
                    json.dumps(
                        {
                            "type": "history",
                            "line": f"[{source}] 尚無可顯示的 CLI 輸出",
                        },
                        ensure_ascii=False,
                    )
                )
                active_path = Path("__missing__")
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        if path != active_path:
            active_path = path
            previous_text = text
            await websocket.send_text(
                json.dumps(
                    {
                        "type": "new",
                        "line": f"── 切換來源：{path} ──",
                    },
                    ensure_ascii=False,
                )
            )
            for line in text.splitlines()[-lines:]:
                await websocket.send_text(
                    json.dumps({"type": "history", "line": line}, ensure_ascii=False)
                )
            continue
        if text == previous_text:
            continue
        new_text = text[len(previous_text) :] if text.startswith(previous_text) else text
        previous_text = text
        for line in new_text.splitlines():
            if line:
                await websocket.send_text(
                    json.dumps({"type": "new", "line": line}, ensure_ascii=False)
                )


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.get("/api/health", tags=["public-read"])
def health():
    runtime_age_seconds = None
    if RUNTIME_STATUS.exists():
        runtime_age_seconds = round(
            datetime.now(timezone.utc).timestamp() - RUNTIME_STATUS.stat().st_mtime,
            1,
        )
    return {
        "status": "ok",
        "agentos_root": str(AGENTOS_ROOT),
        "runtime_evidence": {
            "available": RUNTIME_STATUS.exists(),
            "age_seconds": runtime_age_seconds,
        },
    }


@app.get("/api/runtimes", tags=["public-read"])
def runtimes():
    """Return deterministic registry data merged with the latest collector evidence."""
    try:
        registry = json.loads(RUNTIME_REGISTRY.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise HTTPException(status_code=503, detail=f"runtime registry unavailable: {exc}") from exc

    evidence: dict = {}
    evidence_error = None
    evidence_age = (
        datetime.now(timezone.utc).timestamp() - RUNTIME_STATUS.stat().st_mtime
        if RUNTIME_STATUS.exists()
        else None
    )
    if RUNTIME_STATUS.exists():
        try:
            evidence = json.loads(RUNTIME_STATUS.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            evidence_error = str(exc)
    else:
        evidence_error = evidence_error or "runtime collector has not produced evidence"

    statuses = {item.get("runtime_id"): item for item in evidence.get("runtimes", [])}
    merged = []
    for item in registry.get("runtimes", []):
        merged.append({**item, "status": statuses.get(item.get("runtime_id"), {"state": "unknown"})})
    return {
        "schema_version": registry.get("schema_version"),
        "collected_at": evidence.get("collected_at"),
        "evidence_age_seconds": round(evidence_age, 1) if evidence_age is not None else None,
        "evidence_stale": evidence_age is None or evidence_age > 45,
        "evidence_error": evidence_error,
        "runtimes": merged,
    }


@app.get("/api/runtime-history", tags=["public-read"])
def runtime_history(limit: int = 48):
    """Return recent compact collector snapshots without probing live services."""
    bounded = max(1, min(limit, 192))
    if not RUNTIME_HISTORY.exists():
        return {"snapshots": []}
    lines = RUNTIME_HISTORY.read_text(encoding="utf-8", errors="replace").splitlines()
    snapshots = []
    for line in lines[-bounded:]:
        try:
            snapshots.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return {"snapshots": snapshots}


@app.get("/api/events", tags=["public-read"])
def runtime_events(runtime_id: str | None = None, dispatch_id: str | None = None, limit: int = 200):
    """Read the newest structured runtime events without model interpretation."""
    rows = []
    for path in sorted(OBSERVABILITY_EVENTS_DIR.glob("*.jsonl"), reverse=True):
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            if runtime_id and row.get("runtime_id") != runtime_id:
                continue
            if dispatch_id and row.get("dispatch_id") != dispatch_id:
                continue
            rows.append(row)
    rows.sort(key=lambda row: row.get("ts", ""), reverse=True)
    return {"events": rows[: max(1, min(limit, 1000))]}


@app.get("/api/failures", tags=["public-read"])
def failures(error_class: str | None = None, limit: int = 200):
    rows = runtime_events(limit=1000)["events"]
    rows = [row for row in rows if row.get("result") in {"error", "timeout"}]
    if error_class:
        rows = [row for row in rows if row.get("error_class") == error_class]
    return {"failures": rows[: max(1, min(limit, 1000))]}


@app.get("/api/status-assistant", tags=["public-read"])
def status_assistant(q: str):
    """Answer status questions from local structured evidence, with source paths."""
    query = q.strip().lower()
    if not query:
        raise HTTPException(status_code=400, detail="q is required")

    runtime_data = runtimes()
    runtime_matches = [
        item for item in runtime_data["runtimes"]
        if item.get("runtime_id", "").lower() in query
        or item.get("display_name", "").lower() in query
    ]
    task_matches = [
        item for item in _list_codex_tasks()
        if item.get("dispatch_id", "").lower() in query
        or query in item.get("dispatch_id", "").lower()
        or (len(query) >= 4 and query in item.get("title", "").lower())
    ][:5]

    citations = []
    lines = []
    if runtime_matches:
        for item in runtime_matches[:5]:
            state = item.get("status", {}).get("state", "unknown")
            lines.append(f"{item['display_name']}: {state}")
        citations.append({"path": "data/observability/runtime_status.json", "timestamp": runtime_data.get("collected_at")})
        citations.append({"path": "config/runtime_registry.json", "timestamp": None})
    if task_matches:
        for item in task_matches:
            lines.append(f"{item.get('dispatch_id')}: {item.get('normalized_status', item.get('status', 'unknown'))}")
            if item.get("failure_reason"):
                lines.append(f"blocker: {item.get('failure_reason')}")
            recorded = runtime_events(dispatch_id=item.get("dispatch_id"), limit=1)["events"]
            if recorded:
                last = recorded[0]
                lines.append(
                    f"last event: {last.get('ts')} {last.get('actor')} / "
                    f"{last.get('action')} -> {last.get('result')}; next={last.get('next_step') or 'none'}"
                )
                citations.append({"path": "data/observability/events/", "timestamp": last.get("ts")})
            citations.append({"path": item.get("artifact_path"), "timestamp": item.get("mtime_str")})
            if item.get("result_path"):
                citations.append({"path": item.get("result_path"), "timestamp": item.get("mtime_str")})
    if not lines:
        counts: dict[str, int] = {}
        for item in runtime_data["runtimes"]:
            state = item.get("status", {}).get("state", "unknown")
            counts[state] = counts.get(state, 0) + 1
        lines.append("Runtime summary: " + ", ".join(f"{key}={value}" for key, value in sorted(counts.items())))
        lines.append("No exact task or runtime match was found. Include a dispatch ID or runtime ID for a precise answer.")
        citations.append({"path": "data/observability/runtime_status.json", "timestamp": runtime_data.get("collected_at")})
    return {"answer": "\n".join(lines), "citations": citations, "models_invoked": False}


@app.get("/api/governance", tags=["public-read"])
def governance():
    """Return the latest governance evidence without mutating governance state."""
    if not GOVERNANCE_STATUS.exists():
        return JSONResponse(
            status_code=503,
            content={
                "governance_status": "blocked",
                "refresh_error": "status file missing; run the governance gate explicitly",
                "token_cost": 0,
                "model_calls": 0,
            },
        )
    try:
        payload = json.loads(GOVERNANCE_STATUS.read_text(encoding="utf-8"))
    except Exception as exc:
        return JSONResponse(
            status_code=500,
            content={
                "governance_status": "blocked",
                "refresh_error": f"{type(exc).__name__}: {exc}",
                "token_cost": 0,
                "model_calls": 0,
            },
        )
    return payload


@app.get("/api/usage", tags=["public-read"])
def get_usage():
    return _read_db_usage()


@app.get("/api/usage/summary", tags=["public-read"])
def get_usage_summary():
    return _get_latest_usage_summary()


@app.get("/api/bridge", tags=["public-read"])
def list_bridge():
    return _list_bridge_sessions()


@app.get("/api/bridge/{session_id}", tags=["public-read"])
def get_bridge_session(session_id: str):
    return _read_bridge_session(session_id)


@app.get("/api/v1/today", tags=["public-read"])
def knowledge_today(limit: int = 20):
    safe_limit = max(1, min(limit, 100))
    result = KNOWLEDGE_INDEX.today(limit=safe_limit)
    recent_feedback = DISCUSSIONS.recent(safe_limit)
    result["recent_feedback"] = recent_feedback
    result["pending_feedback"] = [
        item for item in recent_feedback if item.get("type") == "feedback_annotation"
    ]
    result["knowledge_candidates"] = DISCUSSIONS.candidates(safe_limit)
    return result


@app.get("/api/v1/knowledge", tags=["public-read"])
def list_knowledge_nodes(cursor: str | None = None, limit: int = 30):
    try:
        return KNOWLEDGE_INDEX.list_nodes(cursor, limit)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.get("/api/v1/knowledge/search", tags=["public-read"])
def search_knowledge(q: str = "", cursor: str | None = None, limit: int = 30):
    try:
        return KNOWLEDGE_INDEX.search(q, cursor, limit)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.get("/api/v1/knowledge/artifacts/{artifact_ref}", tags=["public-read"])
def read_knowledge_artifact(artifact_ref: str):
    artifact = KNOWLEDGE_INDEX.artifact(artifact_ref)
    if not artifact:
        raise HTTPException(status_code=404, detail="artifact not found")
    return artifact


@app.get("/api/v1/knowledge/{node_id}", tags=["public-read"])
def read_knowledge_node(node_id: str):
    node = KNOWLEDGE_INDEX.node_detail(node_id)
    if not node:
        raise HTTPException(status_code=404, detail="knowledge node not found")
    node["discussion_events"] = DISCUSSIONS.read(node_id)
    return node


@app.get("/api/v1/knowledge/{node_id}/discussions", tags=["public-read"])
def read_knowledge_discussions(node_id: str, discussion_id: str | None = None):
    if not KNOWLEDGE_INDEX.node_detail(node_id):
        raise HTTPException(status_code=404, detail="knowledge node not found")
    try:
        return {"items": DISCUSSIONS.read(node_id, discussion_id)}
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


def _append_discussion_event(
    node_id: str,
    discussion_id: str,
    event_type: str,
    body: DiscussionWriteRequest,
    request: Request,
):
    if not KNOWLEDGE_INDEX.node_detail(node_id):
        raise HTTPException(status_code=404, detail="knowledge node not found")
    auth = _auth_context(request)
    try:
        path, event = DISCUSSIONS.append(
            node_id,
            discussion_id,
            event_type,
            body.content,
            auth.actor_id,
            auth.auth_method,
            auth.request_id,
            body.target,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    AUTH.write_audit(
        auth,
        f"knowledge.{event_type}",
        path,
        None,
        file_sha256(path),
        before_state="absent",
        after_state="immutable_event_created",
    )
    return {"ok": True, "event": event}


@app.post("/api/v1/knowledge/{node_id}/feedback", tags=["knowledge-append"])
def append_knowledge_feedback(node_id: str, body: DiscussionWriteRequest, request: Request):
    discussion_id = body.discussion_id or f"feedback-{datetime.now(timezone.utc).strftime('%Y%m%d')}"
    return _append_discussion_event(node_id, discussion_id, "feedback_annotation", body, request)


@app.post("/api/v1/knowledge/{node_id}/discussions", tags=["knowledge-append"])
def create_knowledge_discussion(node_id: str, body: DiscussionWriteRequest, request: Request):
    discussion_id = body.discussion_id or f"discussion-{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S')}"
    return _append_discussion_event(node_id, discussion_id, "discussion_created", body, request)


@app.post("/api/v1/knowledge/{node_id}/discussions/{discussion_id}/messages", tags=["knowledge-append"])
def append_knowledge_message(
    node_id: str, discussion_id: str, body: DiscussionWriteRequest, request: Request
):
    if body.discussion_id and body.discussion_id != discussion_id:
        raise HTTPException(status_code=400, detail="discussion id mismatch")
    return _append_discussion_event(node_id, discussion_id, "message", body, request)


@app.post("/api/v1/knowledge/{node_id}/candidate", tags=["knowledge-append"])
def export_knowledge_candidate(node_id: str, body: CandidateExportRequest, request: Request):
    if not KNOWLEDGE_INDEX.node_detail(node_id):
        raise HTTPException(status_code=404, detail="knowledge node not found")
    auth = _auth_context(request)
    try:
        path = DISCUSSIONS.export_candidate(
            node_id,
            body.discussion_id,
            body.title,
            body.summary,
            auth.actor_id,
            auth.auth_method,
            auth.request_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    AUTH.write_audit(
        auth,
        "knowledge.candidate_export",
        path,
        None,
        file_sha256(path),
        before_state="absent",
        after_state="candidate_only",
    )
    return {
        "ok": True,
        "candidate_id": path.stem,
        "status": "candidate_only",
        "dispatch_executed": False,
        "publish_executed": False,
    }


def _is_ci_fixture_namespace(value: object) -> bool:
    return str(value or "").lower().startswith("ci-smoke-")


@app.get("/api/tasks", tags=["public-read"])
def list_tasks(include_ci_fixtures: bool = False):
    tasks = KNOWLEDGE_INDEX.list_tasks()
    if include_ci_fixtures:
        return tasks
    return [
        task for task in tasks
        if not _is_ci_fixture_namespace(task.get("dispatch_id") or task.get("folder_id"))
    ]


@app.get("/api/tasks/{task_id}", tags=["public-read"])
def get_task(task_id: str, include_ci_fixtures: bool = False):
    if _is_ci_fixture_namespace(task_id) and not include_ci_fixtures:
        return {"error": "task not found", "id": task_id, "files": {}}
    task = KNOWLEDGE_INDEX.task_detail(task_id)
    if not task:
        return {"error": "task not found", "id": task_id, "files": {}}
    files: dict[str, str] = {}
    for entry in task.get("artifact_refs", []):
        artifact = KNOWLEDGE_INDEX.artifact(entry.get("ref", ""))
        if artifact:
            files[entry.get("kind", "artifact")] = artifact["content"]
    return {
        "id": task_id,
        "dispatch_id": task["dispatch_id"],
        "folder_id": task["folder_id"],
        "files": files,
    }


DECISIONS_DIR = AGENTOS_ROOT / "docs" / "decisions"
DECISIONS_LAYOUT = DECISIONS_DIR / "_layout.json"


class DecisionCreateRequest(BaseModel):
    title: str
    status: str = "proposed"
    body: str = ""
    links: list[str] = []


class DecisionLinkRequest(BaseModel):
    target: str


class DecisionStatusRequest(BaseModel):
    status: str
    evidence: str = ""


class DecisionLayoutRequest(BaseModel):
    positions: dict[str, dict] = {}


@app.get("/api/decisions", tags=["public-read"])
def list_decisions():
    """Strategy decision graph: nodes are ADR markdown files, edges are [[wiki links]]."""
    if not DECISIONS_DIR.exists():
        return {"nodes": [], "edges": []}
    layout: dict = {}
    if DECISIONS_LAYOUT.exists():
        try:
            layout = json.loads(DECISIONS_LAYOUT.read_text(encoding="utf-8", errors="replace"))
        except json.JSONDecodeError:
            layout = {}
    nodes = []
    raw_edges: list[dict] = []
    for path in sorted(DECISIONS_DIR.glob("ADR-*.md")):
        text = path.read_text(encoding="utf-8", errors="replace")
        node_id = path.stem
        title_match = re.search(r"(?m)^#\s+(.+)$", text)
        nodes.append({
            "id": node_id,
            "title": title_match.group(1).strip() if title_match else node_id,
            "status": _field(text, "status") or "proposed",
            "date": _field(text, "date"),
            "body": text,
            "position": layout.get(node_id),
        })
        for target in re.findall(r"\[\[([^\]]+)\]\]", text):
            raw_edges.append({"source": node_id, "target": target.strip()})
    known = {node["id"] for node in nodes}
    edges = [edge for edge in raw_edges if edge["target"] in known and edge["source"] != edge["target"]]
    return {"nodes": nodes, "edges": edges}


@app.post("/api/decisions", tags=["owner-control"])
def create_decision(body: DecisionCreateRequest, request: Request):
    auth = _auth_context(request)
    title = body.title.strip()
    if not title:
        raise HTTPException(status_code=400, detail="title required")
    if body.status not in {"proposed", "accepted", "landed", "superseded"}:
        raise HTTPException(status_code=400, detail="invalid status")
    DECISIONS_DIR.mkdir(parents=True, exist_ok=True)
    numbers = []
    for path in DECISIONS_DIR.glob("ADR-*.md"):
        match = re.match(r"ADR-(\d+)", path.name)
        if match:
            numbers.append(int(match.group(1)))
    next_num = max(numbers, default=0) + 1
    slug = re.sub(r"[^A-Za-z0-9]+", "-", title).strip("-").lower()[:40] or "decision"
    node_id = f"ADR-{next_num:04d}-{slug}"
    known = {path.stem for path in DECISIONS_DIR.glob("ADR-*.md")}
    links = [target for target in body.links if target in known]
    links_line = " ".join(f"[[{target}]]" for target in links) or "none"
    content = (
        f"# ADR-{next_num:04d}: {title}\n\n"
        f"status: {body.status}\n"
        f"date: {datetime.now().strftime('%Y-%m-%d')}\n"
        f"created_by: {auth.actor_id}\n"
        f"authentication_method: {auth.auth_method}\n"
        f"request_id: {auth.request_id}\n"
        f"links: {links_line}\n\n"
        f"## 內容\n\n{body.body.strip() or '（待補）'}\n\n"
        f"## 回頭條件\n\n（待補——什麼徵兆出現時要回來重開這個決策）\n"
    )
    decision_path = DECISIONS_DIR / f"{node_id}.md"
    decision_path.write_text(content, encoding="utf-8")
    index_path = DECISIONS_DIR / "INDEX.md"
    entry = f"- [ADR-{next_num:04d}]({node_id}.md) — {title}\n"
    if index_path.exists():
        existing = index_path.read_text(encoding="utf-8", errors="replace").rstrip("\n")
        index_path.write_text(existing + "\n" + entry, encoding="utf-8")
    else:
        index_path.write_text("# 決策紀錄索引（ADR）\n\n" + entry, encoding="utf-8")
    AUTH.write_audit(
        auth, "decision.create", decision_path, None, file_sha256(decision_path),
        before_state="absent", after_state=body.status,
    )
    return {"id": node_id}


@app.post("/api/decisions/layout", tags=["owner-control"])
def save_decision_layout(body: DecisionLayoutRequest, request: Request):
    auth = _auth_context(request)
    DECISIONS_DIR.mkdir(parents=True, exist_ok=True)
    positions = {}
    for key, value in body.positions.items():
        if isinstance(value, dict) and re.fullmatch(r"ADR-[\w-]+", key):
            try:
                positions[key] = {"x": float(value.get("x", 0)), "y": float(value.get("y", 0))}
            except (TypeError, ValueError):
                continue
    before_hash = file_sha256(DECISIONS_LAYOUT)
    DECISIONS_LAYOUT.write_text(json.dumps(positions, ensure_ascii=False, indent=2), encoding="utf-8")
    AUTH.write_audit(
        auth, "decision.layout", DECISIONS_LAYOUT, before_hash, file_sha256(DECISIONS_LAYOUT),
        before_state="existing" if before_hash else "absent", after_state=f"saved:{len(positions)}",
    )
    return {"ok": True, "saved": len(positions)}


@app.post("/api/decisions/{node_id}/status", tags=["owner-control"])
def set_decision_status(node_id: str, body: DecisionStatusRequest, request: Request):
    """Authenticated owner status change with an append-only audit receipt."""
    auth = _auth_context(request)
    if not re.fullmatch(r"ADR-[\w-]+", node_id):
        raise HTTPException(status_code=400, detail="invalid node id")
    if body.status not in {"proposed", "accepted", "landed", "superseded"}:
        raise HTTPException(status_code=400, detail="invalid status")
    path = DECISIONS_DIR / f"{node_id}.md"
    if not path.exists():
        raise HTTPException(status_code=404, detail="decision not found")
    before_hash = file_sha256(path)
    text = path.read_text(encoding="utf-8", errors="replace")
    before_status = _field(text, "status") or "unknown"
    new_text, count = re.subn(r"(?m)^status:.*$", f"status: {body.status}", text, count=1)
    if not count:
        new_text = text.rstrip("\n") + f"\nstatus: {body.status}\n"
    stamp = datetime.now().strftime("%Y-%m-%d %H:%M")
    evidence = body.evidence.strip()
    audit = f"- {stamp} {auth.actor_id} 標記 {body.status} [auth={auth.auth_method}; request_id={auth.request_id}]" + (f"：{evidence}" if evidence else "")
    if "## 狀態軌跡" in new_text:
        new_text = new_text.rstrip("\n") + f"\n{audit}\n"
    else:
        new_text = new_text.rstrip("\n") + f"\n\n## 狀態軌跡\n\n{audit}\n"
    path.write_text(new_text, encoding="utf-8")
    AUTH.write_audit(
        auth, "decision.status", path, before_hash, file_sha256(path),
        before_state=before_status, after_state=body.status,
    )
    return {"ok": True, "status": body.status}


@app.post("/api/decisions/{node_id}/links", tags=["owner-control"])
def add_decision_link(node_id: str, body: DecisionLinkRequest, request: Request):
    auth = _auth_context(request)
    if not re.fullmatch(r"ADR-[\w-]+", node_id):
        raise HTTPException(status_code=400, detail="invalid node id")
    path = DECISIONS_DIR / f"{node_id}.md"
    target = body.target.strip()
    if not path.exists():
        raise HTTPException(status_code=404, detail="decision not found")
    if not re.fullmatch(r"ADR-[\w-]+", target) or not (DECISIONS_DIR / f"{target}.md").exists():
        raise HTTPException(status_code=404, detail="target not found")
    text = path.read_text(encoding="utf-8", errors="replace")
    if f"[[{target}]]" in text:
        return {"ok": True, "already_linked": True}
    before_hash = file_sha256(path)

    def _append(match: re.Match) -> str:
        line = match.group(0)
        if line.strip() == "links: none":
            line = "links:"
        return line.rstrip() + f" [[{target}]]"

    new_text, count = re.subn(r"(?m)^links:.*$", _append, text, count=1)
    if not count:
        new_text = text.rstrip("\n") + f"\n\nlinks: [[{target}]]\n"
    path.write_text(new_text, encoding="utf-8")
    AUTH.write_audit(
        auth, "decision.link", path, before_hash, file_sha256(path),
        before_state="unlinked", after_state=f"linked:{target}",
    )
    return {"ok": True}


@app.get("/api/workflows", tags=["public-read"])
def list_workflows():
    """Return root-ticket lifecycle views for the Hermes supervisor UI."""
    return _list_workflows()


@app.post("/api/workflows/{task_id}/control", tags=["owner-control"])
def control_workflow(task_id: str, body: WorkflowControlRequest, request: Request):
    auth = _auth_context(request)
    if body.action not in {"pause", "resume", "retry"}:
        raise HTTPException(status_code=400, detail="invalid workflow action")
    safe_id = re.sub(r"[^A-Za-z0-9_.-]+", "-", task_id).strip("-")
    control_path = WORKFLOW_CONTROL_DIR / safe_id / "CONTROL.json"
    before_hash = file_sha256(control_path)
    result = _run_control_script(
        "set_workflow_control.ps1",
        [
            "-RootDispatchId", task_id,
            "-Action", body.action,
            "-ActorId", auth.actor_id,
            "-AuthMethod", auth.auth_method,
            "-RequestId", auth.request_id,
        ],
    )
    supervisor = None
    if body.action in {"resume", "retry"}:
        supervisor = _run_control_script(
            "workflow_supervisor.ps1",
            ["-RootDispatchId", task_id],
        )
    AUTH.write_audit(
        auth, "workflow.control", control_path, before_hash, file_sha256(control_path),
        before_state="existing" if before_hash else "absent", after_state=body.action,
    )
    return {
        "ok": True,
        "action": body.action,
        "control_output": result.get("output", ""),
        "supervisor_output": supervisor.get("output", "") if supervisor else "",
        "message": (
            "暫停要求已記錄，將在目前步驟結束後生效。"
            if body.action == "pause"
            else "控制要求已記錄，Supervisor 已執行狀態檢查。"
        ),
    }


@app.get("/api/approvals", tags=["public-read"])
def list_approvals():
    items = [item for item in _list_escalations() if item["josh_action_required"]]
    return {"total": len(items), "items": items}


@app.post("/api/approvals/{task_id}/decision", tags=["owner-control"])
def decide_approval(
    task_id: str,
    body: EscalationDecisionRequest,
    request: Request,
):
    auth = _auth_context(request)
    if body.decision not in {"approve", "modify", "stop"}:
        raise HTTPException(status_code=400, detail="invalid escalation decision")
    normalized_note = body.note.strip()
    if "\ufffd" in body.note or (
        normalized_note
        and re.fullmatch(r"[?？\s]+", normalized_note) is not None
        and ("?" in normalized_note or "？" in normalized_note)
    ):
        raise HTTPException(
            status_code=400,
            detail="decision note encoding invalid; send UTF-8 JSON with charset=utf-8",
        )
    safe_id = re.sub(r"[^A-Za-z0-9_.-]+", "-", task_id).strip("-")
    escalation_dir = ESCALATIONS_DIR / safe_id
    resolution_path = escalation_dir / "RESOLUTION.json"
    before_hash = file_sha256(resolution_path)
    try:
        receipt_path = AUTH.issue_escalation_decision_receipt(
            auth, task_id, body.decision, escalation_dir
        )
    except (PermissionError, ValueError, OSError) as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc
    AUTH.write_audit(
        auth,
        "approval.receipt_issued",
        receipt_path,
        None,
        file_sha256(receipt_path),
        before_state="owner_session_verified",
        after_state="short_lived_receipt_issued",
    )
    result = _run_control_script(
        "decide_escalation.ps1",
        [
            "-TaskId",
            task_id,
            "-Decision",
            body.decision,
            "-Note",
            body.note,
            "-ActorId",
            auth.actor_id,
            "-AuthMethod",
            auth.auth_method,
            "-RequestId",
            auth.request_id,
            "-ReceiptPath",
            str(receipt_path),
        ],
    )
    for line in result.get("output", "").splitlines():
        if line.startswith("resolution_path="):
            resolution_path = Path(line.split("=", 1)[1])
            break
    if body.decision in {"approve", "modify"}:
        escalations = _list_escalations()
        esc = next((e for e in escalations if e["task_id"] == task_id), None)
        esc_source = esc.get("source", "") if esc else ""
        if esc_source == "raw_intake_approval":
            _run_control_script(
                "promote_draft.ps1",
                ["-DraftId", task_id],
            )
        else:
            _run_control_script(
                "workflow_supervisor.ps1",
                ["-RootDispatchId", task_id],
            )
    AUTH.write_audit(
        auth, "approval.decision", resolution_path, before_hash, file_sha256(resolution_path),
        before_state="awaiting_owner", after_state=body.decision,
    )
    return result


@app.get("/api/escalations", tags=["public-read"])
def list_escalations(include_ci_fixtures: bool = False):
    """List all escalations with resolved vs awaiting_josh distinction."""
    items = _list_escalations()
    if not include_ci_fixtures:
        items = [
            item for item in items
            if not _is_ci_fixture_namespace(item.get("task_id"))
        ]
    awaiting = [i for i in items if i["josh_action_required"]]
    resolved = [i for i in items if not i["josh_action_required"]]
    return {
        "total": len(items),
        "awaiting_josh": len(awaiting),
        "resolved": len(resolved),
        "items": items,
    }


@app.get("/api/leads", tags=["public-read"])
def list_leads():
    return _list_leads()


@app.get("/api/proposals", tags=["public-read"])
def list_proposals():
    return _list_proposals()


@app.get("/api/logs", tags=["public-read"])
def list_logs():
    return ["hermes", "codex", "claude"]


@app.websocket("/ws/logs/{log_name}")
async def ws_log(websocket: WebSocket, log_name: str):
    await websocket.accept()
    try:
        if log_name in {"hermes", "codex", "claude"}:
            await _tail_live_source(log_name, websocket)
        else:
            await websocket.send_text(
                json.dumps(
                    {"type": "error", "message": "Unsupported log source"},
                    ensure_ascii=False,
                )
            )
    except WebSocketDisconnect:
        pass


@app.websocket("/ws/bridge/latest")
async def ws_bridge_latest(websocket: WebSocket):
    """Stream updates when new bridge sessions appear."""
    await websocket.accept()
    known = set(d.name for d in LIVE_BRIDGE_DIR.iterdir() if d.is_dir()) if LIVE_BRIDGE_DIR.exists() else set()
    try:
        while True:
            try:
                message = await asyncio.wait_for(websocket.receive(), timeout=2)
                if message.get("type") == "websocket.disconnect":
                    break
            except TimeoutError:
                pass
            if not LIVE_BRIDGE_DIR.exists():
                continue
            current = set(d.name for d in LIVE_BRIDGE_DIR.iterdir() if d.is_dir())
            new = current - known
            for sid in sorted(new):
                data = _read_bridge_session(sid)
                await websocket.send_text(json.dumps({"type": "new_session", "session": data}))
            known = current
    except WebSocketDisconnect:
        pass


# Known context window limits by model keyword
_MODEL_CONTEXT = {
    "llama-3.1-8b": 131_072,
    "llama-3.3": 131_072,
    "llama-3.1-70b": 131_072,
    "llama-3.1-405b": 131_072,
    "mixtral": 32_768,
    "gemini-3-flash": 1_000_000,
    "gemini-2.5": 1_000_000,
    "gemini-1.5-pro": 2_000_000,
    "claude-opus": 200_000,
    "claude-sonnet": 200_000,
    "claude-haiku": 200_000,
    "gpt-4": 128_000,
    "gpt-5": 128_000,
}

def _model_context_limit(model: str | None) -> int | None:
    if not model:
        return None
    m = (model or "").lower()
    for key, limit in _MODEL_CONTEXT.items():
        if key in m:
            return limit
    return None


def _context_window_pct() -> dict:
    """
    Context window usage = most recent session's token total vs model limit.
    This is the best approximation without instrumenting the live session.
    """
    try:
        latest_session = fetch_context_window_source()
        if latest_session is None:
            return {"pct": None, "used": None, "total": None, "model": None, "note": "no recorded session"}
        model = latest_session.get("model")
        inp = latest_session.get("input_tokens") or 0
        out = latest_session.get("output_tokens") or 0
        cache = latest_session.get("cache_read_tokens") or 0
        used = inp + out + cache
        total = _model_context_limit(model)
        if total is None:
            return {"pct": None, "used": used, "total": None, "model": model, "note": "unknown model context limit"}
        pct = round(min(used / total * 100, 100), 1)
        return {
            "pct": pct, "used": used, "total": total,
            "input": inp, "output": out, "cache": cache,
            "model": model,
            "note": "last session"
        }
    except HermesMetricsUnavailable:
        return {"pct": None, "used": None, "total": None, "model": None, "note": "usage database unavailable"}
    except (HermesMetricsResponseError, KeyError, TypeError):
        return {"pct": None, "used": None, "total": None, "model": None, "note": "usage query failed"}


@app.get("/api/context", tags=["public-read"])
def get_context():
    return _context_window_pct()

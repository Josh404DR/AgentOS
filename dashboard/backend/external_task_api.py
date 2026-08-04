"""
AgentOS External Task API — SCC integration P0.

SCC (demand side) creates jobs; AgentOS (contractor) executes them through
its existing, governance-bound queue. This module ONLY translates HTTP
requests into standard TASK.md packets on disk and reads execution
artifacts back. It does not touch queue/dispatch/verify mechanics, and it
exposes no approval/control operations.

Auth: machine-to-machine via `X-AgentOS-API-Key` header, compared in
constant time against `AGENTOS_SCC_API_KEY` (process env, HKCU User-scope
fallback — same pattern as hermes_metrics_client / F14). Fail-closed:
key not configured => 503 for every authenticated endpoint.
"""
from __future__ import annotations

import hashlib
import hmac
import json
import os
import re
import secrets
from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field

try:
    import winreg
except ImportError:  # pragma: no cover - Windows is the deployed platform.
    winreg = None

BACKEND_DIR = Path(__file__).parent
AGENTOS_ROOT = BACKEND_DIR.parent.parent
CODEX_TASKS_DIR = AGENTOS_ROOT / "data" / "codex_tasks"
ESCALATIONS_DIR = AGENTOS_ROOT / "data" / "escalations"
AGENTS_MD = AGENTOS_ROOT / "AGENTS.md"
GOVERNANCE_STATUS = AGENTOS_ROOT / "data" / "governance" / "governance_status.json"
QUEUE_INDEX = AGENTOS_ROOT / "data" / "queue_runs" / "ACTIVE_TASK_INDEX.json"

API_KEY_ENV = "AGENTOS_SCC_API_KEY"
MIN_KEY_LENGTH = 32

_DISPATCH_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,90}$")
_SLUG_RE = re.compile(r"[^a-z0-9]+")

ALLOWED_ROUTES = {"Codex CLI", "Claude CLI"}
ALLOWED_MODES = {"build", "plan", "verify"}

router = APIRouter(prefix="/api/v1/external", tags=["external-scc"])


# ---------------------------------------------------------------------------
# Auth (fail-closed, constant-time)
# ---------------------------------------------------------------------------
def _configured_key() -> str:
    value = os.environ.get(API_KEY_ENV)
    if value is None and winreg is not None:
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as key:
                raw, _ = winreg.QueryValueEx(key, API_KEY_ENV)
                if isinstance(raw, str):
                    value = raw
        except OSError:
            value = None
    return (value or "").strip()


def _require_api_key(request: Request) -> None:
    configured = _configured_key()
    if len(configured) < MIN_KEY_LENGTH:
        # Not configured (or dangerously short) => refuse everything.
        raise HTTPException(
            status_code=503,
            detail="external task API is not configured on this host",
        )
    provided = (request.headers.get("x-agentos-api-key") or "").strip()
    if not provided or not hmac.compare_digest(
        provided.encode("utf-8"), configured.encode("utf-8")
    ):
        raise HTTPException(status_code=401, detail="invalid api key")


# ---------------------------------------------------------------------------
# Governance binding (computed live, cross-checked, fail-closed)
# ---------------------------------------------------------------------------
def _governance_binding() -> tuple[str, str]:
    if not AGENTS_MD.is_file():
        raise HTTPException(status_code=503, detail="governance canonical file missing")
    live_hash = hashlib.sha256(AGENTS_MD.read_bytes()).hexdigest().upper()
    version = "unknown"
    try:
        status = json.loads(GOVERNANCE_STATUS.read_text(encoding="utf-8"))
        version = str(status.get("governance_version") or "unknown")
        recorded = str(status.get("canonical_hash") or "").upper()
        if recorded and recorded != live_hash:
            # AGENTS.md changed but governance status was not refreshed.
            # Do not mint tickets against an unverified governance state.
            raise HTTPException(
                status_code=503,
                detail="governance hash drift detected; refusing external intake",
            )
    except (OSError, json.JSONDecodeError):
        raise HTTPException(
            status_code=503, detail="governance status unavailable"
        ) from None
    return version, live_hash


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _safe_task_dir(dispatch_id: str) -> Path:
    if not _DISPATCH_ID_RE.match(dispatch_id):
        raise HTTPException(status_code=400, detail="invalid dispatch_id")
    task_dir = (CODEX_TASKS_DIR / dispatch_id).resolve()
    if task_dir.parent != CODEX_TASKS_DIR.resolve():
        raise HTTPException(status_code=400, detail="invalid dispatch_id")
    return task_dir


def _read_field(task_text: str, name: str) -> str:
    match = re.search(rf"^{re.escape(name)}:\s*(.+)$", task_text, re.MULTILINE)
    return match.group(1).strip() if match else ""


def _utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _queue_runner_alive() -> bool:
    """Use the queue index heartbeat without inspecting process command lines."""
    try:
        age = datetime.now(timezone.utc).timestamp() - QUEUE_INDEX.stat().st_mtime
    except OSError:
        return False
    return 0 <= age <= 180


# ---------------------------------------------------------------------------
# Request/response models
# ---------------------------------------------------------------------------
class ExternalTaskCreate(BaseModel):
    title: str = Field(min_length=3, max_length=200)
    instructions: str = Field(min_length=10, max_length=20000)
    route_to: str = "Codex CLI"
    codex_mode: str = "build"
    risk_note: str = Field(default="", max_length=2000)
    client_ref: str = Field(default="", max_length=120)


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------
@router.get("/health")
def external_health():
    """Unauthenticated liveness probe for SCC. Reveals nothing sensitive."""
    key_ok = len(_configured_key()) >= MIN_KEY_LENGTH
    return {
        "queue_runner_alive": _queue_runner_alive(),
        "api_key_configured": key_ok,
    }


@router.post("/tasks")
def create_external_task(body: ExternalTaskCreate, request: Request):
    _require_api_key(request)

    if "\n" in body.title or "\r" in body.title:
        raise HTTPException(status_code=400, detail="title must be a single line")
    if "\n" in body.client_ref or "\r" in body.client_ref:
        raise HTTPException(status_code=400, detail="client_ref must be a single line")

    route = body.route_to.strip() or "Codex CLI"
    if route not in ALLOWED_ROUTES:
        raise HTTPException(status_code=400, detail="route_to must be 'Codex CLI' or 'Claude CLI'")
    mode = body.codex_mode.strip().lower() or "build"
    if mode not in ALLOWED_MODES:
        raise HTTPException(status_code=400, detail="codex_mode must be build|plan|verify")

    version, gov_hash = _governance_binding()

    slug = _SLUG_RE.sub("-", body.title.lower()).strip("-")[:40] or "task"
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    dispatch_id = f"scc-{stamp}-{slug}-{secrets.token_hex(2)}"
    task_dir = _safe_task_dir(dispatch_id)
    if task_dir.exists():
        raise HTTPException(status_code=409, detail="dispatch_id collision; retry")

    client_ref = body.client_ref.strip()
    risk_note = body.risk_note.strip()
    packet_route = "Codex" if route == "Codex CLI" else "Claude"
    task_md = f"""# Task Packet — [SCC外部工單] {body.title.strip()}

dispatch_id: {dispatch_id}
parent_dispatch_id: none
type: BUILDER_TASK
assigned_to: {'Codex' if route == 'Codex CLI' else 'Claude Worker'}
route_to: {packet_route}
codex_mode: {mode}
task_kind: scc_external_request
task_type: Complex
task_status: ready
dispatch_status: ready_to_route
requires_josh_approval: false
approval: 經 external task API 建立（SCC 需求方）；AgentOS 治理（RISK_RULES、
  escalation gate、獨立 Verify）對本工單完全適用，API 不提供任何繞過。
source: scc-external-api
client_ref: {client_ref or 'none'}
created_at: {_utc_now()}
governance_version: {version}
governance_hash: {gov_hash}

## 任務目標（SCC 需求方原文）

{body.instructions.strip()}

## 風險備註（SCC 提供）

{risk_note or '（無）'}

## 治理約束（AgentOS 接案方標準條款，不可省略）

- 遵守 `E:\\AgentOS\\AGENTS.md` 現行版本；開工前核對 governance hash。
- 命中 `docs\\governance\\RISK_RULES.md` 任一條即停止並建立 escalation，
  等待 owner 決策；不得因本工單來自外部系統而放寬。
- 不捏造：拿不到的狀態寫 unknown；估算標明 estimate。
- 完成後寫 `OUTPUTS\\RESULT.md`（含 Evidence Block），交由獨立 fresh
  read-only Verify session 驗證，實作者不自驗。
"""
    prompt_md = f"""# AgentOS SCC 外部工單派送

執行工單 `{dispatch_id}`。先讀取並遵守：

- `E:\\AgentOS\\AGENTS.md`
- `E:\\AgentOS\\data\\codex_tasks\\{dispatch_id}\\TASK.md`

開工前必須執行 `scripts\\assert_governance_ready.ps1` 並核對工單的
governance_version/hash。工作範圍、風險邊界、驗收條件與回報要求皆以
TASK.md 為準。完成後寫入 `OUTPUTS\\RESULT.md`；實作者不得自行宣稱
最終 PASS，必須交 fresh read-only Codex Verify。
"""
    task_dir.mkdir(parents=True, exist_ok=False)
    (task_dir / "TASK.md").write_text(task_md, encoding="utf-8", newline="\n")
    (task_dir / "PROMPT_FOR_CODEX.md").write_text(
        prompt_md, encoding="utf-8", newline="\n"
    )

    return {
        "dispatch_id": dispatch_id,
        "client_ref": client_ref or None,
        "status": "queued",
        "note": "picked up by the AgentOS task queue runner (filesystem poll, <=60s)",
    }


@router.get("/tasks/{dispatch_id}")
def external_task_status(dispatch_id: str, request: Request):
    _require_api_key(request)
    task_dir = _safe_task_dir(dispatch_id)
    task_file = task_dir / "TASK.md"
    if not task_file.is_file():
        raise HTTPException(status_code=404, detail="task not found")
    task_text = task_file.read_text(encoding="utf-8", errors="replace")

    heartbeat = None
    hb_file = task_dir / "OUTPUTS" / "HEARTBEAT.json"
    if hb_file.is_file():
        try:
            heartbeat = json.loads(hb_file.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            heartbeat = {"error": "heartbeat unreadable"}

    result_exists = (task_dir / "OUTPUTS" / "RESULT.md").is_file()

    verify_verdict = None
    verify_result = CODEX_TASKS_DIR / f"{dispatch_id}-codex-verify" / "OUTPUTS" / "VERIFY_RESULT.md"
    if not verify_result.is_file():
        verify_result = task_dir / "OUTPUTS" / "VERIFY_RESULT.md"
    if verify_result.is_file():
        try:
            first = verify_result.read_text(encoding="utf-8", errors="replace").splitlines()
            for line in first[:5]:
                lowered = line.strip().lower()
                if lowered.startswith("verdict:") or lowered.startswith("驗證結果"):
                    verify_verdict = line.strip()
                    break
        except OSError:
            verify_verdict = None

    escalation_dir = ESCALATIONS_DIR / dispatch_id
    escalation_pending = escalation_dir.is_dir() and not any(
        escalation_dir.glob("RESOLUTION*.json")
    )

    return {
        "dispatch_id": dispatch_id,
        "client_ref": (_read_field(task_text, "client_ref") or "none").replace("none", "") or None,
        "task_status": _read_field(task_text, "task_status") or "unknown",
        "dispatch_status": _read_field(task_text, "dispatch_status") or "unknown",
        "result_available": result_exists,
        "verify_verdict": verify_verdict,
        "escalation_pending": escalation_pending,
        "heartbeat": heartbeat,
    }


@router.get("/tasks/{dispatch_id}/result")
def external_task_result(dispatch_id: str, request: Request):
    _require_api_key(request)
    task_dir = _safe_task_dir(dispatch_id)
    if not (task_dir / "TASK.md").is_file():
        raise HTTPException(status_code=404, detail="task not found")
    result_file = task_dir / "OUTPUTS" / "RESULT.md"
    if not result_file.is_file():
        raise HTTPException(status_code=409, detail="result not available yet")
    outputs = sorted(
        p.name for p in (task_dir / "OUTPUTS").iterdir() if p.is_file()
    )
    return {
        "dispatch_id": dispatch_id,
        "result_markdown": result_file.read_text(encoding="utf-8", errors="replace"),
        "output_files": outputs,
    }

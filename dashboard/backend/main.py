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
import sqlite3
import subprocess
import sys
import httpx
from datetime import datetime, timezone
from pathlib import Path
from typing import AsyncGenerator
from urllib.parse import quote


from fastapi import FastAPI, HTTPException, Request, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel

# ---------------------------------------------------------------------------
# Paths — all resolved relative to this file's location (dashboard/backend/)
# ---------------------------------------------------------------------------
BACKEND_DIR = Path(__file__).parent
DASHBOARD_DIR = BACKEND_DIR.parent
AGENTOS_ROOT = DASHBOARD_DIR.parent

HERMES_DB = Path.home() / "AppData" / "Local" / "hermes" / "state.db"
HERMES_EXE = Path("E:/AI_Projects_Hub/External_AI_Agents/hermes-agent/.venv/Scripts/hermes.exe")
HERMES_ROOT = HERMES_EXE.parent.parent.parent

LOGS_DIR = AGENTOS_ROOT / "logs"
LIVE_BRIDGE_DIR = AGENTOS_ROOT / "data" / "live_bridge"
CODEX_TASKS_DIR = AGENTOS_ROOT / "data" / "codex_tasks"
ESCALATIONS_DIR = AGENTOS_ROOT / "data" / "escalations"
QUEUE_RUNS_DIR = AGENTOS_ROOT / "data" / "queue_runs"
WORKFLOW_CONTROL_DIR = AGENTOS_ROOT / "data" / "workflow_control"
LEADS_DIR = AGENTOS_ROOT / "data" / "leads"
PROPOSALS_DIR = AGENTOS_ROOT / "data" / "proposals"
USAGE_DIR = AGENTOS_ROOT / "data" / "usage"
OBSIDIAN_VAULT_DIR = AGENTOS_ROOT / "exports" / "obsidian_agentos"
GOVERNANCE_STATUS = AGENTOS_ROOT / "data" / "governance" / "governance_status.json"
GOVERNANCE_SYNC = AGENTOS_ROOT / "scripts" / "sync_shared_governance.ps1"

app = FastAPI(title="AgentOS Dashboard API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


class WorkflowControlRequest(BaseModel):
    action: str


class EscalationDecisionRequest(BaseModel):
    decision: str
    note: str = ""


def _require_local_request(request: Request) -> None:
    host = request.client.host if request.client else ""
    if host not in {"127.0.0.1", "::1", "localhost"}:
        raise HTTPException(status_code=403, detail="local requests only")


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
    """Read token usage totals from Hermes state.db."""
    if not HERMES_DB.exists():
        return {"error": "state.db not found", "path": str(HERMES_DB)}
    try:
        con = sqlite3.connect(str(HERMES_DB))
        con.row_factory = sqlite3.Row
        cur = con.cursor()

        # Total row
        cur.execute("""
            SELECT
                COUNT(*) as session_count,
                SUM(api_call_count) as api_calls,
                SUM(message_count) as messages,
                SUM(tool_call_count) as tool_calls,
                SUM(input_tokens) as input_tokens,
                SUM(output_tokens) as output_tokens,
                SUM(cache_read_tokens) as cache_read,
                SUM(cache_write_tokens) as cache_write,
                SUM(estimated_cost_usd) as est_cost,
                SUM(actual_cost_usd) as actual_cost,
                MAX(started_at) as latest_session
            FROM sessions
        """)
        total = dict(cur.fetchone())

        # Last 5h window (rolling) — started_at is Unix REAL, confirmed
        cur.execute("""
            SELECT
                COUNT(*) as session_count,
                COALESCE(SUM(input_tokens),0) as input_tokens,
                COALESCE(SUM(output_tokens),0) as output_tokens,
                COALESCE(SUM(cache_read_tokens),0) as cache_read,
                COALESCE(SUM(reasoning_tokens),0) as reasoning_tokens,
                COALESCE(SUM(estimated_cost_usd),0) as est_cost
            FROM sessions
            WHERE started_at >= (strftime('%s','now') - 18000)
        """)
        window_5h = dict(cur.fetchone())

        # Last 7 days
        cur.execute("""
            SELECT
                COUNT(*) as session_count,
                COALESCE(SUM(input_tokens),0) as input_tokens,
                COALESCE(SUM(output_tokens),0) as output_tokens,
                COALESCE(SUM(cache_read_tokens),0) as cache_read,
                COALESCE(SUM(reasoning_tokens),0) as reasoning_tokens,
                COALESCE(SUM(estimated_cost_usd),0) as est_cost
            FROM sessions
            WHERE started_at >= (strftime('%s','now') - 604800)
        """)
        window_7d = dict(cur.fetchone())

        # Current model (most recent session)
        cur.execute("SELECT model FROM sessions ORDER BY started_at DESC LIMIT 1")
        model_row = cur.fetchone()
        current_model = model_row[0] if model_row else None

        # Recent sessions (last 20)
        cur.execute("""
            SELECT
                id, source, model,
                input_tokens, output_tokens, cache_read_tokens,
                estimated_cost_usd, started_at, ended_at
            FROM sessions
            ORDER BY started_at DESC
            LIMIT 20
        """)
        recent = [dict(r) for r in cur.fetchall()]

        con.close()
        return {
            "total": total,
            "window_5h": window_5h,
            "window_7d": window_7d,
            "recent_sessions": recent,
            "current_model": current_model,
        }
    except Exception as e:
        return {"error": str(e)}


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
    tasks = _list_codex_tasks()
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
                "state": "completed" if root["has_result"] else "pending",
            },
            {
                "key": "worker",
                "label": "Claude 實作",
                "state": (
                    "processing" if any(node["normalized_status"] == "processing" for node in workers)
                    else "completed" if workers and not pending_workers
                    else "pending"
                ),
            },
            {
                "key": "verify",
                "label": "Codex 驗證",
                "state": (
                    "processing" if any(node["normalized_status"] == "processing" for node in verifiers)
                    else "completed" if "PASS" in verdicts
                    else "blocked" if any(value in {"FAIL", "NEEDS_HUMAN_DECISION", "blocked"} for value in verdicts)
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
        workflows.append({
            "dispatch_id": dispatch_id,
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
                    "dispatch_id": node["dispatch_id"],
                    "route_to": node["route_to"],
                    "status": node["normalized_status"],
                    "review_status": node["review_status"],
                    "result_path": node["result_path"],
                }
                for node in nodes
            ],
        })
    return sorted(workflows, key=lambda item: item["updated_at"], reverse=True)


def _read_codex_task(task_id: str) -> dict:
    task_dir = CODEX_TASKS_DIR / task_id
    if not task_dir.exists():
        return {"error": "task not found"}
    result = {"id": task_id, "files": {}}
    for f in task_dir.rglob("*.md"):
        rel = str(f.relative_to(task_dir))
        try:
            result["files"][rel] = f.read_text(encoding="utf-8", errors="replace")
        except Exception:
            result["files"][rel] = "[unreadable]"
    return result


def _list_escalations() -> list[dict]:
    """List all escalations from ESCALATION_INDEX.jsonl, enriched with resolution status."""
    index_path = ESCALATIONS_DIR / "ESCALATION_INDEX.jsonl"
    if not index_path.exists():
        return []
    results = []
    seen = set()
    for line in index_path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except Exception:
            continue
        task_id = entry.get("task_id", "")
        # De-duplicate: keep only the first occurrence per task_id
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

@app.get("/api/health")
def health():
    return {"status": "ok", "agentos_root": str(AGENTOS_ROOT)}


@app.get("/api/governance")
def governance():
    """Refresh and return local governance drift without invoking a model."""
    refresh_error = None
    if GOVERNANCE_SYNC.exists():
        try:
            completed = subprocess.run(
                [
                    "powershell.exe",
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    str(GOVERNANCE_SYNC),
                ],
                cwd=str(AGENTOS_ROOT),
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=20,
            )
            if completed.returncode != 0:
                refresh_error = (completed.stderr or completed.stdout).strip()
        except Exception as exc:
            refresh_error = f"{type(exc).__name__}: {exc}"
    else:
        refresh_error = "governance sync script missing"

    if not GOVERNANCE_STATUS.exists():
        return JSONResponse(
            status_code=503,
            content={
                "governance_status": "blocked",
                "refresh_error": refresh_error or "status file missing",
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
    if refresh_error:
        payload["refresh_error"] = refresh_error
    return payload


@app.get("/api/usage")
def get_usage():
    return _read_db_usage()


@app.get("/api/usage/summary")
def get_usage_summary():
    return _get_latest_usage_summary()


@app.get("/api/bridge")
def list_bridge():
    return _list_bridge_sessions()


@app.get("/api/bridge/{session_id}")
def get_bridge_session(session_id: str):
    return _read_bridge_session(session_id)


@app.get("/api/tasks")
def list_tasks():
    return _list_codex_tasks()


@app.get("/api/tasks/{task_id}")
def get_task(task_id: str):
    return _read_codex_task(task_id)


@app.get("/api/workflows")
def list_workflows():
    """Return root-ticket lifecycle views for the Hermes supervisor UI."""
    return _list_workflows()


@app.post("/api/workflows/{task_id}/control")
def control_workflow(task_id: str, body: WorkflowControlRequest, request: Request):
    _require_local_request(request)
    if body.action not in {"pause", "resume", "retry"}:
        raise HTTPException(status_code=400, detail="invalid workflow action")
    result = _run_control_script(
        "set_workflow_control.ps1",
        ["-RootDispatchId", task_id, "-Action", body.action],
    )
    supervisor = None
    if body.action in {"resume", "retry"}:
        supervisor = _run_control_script(
            "workflow_supervisor.ps1",
            ["-RootDispatchId", task_id],
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


@app.get("/api/approvals")
def list_approvals():
    items = [item for item in _list_escalations() if item["josh_action_required"]]
    return {"total": len(items), "items": items}


@app.post("/api/approvals/{task_id}/decision")
def decide_approval(
    task_id: str,
    body: EscalationDecisionRequest,
    request: Request,
):
    _require_local_request(request)
    if body.decision not in {"approve", "modify", "stop"}:
        raise HTTPException(status_code=400, detail="invalid escalation decision")
    result = _run_control_script(
        "decide_escalation.ps1",
        [
            "-TaskId",
            task_id,
            "-Decision",
            body.decision,
            "-Note",
            body.note,
        ],
    )
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
    return result


@app.get("/api/escalations")
def list_escalations():
    """List all escalations with resolved vs awaiting_josh distinction."""
    items = _list_escalations()
    awaiting = [i for i in items if i["josh_action_required"]]
    resolved = [i for i in items if not i["josh_action_required"]]
    return {
        "total": len(items),
        "awaiting_josh": len(awaiting),
        "resolved": len(resolved),
        "items": items,
    }


@app.get("/api/leads")
def list_leads():
    return _list_leads()


@app.get("/api/proposals")
def list_proposals():
    return _list_proposals()


@app.get("/api/logs")
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
            await asyncio.sleep(2)
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


# ---------------------------------------------------------------------------
# Chat API — calls hermes.exe -z directly (independent of Telegram gateway)
# ---------------------------------------------------------------------------

class ChatRequest(BaseModel):
    message: str


def _snapshot_tokens() -> dict:
    """Read current token totals from state.db for delta calculation."""
    if not HERMES_DB.exists():
        return {}
    try:
        con = sqlite3.connect(str(HERMES_DB))
        cur = con.cursor()
        cur.execute("SELECT SUM(input_tokens), SUM(output_tokens), SUM(cache_read_tokens) FROM sessions")
        row = cur.fetchone()
        con.close()
        return {"input": row[0] or 0, "output": row[1] or 0, "cache": row[2] or 0}
    except Exception:
        return {}


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

def _model_context_limit(model: str | None) -> int:
    if not model:
        return 128_000
    m = (model or "").lower()
    for key, limit in _MODEL_CONTEXT.items():
        if key in m:
            return limit
    return 128_000


def _read_messages(limit: int = 50) -> list[dict]:
    """Read recent messages from state.db — uses 'timestamp' column."""
    if not HERMES_DB.exists():
        return []
    try:
        con = sqlite3.connect(str(HERMES_DB))
        con.row_factory = sqlite3.Row
        cur = con.cursor()
        cur.execute("""
            SELECT m.id, m.session_id, m.role, m.content, m.timestamp,
                   s.source, s.model
            FROM messages m
            LEFT JOIN sessions s ON m.session_id = s.id
            ORDER BY m.timestamp DESC
            LIMIT ?
        """, (limit,))
        rows = [dict(r) for r in cur.fetchall()]
        con.close()
        rows.reverse()
        return rows
    except Exception as e:
        return [{"error": str(e)}]


def _context_window_pct() -> dict:
    """
    Context window usage = most recent session's token total vs model limit.
    This is the best approximation without instrumenting the live session.
    """
    if not HERMES_DB.exists():
        return {"pct": 0, "used": 0, "total": 128_000, "model": None}
    try:
        con = sqlite3.connect(str(HERMES_DB))
        cur = con.cursor()
        cur.execute("""
            SELECT model, input_tokens, output_tokens, cache_read_tokens, cache_write_tokens
            FROM sessions
            ORDER BY started_at DESC
            LIMIT 1
        """)
        row = cur.fetchone()
        con.close()
        if not row:
            return {"pct": 0, "used": 0, "total": 128_000, "model": None}
        model = row[0]
        inp = row[1] or 0
        out = row[2] or 0
        cache = row[3] or 0
        used = inp + out + cache
        total = _model_context_limit(model)
        pct = round(min(used / total * 100, 100), 1)
        return {
            "pct": pct, "used": used, "total": total,
            "input": inp, "output": out, "cache": cache,
            "model": model,
            "note": "last session"
        }
    except Exception:
        return {"pct": 0, "used": 0, "total": 128_000, "model": None}


@app.post("/api/chat")
async def chat(req: ChatRequest):
    """
    Hermes Lite chat — calls Groq API directly.

    Why not hermes.exe -z:
    - Gemini: monthly cap hit (429)
    - Groq via hermes.exe: full request with 30 tool schemas ~21K tokens,
      exceeds Groq free-tier TPM limit of 6K → 413 every time.

    Solution (same as scripts/free_model_window.ps1 for Telegram):
    Call Groq API directly with a stripped system prompt, no tool schemas.
    """
    # Resolve GROQ_API_KEY from environment (user / machine level on Windows)
    api_key = (
        os.environ.get("GROQ_API_KEY")
        or os.environ.get("GROQ_API_KEY".lower())
        or ""
    )
    if not api_key:
        return {
            "error": "GROQ_API_KEY not set. Set it as a user environment variable.",
            "response": None,
            "mode": "hermes_lite",
        }

    HERMES_LITE_SYSTEM = (
        "You are Hermes Lite, the AgentOS web dashboard chat interface.\n"
        "Answer in the same language the user writes in.\n"
        "You have no tools in this mode — do not claim file, routing, fetch, "
        "model, or external actions unless the message contains explicit output.\n"
        "For real work (code, tasks, file ops), tell the user to dispatch via Codex.\n"
        "Be concise. Traditional Chinese preferred for short replies."
    )

    body = {
        "model": "llama-3.1-8b-instant",
        "messages": [
            {"role": "system", "content": HERMES_LITE_SYSTEM},
            {"role": "user", "content": req.message[:4000]},
        ],
        "max_tokens": 512,
        "temperature": 0.3,
    }

    ts = datetime.now(timezone.utc).isoformat()

    try:
        async with httpx.AsyncClient(timeout=45) as client:
            resp = await client.post(
                "https://api.groq.com/openai/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                    "User-Agent": "AgentOS-Dashboard/1.0",
                },
                json=body,
            )
            resp.raise_for_status()
            data = resp.json()

        response_text = data["choices"][0]["message"]["content"].strip()
        delta_tokens = data.get("usage", {}).get("total_tokens", 0)
        return {
            "response": response_text,
            "sent_at": ts,
            "delta_tokens": delta_tokens,
            "context": _context_window_pct(),
            "mode": "hermes_lite",
            "model": data.get("model", "llama-3.1-8b-instant"),
        }
    except httpx.HTTPStatusError as e:
        body_text = e.response.text[:300]
        return {"error": f"Groq HTTP {e.response.status_code}: {body_text}", "response": None, "mode": "hermes_lite"}
    except Exception as e:
        return {"error": str(e), "response": None, "mode": "hermes_lite"}


@app.get("/api/messages")
def get_messages(limit: int = 50):
    return _read_messages(limit)


@app.get("/api/context")
def get_context():
    return _context_window_pct()

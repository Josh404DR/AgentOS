#!/usr/bin/env python3
"""Audit Hermes token usage from the existing local state.db.

This reads aggregate session metadata only. It does not read message content.
The goal is to identify which Hermes work should stay on Gemini and which
low-risk work should be routed to Ollama.
"""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable


AGENTOS_ROOT = Path(__file__).resolve().parents[1]


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


DEFAULT_DB = Path(_load_runtime_config()["hermes"]["state_db"])
DEFAULT_OUT_DIR = Path("data") / "usage"


@dataclass
class SessionRow:
    id: str
    source: str
    model: str
    provider: str
    started_at: float
    ended_at: float | None
    end_reason: str
    message_count: int
    tool_call_count: int
    input_tokens: int
    output_tokens: int
    cache_read_tokens: int
    cache_write_tokens: int
    reasoning_tokens: int
    estimated_cost_usd: float
    actual_cost_usd: float
    cost_status: str
    api_call_count: int

    @property
    def non_cache_tokens(self) -> int:
        return self.input_tokens + self.output_tokens + self.cache_write_tokens + self.reasoning_tokens

    @property
    def total_tokens(self) -> int:
        return self.non_cache_tokens + self.cache_read_tokens


def _safe_int(value: object) -> int:
    try:
        return int(value or 0)
    except Exception:
        return 0


def _safe_float(value: object) -> float:
    try:
        return float(value or 0)
    except Exception:
        return 0.0


def _fmt_int(value: int) -> str:
    return f"{value:,}"


def _fmt_cost(value: float) -> str:
    return f"${value:.4f}"


def _fmt_time(epoch: float | None) -> str:
    if not epoch:
        return ""
    try:
        return datetime.fromtimestamp(float(epoch), tz=timezone.utc).astimezone().strftime("%Y-%m-%d %H:%M:%S %z")
    except Exception:
        return ""


def load_sessions(db_path: Path) -> list[SessionRow]:
    con = sqlite3.connect(db_path)
    con.row_factory = sqlite3.Row
    rows: list[SessionRow] = []
    for r in con.execute(
        """
        select id, source, model, billing_provider, started_at, ended_at,
               end_reason, message_count, tool_call_count,
               input_tokens, output_tokens, cache_read_tokens,
               cache_write_tokens, reasoning_tokens,
               estimated_cost_usd, actual_cost_usd, cost_status, api_call_count
        from sessions
        """
    ):
        rows.append(
            SessionRow(
                id=str(r["id"] or ""),
                source=str(r["source"] or ""),
                model=str(r["model"] or ""),
                provider=str(r["billing_provider"] or ""),
                started_at=_safe_float(r["started_at"]),
                ended_at=_safe_float(r["ended_at"]) if r["ended_at"] is not None else None,
                end_reason=str(r["end_reason"] or ""),
                message_count=_safe_int(r["message_count"]),
                tool_call_count=_safe_int(r["tool_call_count"]),
                input_tokens=_safe_int(r["input_tokens"]),
                output_tokens=_safe_int(r["output_tokens"]),
                cache_read_tokens=_safe_int(r["cache_read_tokens"]),
                cache_write_tokens=_safe_int(r["cache_write_tokens"]),
                reasoning_tokens=_safe_int(r["reasoning_tokens"]),
                estimated_cost_usd=_safe_float(r["estimated_cost_usd"]),
                actual_cost_usd=_safe_float(r["actual_cost_usd"]),
                cost_status=str(r["cost_status"] or ""),
                api_call_count=_safe_int(r["api_call_count"]),
            )
        )
    con.close()
    return rows


def filter_by_date(rows: Iterable[SessionRow], date: str | None) -> list[SessionRow]:
    if not date:
        return list(rows)
    out: list[SessionRow] = []
    for row in rows:
        day = datetime.fromtimestamp(row.started_at, tz=timezone.utc).astimezone().strftime("%Y-%m-%d")
        if day == date:
            out.append(row)
    return out


def classify(row: SessionRow) -> tuple[str, str]:
    """Return (work_type, routing_recommendation)."""
    sid = row.id.lower()
    source = row.source.lower()
    model = row.model.lower()

    if sid.startswith("cron_"):
        if row.tool_call_count <= 1 and row.message_count <= 8:
            return "scheduled_lightwork", "route_to_ollama_candidate"
        return "scheduled_tool_work", "review_before_routing"
    if "telegram" in source or "dm" in source:
        if row.non_cache_tokens < 20_000 and row.tool_call_count <= 1:
            return "telegram_lightwork", "route_to_ollama_candidate"
        return "telegram_heavywork", "keep_gemini_if_quality_needed"
    if "ollama" in model or model.startswith("qwen"):
        return "local_ollama", "already_local"
    if row.tool_call_count >= 3:
        return "tool_heavy_work", "keep_gemini_or_delegate"
    if row.non_cache_tokens == 0:
        return "unmeasured_or_empty", "needs_instrumentation_check"
    return "unclassified", "inspect_if_high_token"


def aggregate(rows: Iterable[SessionRow], key_func) -> list[dict[str, object]]:
    buckets: dict[object, dict[str, object]] = {}
    for row in rows:
        key = key_func(row)
        if key not in buckets:
            buckets[key] = {
                "key": key,
                "sessions": 0,
                "input": 0,
                "output": 0,
                "cache_read": 0,
                "cache_write": 0,
                "reasoning": 0,
                "non_cache": 0,
                "total": 0,
                "cost": 0.0,
            }
        b = buckets[key]
        b["sessions"] = int(b["sessions"]) + 1
        b["input"] = int(b["input"]) + row.input_tokens
        b["output"] = int(b["output"]) + row.output_tokens
        b["cache_read"] = int(b["cache_read"]) + row.cache_read_tokens
        b["cache_write"] = int(b["cache_write"]) + row.cache_write_tokens
        b["reasoning"] = int(b["reasoning"]) + row.reasoning_tokens
        b["non_cache"] = int(b["non_cache"]) + row.non_cache_tokens
        b["total"] = int(b["total"]) + row.total_tokens
        b["cost"] = float(b["cost"]) + (row.actual_cost_usd or row.estimated_cost_usd)
    return sorted(buckets.values(), key=lambda x: int(x["total"]), reverse=True)


def table(headers: list[str], rows: list[list[str]]) -> str:
    lines = [
        "| " + " | ".join(headers) + " |",
        "| " + " | ".join(["---"] * len(headers)) + " |",
    ]
    for row in rows:
        lines.append("| " + " | ".join(row) + " |")
    return "\n".join(lines)


def agg_table(items: list[dict[str, object]], key_label: str, limit: int = 20) -> str:
    rows: list[list[str]] = []
    for item in items[:limit]:
        rows.append(
            [
                str(item["key"]) or "(blank)",
                str(item["sessions"]),
                _fmt_int(int(item["non_cache"])),
                _fmt_int(int(item["cache_read"])),
                _fmt_int(int(item["total"])),
                _fmt_cost(float(item["cost"])),
            ]
        )
    return table([key_label, "Sessions", "Non-cache tokens", "Cache read", "Total tokens", "Cost"], rows)


def render_report(
    all_rows: list[SessionRow],
    today_rows: list[SessionRow],
    date: str,
    db_path: Path,
) -> str:
    generated = datetime.now().astimezone().strftime("%Y-%m-%d %H:%M:%S %z")
    all_total = sum(r.total_tokens for r in all_rows)
    all_non_cache = sum(r.non_cache_tokens for r in all_rows)
    today_total = sum(r.total_tokens for r in today_rows)
    today_non_cache = sum(r.non_cache_tokens for r in today_rows)

    classified_all: list[tuple[SessionRow, str, str]] = []
    for row in all_rows:
        work_type, recommendation = classify(row)
        classified_all.append((row, work_type, recommendation))

    by_model = aggregate(all_rows, lambda r: f"{r.provider or '(blank)'} / {r.model or '(blank)'}")
    by_source = aggregate(all_rows, lambda r: r.source or "(blank)")
    by_class = aggregate(all_rows, lambda r: classify(r)[0])
    by_recommendation = aggregate(all_rows, lambda r: classify(r)[1])

    top = sorted(all_rows, key=lambda r: r.total_tokens, reverse=True)[:20]
    top_rows: list[list[str]] = []
    for row in top:
        work_type, recommendation = classify(row)
        top_rows.append(
            [
                row.id,
                _fmt_time(row.started_at),
                row.source or "(blank)",
                row.provider or "(blank)",
                row.model or "(blank)",
                str(row.message_count),
                str(row.tool_call_count),
                _fmt_int(row.non_cache_tokens),
                _fmt_int(row.cache_read_tokens),
                _fmt_int(row.total_tokens),
                work_type,
                recommendation,
            ]
        )

    route_to_ollama = sum(r.total_tokens for r, _, rec in classified_all if rec == "route_to_ollama_candidate")
    route_to_ollama_sessions = sum(1 for _, _, rec in classified_all if rec == "route_to_ollama_candidate")

    lines = [
        f"# Hermes Usage Audit - {date}",
        "",
        "## Scope",
        f"- Generated: {generated}",
        f"- Source DB: `{db_path}`",
        "- Privacy: message content was not read; this report uses session metadata and token counters only.",
        "",
        "## Summary",
        f"- All-time sessions: {_fmt_int(len(all_rows))}",
        f"- All-time non-cache tokens: {_fmt_int(all_non_cache)}",
        f"- All-time total tokens including cache reads: {_fmt_int(all_total)}",
        f"- Sessions on {date}: {_fmt_int(len(today_rows))}",
        f"- {date} non-cache tokens: {_fmt_int(today_non_cache)}",
        f"- {date} total tokens including cache reads: {_fmt_int(today_total)}",
        "",
        "## Routing Signal",
        f"- Ollama-route candidates: {_fmt_int(route_to_ollama_sessions)} sessions",
        f"- Ollama-route candidate total tokens: {_fmt_int(route_to_ollama)}",
        "- Classification is heuristic. Use it to choose what to inspect next, not as final billing truth.",
        "",
        "## By Provider / Model",
        agg_table(by_model, "Provider / Model"),
        "",
        "## By Source",
        agg_table(by_source, "Source"),
        "",
        "## By Work Type",
        agg_table(by_class, "Work Type"),
        "",
        "## By Routing Recommendation",
        agg_table(by_recommendation, "Recommendation"),
        "",
        "## Top Token Sessions",
        table(
            [
                "Session",
                "Started",
                "Source",
                "Provider",
                "Model",
                "Messages",
                "Tools",
                "Non-cache",
                "Cache read",
                "Total",
                "Work type",
                "Recommendation",
            ],
            top_rows,
        ),
        "",
        "## Initial Action Items",
        "- Keep `/model ollama` for Watchtower, Notes Curator, formatting, and low-risk routing drafts.",
        "- Keep Gemini for proposal-quality writing, lead analysis, and high-impact planning.",
        "- Inspect top token sessions before changing cron jobs; large cache-read totals may be context reuse rather than fresh billing.",
        "- Add explicit Hermes mode tags to future sessions if exact work-type accounting is needed.",
    ]
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate a Hermes token usage audit report.")
    parser.add_argument("--db", default=str(DEFAULT_DB), help="Path to Hermes state.db")
    parser.add_argument("--date", default=datetime.now().astimezone().strftime("%Y-%m-%d"), help="Local date to summarize")
    parser.add_argument("--out-dir", default=str(DEFAULT_OUT_DIR), help="Output directory")
    args = parser.parse_args()

    db_path = Path(args.db)
    if not db_path.exists():
        raise SystemExit(f"Hermes state DB not found: {db_path}")

    all_rows = load_sessions(db_path)
    today_rows = filter_by_date(all_rows, args.date)

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"hermes_usage_audit_{args.date}.md"
    out_path.write_text(render_report(all_rows, today_rows, args.date, db_path), encoding="utf-8")
    print(out_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

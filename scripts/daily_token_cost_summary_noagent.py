#!/usr/bin/env python3
"""No-agent Daily Token Cost Summary for Hermes cron.

This script reads Hermes session metadata from the local state.db and writes a
small local audit report only when usage counters changed since the previous
run. It does not call any model or external service.

Hermes cron should run this with --no-agent so stdout is delivered directly.
When there is no new data, default stdout is empty to avoid Telegram noise.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path


DEFAULT_AGENTOS_ROOT = Path("E:/AgentOS")
DEFAULT_DB = Path.home() / "AppData" / "Local" / "hermes" / "state.db"


@dataclass
class UsageSnapshot:
    session_count: int
    api_call_count: int
    message_count: int
    tool_call_count: int
    input_tokens: int
    output_tokens: int
    cache_read_tokens: int
    cache_write_tokens: int
    reasoning_tokens: int
    estimated_cost_usd: float
    actual_cost_usd: float
    latest_started_at: float

    @property
    def non_cache_tokens(self) -> int:
        return (
            self.input_tokens
            + self.output_tokens
            + self.cache_write_tokens
            + self.reasoning_tokens
        )

    @property
    def total_tokens(self) -> int:
        return self.non_cache_tokens + self.cache_read_tokens


def now_local() -> str:
    return datetime.now().astimezone().strftime("%Y-%m-%d %H:%M:%S %z")


def today_local() -> str:
    return datetime.now().astimezone().strftime("%Y-%m-%d")


def safe_int(value: object) -> int:
    try:
        return int(value or 0)
    except Exception:
        return 0


def safe_float(value: object) -> float:
    try:
        return float(value or 0)
    except Exception:
        return 0.0


def load_snapshot(db_path: Path) -> UsageSnapshot:
    if not db_path.exists():
        raise FileNotFoundError(f"Hermes state DB not found: {db_path}")

    con = sqlite3.connect(db_path)
    con.row_factory = sqlite3.Row
    row = con.execute(
        """
        select
          count(*) as session_count,
          coalesce(sum(api_call_count), 0) as api_call_count,
          coalesce(sum(message_count), 0) as message_count,
          coalesce(sum(tool_call_count), 0) as tool_call_count,
          coalesce(sum(input_tokens), 0) as input_tokens,
          coalesce(sum(output_tokens), 0) as output_tokens,
          coalesce(sum(cache_read_tokens), 0) as cache_read_tokens,
          coalesce(sum(cache_write_tokens), 0) as cache_write_tokens,
          coalesce(sum(reasoning_tokens), 0) as reasoning_tokens,
          coalesce(sum(estimated_cost_usd), 0) as estimated_cost_usd,
          coalesce(sum(actual_cost_usd), 0) as actual_cost_usd,
          coalesce(max(started_at), 0) as latest_started_at
        from sessions
        """
    ).fetchone()
    con.close()
    return UsageSnapshot(
        session_count=safe_int(row["session_count"]),
        api_call_count=safe_int(row["api_call_count"]),
        message_count=safe_int(row["message_count"]),
        tool_call_count=safe_int(row["tool_call_count"]),
        input_tokens=safe_int(row["input_tokens"]),
        output_tokens=safe_int(row["output_tokens"]),
        cache_read_tokens=safe_int(row["cache_read_tokens"]),
        cache_write_tokens=safe_int(row["cache_write_tokens"]),
        reasoning_tokens=safe_int(row["reasoning_tokens"]),
        estimated_cost_usd=safe_float(row["estimated_cost_usd"]),
        actual_cost_usd=safe_float(row["actual_cost_usd"]),
        latest_started_at=safe_float(row["latest_started_at"]),
    )


def fingerprint(snapshot: UsageSnapshot) -> str:
    payload = {
        "session_count": snapshot.session_count,
        "api_call_count": snapshot.api_call_count,
        "message_count": snapshot.message_count,
        "tool_call_count": snapshot.tool_call_count,
        "input_tokens": snapshot.input_tokens,
        "output_tokens": snapshot.output_tokens,
        "cache_read_tokens": snapshot.cache_read_tokens,
        "cache_write_tokens": snapshot.cache_write_tokens,
        "reasoning_tokens": snapshot.reasoning_tokens,
        "estimated_cost_usd": round(snapshot.estimated_cost_usd, 8),
        "actual_cost_usd": round(snapshot.actual_cost_usd, 8),
        "latest_started_at": snapshot.latest_started_at,
    }
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


def read_state(path: Path) -> dict[str, object]:
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}


def write_json(path: Path, data: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def fmt_int(value: int) -> str:
    return f"{value:,}"


def fmt_cost(value: float) -> str:
    return f"${value:.4f}"


def render_report(snapshot: UsageSnapshot, old: dict[str, object], fp: str) -> str:
    old_sessions = safe_int(old.get("session_count"))
    old_api_calls = safe_int(old.get("api_call_count"))
    old_total = safe_int(old.get("total_tokens"))
    old_non_cache = safe_int(old.get("non_cache_tokens"))
    return "\n".join(
        [
            f"# Daily Token Cost Summary - {today_local()}",
            "",
            f"generated_at: {now_local()}",
            "mode: no_agent",
            "models_invoked: false",
            "external_services_invoked: false",
            f"fingerprint: {fp}",
            "",
            "## Current Totals",
            f"- sessions: {fmt_int(snapshot.session_count)}",
            f"- api_calls: {fmt_int(snapshot.api_call_count)}",
            f"- messages: {fmt_int(snapshot.message_count)}",
            f"- tool_calls: {fmt_int(snapshot.tool_call_count)}",
            f"- non_cache_tokens: {fmt_int(snapshot.non_cache_tokens)}",
            f"- cache_read_tokens: {fmt_int(snapshot.cache_read_tokens)}",
            f"- total_tokens: {fmt_int(snapshot.total_tokens)}",
            f"- estimated_cost_usd: {fmt_cost(snapshot.estimated_cost_usd)}",
            f"- actual_cost_usd: {fmt_cost(snapshot.actual_cost_usd)}",
            "",
            "## Delta Since Last Report",
            f"- sessions_delta: {fmt_int(snapshot.session_count - old_sessions)}",
            f"- api_calls_delta: {fmt_int(snapshot.api_call_count - old_api_calls)}",
            f"- non_cache_tokens_delta: {fmt_int(snapshot.non_cache_tokens - old_non_cache)}",
            f"- total_tokens_delta: {fmt_int(snapshot.total_tokens - old_total)}",
            "",
            "## Notes",
            "- This report uses Hermes state.db metadata only.",
            "- It does not read message content.",
            "- It does not call Gemini or any other model.",
            "- Empty stdout means no new usage data was detected.",
            "",
        ]
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="No-agent throttled Hermes usage summary.")
    parser.add_argument("--agentos-root", default=str(DEFAULT_AGENTOS_ROOT))
    parser.add_argument("--db", default=str(DEFAULT_DB))
    parser.add_argument("--force", action="store_true", help="Write/report even if fingerprint did not change.")
    parser.add_argument("--verbose", action="store_true", help="Print no-change status instead of silent stdout.")
    args = parser.parse_args()

    root = Path(args.agentos_root)
    state_path = root / "data" / "usage" / "daily_token_cost_summary_state.json"
    out_dir = root / "data" / "usage" / "daily_token_cost_summary"
    snapshot = load_snapshot(Path(args.db))
    fp = fingerprint(snapshot)
    old = read_state(state_path)
    old_fp = str(old.get("fingerprint") or "")

    if fp == old_fp and not args.force:
        if args.verbose:
            print("daily_token_cost_summary_status=no_change")
            print("models_invoked=false")
            print("external_services_invoked=false")
        return 0

    report = render_report(snapshot, old, fp)
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{today_local()}.md"
    out_path.write_text(report, encoding="utf-8")
    write_json(
        state_path,
        {
            "updated_at": now_local(),
            "fingerprint": fp,
            "session_count": snapshot.session_count,
            "api_call_count": snapshot.api_call_count,
            "non_cache_tokens": snapshot.non_cache_tokens,
            "total_tokens": snapshot.total_tokens,
            "report_path": str(out_path),
            "models_invoked": False,
            "external_services_invoked": False,
        },
    )

    print("daily_token_cost_summary_status=updated")
    print(f"report_path={out_path}")
    print(f"sessions={snapshot.session_count}")
    print(f"api_calls={snapshot.api_call_count}")
    print(f"non_cache_tokens={snapshot.non_cache_tokens}")
    print(f"total_tokens={snapshot.total_tokens}")
    print("models_invoked=false")
    print("external_services_invoked=false")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

"""Deterministic Windows health report for the Hermes cron scheduler."""

import json
import os
from datetime import datetime
from pathlib import Path


home = Path(os.environ.get("HERMES_HOME", Path.home() / "AppData/Local/hermes"))
state_path = home / "gateway_state.json"
jobs_path = home / "cron" / "jobs.json"

state = json.loads(state_path.read_text(encoding="utf-8")) if state_path.exists() else {}
jobs_doc = json.loads(jobs_path.read_text(encoding="utf-8")) if jobs_path.exists() else {"jobs": []}
jobs = jobs_doc.get("jobs", [])
telegram = state.get("platforms", {}).get("telegram", {})
patrol = next((job for job in jobs if job.get("id") == "d00fbf284738"), {})

ok = (
    state.get("gateway_state") == "running"
    and telegram.get("state") == "connected"
)

print("AgentOS deterministic health check")
print(f"checked_at={datetime.now().astimezone().isoformat(timespec='seconds')}")
print(f"overall_status={'OK' if ok else 'WARN'}")
print(f"gateway_state={state.get('gateway_state', 'unknown')}")
print(f"gateway_pid={state.get('pid', 'unknown')}")
print(f"telegram_state={telegram.get('state', 'unknown')}")
print(f"active_agents={state.get('active_agents', 'unknown')}")
print(f"cron_job_count={len(jobs)}")
print(f"upwork_patrol_enabled={str(bool(patrol.get('enabled'))).lower()}")
print(f"upwork_patrol_state={patrol.get('state', 'unknown')}")
print(f"upwork_patrol_next_run={patrol.get('next_run_at', 'unknown')}")
print("models_invoked=false")
print("external_services_invoked=false")

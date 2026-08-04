"""
Quick diagnostic: check state.db schema and real data.
Run: python check_db.py
"""
import json
import os
import sqlite3
from pathlib import Path
from datetime import datetime, timezone

AGENTOS_ROOT = Path(__file__).resolve().parents[2]


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


DB = Path(_load_runtime_config()["hermes"]["state_db"])

if not DB.exists():
    print(f"ERROR: state.db not found at {DB}")
    raise SystemExit(1)

con = sqlite3.connect(str(DB))
con.row_factory = sqlite3.Row

print(f"DB path: {DB}")
print()

# 1. Tables
tables = [r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()]
print(f"Tables: {tables}")
print()

# 2. Sessions schema
print("=== sessions columns ===")
for row in con.execute("PRAGMA table_info(sessions)").fetchall():
    print(f"  {row['name']}  {row['type']}")
print()

# 3. Sample started_at to check format
print("=== started_at format check (last 3 sessions) ===")
for row in con.execute("SELECT id, started_at, input_tokens, output_tokens FROM sessions ORDER BY started_at DESC LIMIT 3").fetchall():
    sat = row["started_at"]
    # Try to interpret
    try:
        if isinstance(sat, (int, float)):
            dt = datetime.fromtimestamp(sat, tz=timezone.utc)
            fmt = f"unix → {dt}"
        else:
            fmt = f"string: {sat}"
    except Exception as e:
        fmt = f"? {sat} ({e})"
    print(f"  id={row['id'][:8]}  started_at={sat} ({fmt})  in={row['input_tokens']}  out={row['output_tokens']}")
print()

# 4. 5h window query
print("=== 5h window test ===")
row = con.execute("""
    SELECT COUNT(*) as n,
           COALESCE(SUM(input_tokens),0) as inp,
           COALESCE(SUM(output_tokens),0) as out
    FROM sessions
    WHERE started_at >= strftime('%s','now') - 18000
""").fetchone()
print(f"  sessions={row['n']}  input={row['inp']}  output={row['out']}")
print()

# 5. 7d window
print("=== 7d window test ===")
row = con.execute("""
    SELECT COUNT(*) as n,
           COALESCE(SUM(input_tokens),0) as inp,
           COALESCE(SUM(output_tokens),0) as out
    FROM sessions
    WHERE started_at >= strftime('%s','now') - 604800
""").fetchone()
print(f"  sessions={row['n']}  input={row['inp']}  output={row['out']}")
print()

# 6. messages table if exists
if "messages" in tables:
    print("=== messages columns ===")
    for row in con.execute("PRAGMA table_info(messages)").fetchall():
        print(f"  {row['name']}  {row['type']}")
    cnt = con.execute("SELECT COUNT(*) FROM messages").fetchone()[0]
    print(f"  total rows: {cnt}")
else:
    print("No 'messages' table found")

con.close()

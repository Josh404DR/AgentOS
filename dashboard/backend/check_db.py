"""
Quick diagnostic: check state.db schema and real data.
Run: python check_db.py
"""
import sqlite3
from pathlib import Path
from datetime import datetime, timezone

DB = Path.home() / "AppData" / "Local" / "hermes" / "state.db"

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

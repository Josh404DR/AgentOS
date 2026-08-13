"""Command-line interface for the deterministic Hermes Lite index."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .indexer import DEFAULT_STATE, Indexer, query_index


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--state", type=Path, default=DEFAULT_STATE)
    sub = parser.add_subparsers(dest="command", required=True)
    build = sub.add_parser("index")
    build.add_argument("--full", action="store_true")
    query = sub.add_parser("query")
    query.add_argument("text")
    args = parser.parse_args()
    state = args.state if args.state.is_absolute() else args.root / args.state
    result = Indexer(args.root, state).run(args.full).as_dict() if args.command == "index" else query_index(state, args.text)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

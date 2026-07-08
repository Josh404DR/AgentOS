"""Extract raw CSV files and normalize schemas into a staging layer."""

from __future__ import annotations

from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"
STAGING = ROOT / "data" / "processed" / "staging"
TABLES = ["orders", "order_items", "products", "inventory", "shipments", "campaign_calendar"]


def run() -> None:
    STAGING.mkdir(parents=True, exist_ok=True)
    for table in TABLES:
        path = RAW / f"{table}.csv"
        if not path.exists():
            raise FileNotFoundError(f"Required raw table missing: {path}")
        frame = pd.read_csv(path)
        frame.columns = [column.strip().lower() for column in frame.columns]
        frame.to_csv(STAGING / f"{table}.csv", index=False)
    print(f"extract_status=completed tables={len(TABLES)}")


if __name__ == "__main__":
    run()

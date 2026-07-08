"""Generate reproducible synthetic e-commerce operations data."""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"
SEED = 77


def run() -> None:
    rng = np.random.default_rng(SEED)
    RAW.mkdir(parents=True, exist_ok=True)

    categories = ["Electronics", "Home", "Beauty", "Sports", "Fashion", "Grocery"]
    products = pd.DataFrame(
        {
            "product_id": range(1, 49),
            "product_name": [f"{categories[(i - 1) // 8]} Item {(i - 1) % 8 + 1:02d}" for i in range(1, 49)],
            "category": [categories[(i - 1) // 8] for i in range(1, 49)],
            "unit_cost": np.round(rng.uniform(4, 95, 48), 2),
        }
    )
    products["list_price"] = np.round(products["unit_cost"] * rng.uniform(1.45, 2.3, 48), 2)
    # Intentional data-quality issue for validation demonstration.
    products.loc[products["product_id"] == 48, "product_name"] = np.nan

    campaigns = pd.DataFrame(
        [
            (1, "Spring Push", "2025-02-10", "2025-02-18"),
            (2, "Month-End Flash", "2025-03-25", "2025-03-31"),
        ],
        columns=["campaign_id", "campaign_name", "start_date", "end_date"],
    )
    campaigns["start_date"] = pd.to_datetime(campaigns["start_date"])
    campaigns["end_date"] = pd.to_datetime(campaigns["end_date"])

    dates = pd.date_range("2025-01-01", "2025-03-31", freq="D")
    order_rows, item_rows, shipment_rows = [], [], []
    order_id = item_id = shipment_id = 1
    base_product_weights = rng.dirichlet(np.ones(48) * 2)

    for date in dates:
        active_campaign = campaigns[
            (campaigns["start_date"] <= date) & (campaigns["end_date"] >= date)
        ]
        campaign_id = int(active_campaign.iloc[0]["campaign_id"]) if not active_campaign.empty else None
        demand_multiplier = 1.35 if campaign_id else 1.0
        if date >= pd.Timestamp("2025-03-15"):
            demand_multiplier *= 0.86  # creates product-level decline signals
        order_count = int(rng.poisson(42 * demand_multiplier))

        for _ in range(order_count):
            created_at = date + pd.Timedelta(minutes=int(rng.integers(0, 1440)))
            status = rng.choice(
                ["completed", "processing", "cancelled", "refunded", "unknown_status"],
                p=[0.83, 0.09, 0.045, 0.025, 0.01],
            )
            order_rows.append((order_id, created_at, status, campaign_id, rng.choice(["North", "Central", "South", "East"])))

            item_count = int(rng.choice([1, 2, 3], p=[0.65, 0.27, 0.08]))
            selected = rng.choice(products["product_id"], item_count, replace=False, p=base_product_weights)
            for product_id in selected:
                product = products.loc[products["product_id"] == product_id].iloc[0]
                quantity = int(rng.choice([1, 2, 3], p=[0.79, 0.17, 0.04]))
                unit_price = float(product["list_price"]) * (0.88 if campaign_id else 1)
                if order_id == 25 and product_id == selected[0]:
                    unit_price *= 12  # intentional sales-amount anomaly
                item_rows.append((item_id, order_id, int(product_id), quantity, round(unit_price, 2)))
                item_id += 1

            if status in {"completed", "processing"}:
                promised = date + pd.Timedelta(days=int(rng.choice([2, 3, 4], p=[0.25, 0.55, 0.20])))
                shipped = (
                    date + pd.Timedelta(days=int(rng.choice([1, 2, 3, 5, 7], p=[0.15, 0.38, 0.28, 0.14, 0.05])))
                    if rng.random() > 0.035
                    else pd.NaT
                )
                delivered = shipped + pd.Timedelta(days=int(rng.integers(1, 5))) if pd.notna(shipped) else pd.NaT
                shipment_rows.append((shipment_id, order_id, promised, shipped, delivered))
                shipment_id += 1
            order_id += 1

    orders = pd.DataFrame(order_rows, columns=["order_id", "order_created_at", "order_status", "campaign_id", "region"])
    order_items = pd.DataFrame(item_rows, columns=["order_item_id", "order_id", "product_id", "quantity", "unit_price"])
    shipments = pd.DataFrame(
        shipment_rows,
        columns=["shipment_id", "order_id", "promised_ship_date", "shipped_date", "delivered_date"],
    )
    inventory = pd.DataFrame(
        {
            "product_id": products["product_id"],
            "stock_on_hand": rng.integers(0, 180, len(products)),
            "reorder_point": rng.integers(18, 55, len(products)),
            "snapshot_date": pd.Timestamp("2025-03-31"),
        }
    )

    # Intentional duplicate for validation and deduplication demonstration.
    orders = pd.concat([orders, orders.iloc[[9]]], ignore_index=True)

    for name, frame in {
        "orders": orders,
        "order_items": order_items,
        "products": products,
        "inventory": inventory,
        "shipments": shipments,
        "campaign_calendar": campaigns,
    }.items():
        frame.to_csv(RAW / f"{name}.csv", index=False, date_format="%Y-%m-%d %H:%M:%S")
    print(f"mock_data_status=completed orders={len(orders)} items={len(order_items)}")


if __name__ == "__main__":
    run()

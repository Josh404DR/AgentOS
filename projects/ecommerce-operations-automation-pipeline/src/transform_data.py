"""Clean staged tables and create dashboard-ready operational datasets."""

from __future__ import annotations

from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
STAGING = ROOT / "data" / "processed" / "staging"
PROCESSED = ROOT / "data" / "processed"


def run() -> None:
    PROCESSED.mkdir(parents=True, exist_ok=True)
    orders = pd.read_csv(STAGING / "orders.csv", parse_dates=["order_created_at"])
    items = pd.read_csv(STAGING / "order_items.csv")
    products = pd.read_csv(STAGING / "products.csv")
    inventory = pd.read_csv(STAGING / "inventory.csv", parse_dates=["snapshot_date"])
    shipments = pd.read_csv(
        STAGING / "shipments.csv",
        parse_dates=["promised_ship_date", "shipped_date", "delivered_date"],
    )
    campaigns = pd.read_csv(
        STAGING / "campaign_calendar.csv", parse_dates=["start_date", "end_date"]
    )

    orders = orders.drop_duplicates(subset=["order_id"], keep="first")
    items = items.drop_duplicates(subset=["order_item_id"], keep="first")
    items["line_gmv"] = (items["quantity"] * items["unit_price"]).round(2)
    order_values = (
        items.groupby("order_id", as_index=False)["line_gmv"]
        .sum()
        .rename(columns={"line_gmv": "order_gmv"})
    )
    orders = orders.merge(order_values, on="order_id", how="left")
    orders["order_gmv"] = orders["order_gmv"].fillna(0)
    orders["order_date"] = orders["order_created_at"].dt.date.astype(str)

    shipment_ops = orders.merge(shipments, on="order_id", how="left")
    shipment_ops["is_fulfilled"] = shipment_ops["shipped_date"].notna().astype(int)
    shipment_ops["is_delayed"] = (
        shipment_ops["shipped_date"].isna()
        | (shipment_ops["shipped_date"] > shipment_ops["promised_ship_date"])
    ).astype(int)

    sales_detail = (
        items.merge(orders, on="order_id", how="left")
        .merge(products, on="product_id", how="left")
    )
    sales_detail["is_commercial_order"] = sales_detail["order_status"].isin(
        ["completed", "processing"]
    )

    for name, frame in {
        "orders_clean": orders,
        "order_items_clean": items,
        "products_clean": products,
        "inventory_clean": inventory,
        "shipments_clean": shipments,
        "campaign_calendar_clean": campaigns,
        "shipment_operations": shipment_ops,
        "sales_detail": sales_detail,
    }.items():
        frame.to_csv(PROCESSED / f"{name}.csv", index=False, date_format="%Y-%m-%d")
    print(f"transform_status=completed clean_orders={len(orders)}")


if __name__ == "__main__":
    run()

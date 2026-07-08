"""Validate processed data and produce operational/data-quality alerts."""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"
PROCESSED = ROOT / "data" / "processed"
OUTPUTS = ROOT / "outputs"


def alert(alert_type: str, severity: str, entity: str, metric: str, details: str) -> dict:
    return {
        "alert_type": alert_type,
        "severity": severity,
        "entity": entity,
        "metric": metric,
        "details": details,
    }


def run() -> None:
    OUTPUTS.mkdir(parents=True, exist_ok=True)
    raw_orders = pd.read_csv(RAW / "orders.csv")
    orders = pd.read_csv(PROCESSED / "orders_clean.csv", parse_dates=["order_created_at"])
    sales = pd.read_csv(PROCESSED / "sales_detail.csv", parse_dates=["order_created_at"])
    products = pd.read_csv(PROCESSED / "products_clean.csv")
    inventory = pd.read_csv(PROCESSED / "inventory_clean.csv")
    shipment_ops = pd.read_csv(
        PROCESSED / "shipment_operations.csv",
        parse_dates=["promised_ship_date", "shipped_date"],
    )
    alerts: list[dict] = []

    duplicate_count = int(raw_orders.duplicated(subset=["order_id"]).sum())
    if duplicate_count:
        alerts.append(alert("data_quality", "medium", "orders", str(duplicate_count), "Duplicate order IDs removed during transform."))

    valid_statuses = {"completed", "processing", "cancelled", "refunded"}
    invalid = orders.loc[~orders["order_status"].isin(valid_statuses)]
    for row in invalid.itertuples():
        alerts.append(alert("order_status_anomaly", "high", f"order:{row.order_id}", row.order_status, "Status is outside the approved operational values."))

    delayed = shipment_ops.loc[
        shipment_ops["order_status"].isin(["completed", "processing"])
        & (shipment_ops["is_delayed"] == 1)
    ]
    for row in delayed.head(100).itertuples():
        alerts.append(alert("delayed_shipment", "high", f"order:{row.order_id}", str(row.promised_ship_date.date()), "Shipment missed or is projected to miss its promised ship date."))

    low_stock = inventory.loc[inventory["stock_on_hand"] <= inventory["reorder_point"]]
    for row in low_stock.itertuples():
        alerts.append(alert("low_inventory", "high", f"product:{row.product_id}", f"{row.stock_on_hand}/{row.reorder_point}", "Stock on hand is at or below reorder point."))

    missing_products = products.loc[products[["product_name", "category", "list_price"]].isna().any(axis=1)]
    for row in missing_products.itertuples():
        alerts.append(alert("product_data_missing", "medium", f"product:{row.product_id}", "required_field", "One or more required product fields are missing."))

    commercial = sales.loc[sales["is_commercial_order"].astype(str).str.lower().isin(["true", "1"])]
    product_price = commercial.groupby("product_id")["unit_price"].agg(["median", "std"]).reset_index()
    sales_checked = commercial.merge(product_price, on="product_id")
    amount_anomaly = sales_checked.loc[
        sales_checked["unit_price"] > sales_checked["median"] + 5 * sales_checked["std"].fillna(0)
    ]
    for row in amount_anomaly.itertuples():
        alerts.append(alert("sales_amount_anomaly", "high", f"order:{row.order_id}/product:{row.product_id}", f"{row.unit_price:.2f}", "Unit price is materially above the product baseline."))

    commercial = commercial.copy()
    commercial["order_date"] = pd.to_datetime(commercial["order_date"])
    daily_product = commercial.groupby(["order_date", "product_id"], as_index=False)["line_gmv"].sum()
    cutoff = daily_product["order_date"].max() - pd.Timedelta(days=13)
    current = daily_product[daily_product["order_date"] > cutoff].groupby("product_id")["line_gmv"].mean()
    previous = daily_product[
        (daily_product["order_date"] <= cutoff)
        & (daily_product["order_date"] > cutoff - pd.Timedelta(days=14))
    ].groupby("product_id")["line_gmv"].mean()
    declines = pd.concat([previous.rename("previous"), current.rename("current")], axis=1).dropna()
    declines["change_pct"] = declines["current"] / declines["previous"] - 1
    for product_id, row in declines.loc[declines["change_pct"] <= -0.35].iterrows():
        alerts.append(alert("sales_drop", "medium", f"product:{product_id}", f"{row['change_pct']:.1%}", "Recent 14-day average GMV fell at least 35% versus the prior period."))

    alerts_frame = pd.DataFrame(alerts)
    alerts_frame.to_csv(OUTPUTS / "alert_log.csv", index=False)
    quality = pd.DataFrame(
        [
            ("raw_duplicate_order_ids", duplicate_count),
            ("invalid_order_status_rows", len(invalid)),
            ("missing_product_rows", len(missing_products)),
            ("sales_amount_anomalies", len(amount_anomaly)),
            ("total_data_errors", duplicate_count + len(invalid) + len(missing_products) + len(amount_anomaly)),
        ],
        columns=["check_name", "error_count"],
    )
    quality.to_csv(OUTPUTS / "data_quality_summary.csv", index=False)
    print(f"validate_status=completed alerts={len(alerts_frame)} data_errors={int(quality.iloc[-1]['error_count'])}")


if __name__ == "__main__":
    run()

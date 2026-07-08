"""Generate dashboard-ready KPIs and the daily operations report."""

from __future__ import annotations

from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
PROCESSED = ROOT / "data" / "processed"
OUTPUTS = ROOT / "outputs"


def run() -> None:
    OUTPUTS.mkdir(parents=True, exist_ok=True)
    orders = pd.read_csv(PROCESSED / "orders_clean.csv", parse_dates=["order_created_at"])
    sales = pd.read_csv(PROCESSED / "sales_detail.csv", parse_dates=["order_created_at"])
    shipment_ops = pd.read_csv(PROCESSED / "shipment_operations.csv")
    campaigns = pd.read_csv(PROCESSED / "campaign_calendar_clean.csv", parse_dates=["start_date", "end_date"])
    alerts = pd.read_csv(OUTPUTS / "alert_log.csv")
    quality = pd.read_csv(OUTPUTS / "data_quality_summary.csv")

    commercial_orders = orders.loc[orders["order_status"].isin(["completed", "processing"])].copy()
    daily = (
        commercial_orders.groupby("order_date", as_index=False)
        .agg(daily_gmv=("order_gmv", "sum"), daily_order_count=("order_id", "nunique"))
    )
    daily["average_order_value"] = daily["daily_gmv"] / daily["daily_order_count"]
    daily.to_csv(OUTPUTS / "daily_sales_summary.csv", index=False)

    commercial_sales = sales.loc[sales["order_status"].isin(["completed", "processing"])].copy()
    product_metrics = (
        commercial_sales.groupby(["product_id", "product_name", "category"], dropna=False, as_index=False)
        .agg(gmv=("line_gmv", "sum"), units_sold=("quantity", "sum"), order_count=("order_id", "nunique"))
        .sort_values("gmv", ascending=False)
    )
    product_metrics["sales_rank"] = range(1, len(product_metrics) + 1)
    product_metrics.to_csv(OUTPUTS / "product_operation_metrics.csv", index=False)

    eligible_shipments = shipment_ops.loc[
        shipment_ops["order_status"].isin(["completed", "processing"])
    ]
    fulfillment_rate = float(eligible_shipments["is_fulfilled"].mean())
    delayed_count = int(eligible_shipments["is_delayed"].sum())
    latest = daily.iloc[-1]
    prior_7 = daily.iloc[-8:-1]
    latest_vs_prior = float(latest["daily_gmv"] / prior_7["daily_gmv"].mean() - 1)
    low_inventory_count = int((alerts["alert_type"] == "low_inventory").sum())
    data_error_count = int(quality.loc[quality["check_name"] == "total_data_errors", "error_count"].iloc[0])

    campaign_rows = []
    for campaign in campaigns.itertuples(index=False):
        duration = (campaign.end_date - campaign.start_date).days + 1
        during = commercial_orders[
            commercial_orders["order_created_at"].dt.date.between(campaign.start_date.date(), campaign.end_date.date())
        ]["order_gmv"].sum() / duration
        before = commercial_orders[
            commercial_orders["order_created_at"].dt.date.between(
                (campaign.start_date - pd.Timedelta(days=duration)).date(),
                (campaign.start_date - pd.Timedelta(days=1)).date(),
            )
        ]["order_gmv"].sum() / duration
        campaign_rows.append((campaign.campaign_name, during / before - 1 if before else 0))
    campaign_comparison = pd.DataFrame(campaign_rows, columns=["campaign_name", "daily_gmv_lift_pct"])
    campaign_comparison.to_csv(OUTPUTS / "campaign_period_comparison.csv", index=False)
    best_campaign = campaign_comparison.sort_values("daily_gmv_lift_pct", ascending=False).iloc[0]

    report = f"""# Daily E-commerce Operations Report

Report date: {latest['order_date']}  
Data scope: Reproducible synthetic data only

## Executive Snapshot

| KPI | Current Result |
|---|---:|
| Daily GMV | ${latest['daily_gmv']:,.2f} |
| Daily Order Count | {int(latest['daily_order_count']):,} |
| Average Order Value | ${latest['average_order_value']:,.2f} |
| Order Fulfillment Rate | {fulfillment_rate:.1%} |
| Delayed Shipment Count | {delayed_count:,} |
| Low Inventory Alerts | {low_inventory_count:,} |
| Data Error Count | {data_error_count:,} |

## Insight 1 — Daily Sales Pulse

- **Metric:** Daily GMV, order count, and AOV.
- **Observation:** Latest GMV was **${latest['daily_gmv']:,.2f}** from **{int(latest['daily_order_count'])} orders**, with AOV of **${latest['average_order_value']:,.2f}**. GMV was **{latest_vs_prior:.1%}** versus the prior seven-day average.
- **Possible Cause:** Day-of-week demand, campaign timing, and the simulated late-period demand slowdown affect daily volume.
- **Recommended Action:** Review traffic and conversion alongside GMV; escalate only if the decline persists for multiple days or affects priority products.

## Insight 2 — Fulfillment Health

- **Metric:** Order fulfillment rate and delayed shipments.
- **Observation:** Fulfillment rate was **{fulfillment_rate:.1%}**, with **{delayed_count}** delayed or unshipped eligible orders.
- **Possible Cause:** Carrier lead-time variability, warehouse backlog, or incomplete shipment events.
- **Recommended Action:** Prioritize the high-severity delayed-shipment queue by promised date and customer impact; reconcile missing shipment scans daily.

## Insight 3 — Inventory Risk

- **Metric:** Products at or below reorder point.
- **Observation:** **{low_inventory_count} products** triggered low-inventory alerts.
- **Possible Cause:** Demand concentration, campaign lift, or reorder points that were not adjusted for current sales velocity.
- **Recommended Action:** Replenish high-rank products first and update reorder points using lead time plus recent demand.

## Insight 4 — Campaign Period Comparison

- **Metric:** Daily GMV during campaign versus equal-length pre-period.
- **Observation:** **{best_campaign['campaign_name']}** had the strongest directional lift at **{best_campaign['daily_gmv_lift_pct']:.1%}**.
- **Possible Cause:** Promotion timing and discounts increased short-term purchasing, though seasonality is not controlled.
- **Recommended Action:** Use this comparison for operational planning, then add holdouts or margin-adjusted measurement before changing long-term budget.

## Insight 5 — Data Reliability

- **Metric:** Automated data error count and operational alerts.
- **Observation:** Validation found **{data_error_count} data errors** and produced **{len(alerts)} total alerts** across quality and operations.
- **Possible Cause:** Duplicate source events, invalid statuses, missing product attributes, and extreme transaction values.
- **Recommended Action:** Quarantine invalid records, assign alert owners, and track recurrence by source system before publishing executive KPIs.

## Operating Decision

The pipeline is suitable as a daily MVP control layer: it separates source errors from operational risk, produces dashboard-ready outputs, and preserves an alert trail. Production deployment would add source-level SLAs, incremental loads, idempotent storage, and notification routing.
"""
    (OUTPUTS / "daily_operations_report.md").write_text(report, encoding="utf-8")
    print(f"report_status=completed report_date={latest['order_date']}")


if __name__ == "__main__":
    run()

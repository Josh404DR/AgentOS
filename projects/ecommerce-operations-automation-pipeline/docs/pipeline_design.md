# Pipeline Design

## Purpose

This MVP converts messy synthetic commerce operations data into validated,
dashboard-ready datasets and an actionable daily report. It demonstrates a
small, understandable batch pipeline rather than production infrastructure.

## Source Tables

| Table | Grain | Operational use |
|---|---|---|
| `orders` | One row per order | Status, date, region and campaign context |
| `order_items` | One row per order-product line | Quantity, price and GMV |
| `products` | One row per product | Product name, category, cost and list price |
| `inventory` | One row per product snapshot | Stock and reorder threshold |
| `shipments` | One row per shipment | Promise, ship and delivery dates |
| `campaign_calendar` | One row per campaign | Campaign-period comparison |

All records are generated with a fixed random seed and contain no real company
or customer data. Deliberate duplicates, invalid statuses, missing attributes,
and an extreme transaction value are included to demonstrate controls.

## Data Flow

```text
Raw CSV
  → Extract / schema normalization
  → Transform / deduplicate / join / derive metrics
  → Validate / quality and operational alerts
  → KPI outputs and daily report
  → Dashboard-ready CSV datasets
```

## Processing Steps

1. `generate_mock_data.py` creates six reproducible source tables.
2. `extract_data.py` checks table availability and creates a normalized staging layer.
3. `transform_data.py` parses dates, removes duplicate keys, calculates line
   GMV, enriches order data, and produces sales and shipment operation tables.
4. `validate_data.py` separates data-quality errors from operational alerts.
5. `generate_report.py` creates daily sales, product ranking, campaign
   comparison, alert logs, and an executive operating report.
6. `main.py` orchestrates the full pipeline and records stage duration.

## Data Correctness Controls

- Required source-file checks.
- Primary-key duplicate detection and deterministic deduplication.
- Approved order-status domain.
- Product required-field validation.
- Referential joins between order, item, product and shipment data.
- Extreme unit-price detection against product baselines.
- Explicit metric definitions and completed/processing order scope.
- Persistent alert log and data-quality summary.

A production implementation would add database constraints, idempotent load
keys, source freshness SLAs, row-count reconciliation, schema contracts,
lineage metadata, and failed-record quarantine.

## Dashboard and Decision Support

`daily_sales_summary.csv` supplies the executive sales trend.
`product_operation_metrics.csv` supports product ranking and sales monitoring.
`alert_log.csv` supplies the exception queue. Campaign comparison and data
quality outputs explain performance and trustworthiness.

The design helps operations teams answer:

- Is today's sales performance within its recent range?
- Are orders being fulfilled on time?
- Which products need replenishment or investigation?
- Which campaign periods changed demand?
- Can the reported KPIs be trusted?

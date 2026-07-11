# E-commerce Operations Automation Pipeline

An end-to-end data operations portfolio project that turns synthetic
e-commerce source files into validated KPIs, operational alerts, a daily
business report, and dashboard-ready datasets.

> **Data disclaimer:** All records are reproducible mock data. No real company,
> customer, order, product, or campaign information is used.

## Project Overview

This one-day MVP demonstrates how Python, Pandas and SQL can automate a daily
commerce operations workflow. It focuses on reliability, traceable controls,
exception management and outputs that HR, operations stakeholders and BI teams
can understand.

## Business Problem

Commerce teams often receive fragmented order, product, inventory and
fulfillment exports. Manual preparation delays decisions and allows duplicate
orders, invalid statuses, missing product attributes or late shipments to
silently distort reporting.

The project answers: how can messy source data become a stable, repeatable and
dashboard-ready operating process?

## Pipeline Design

```text
Raw Data
  → Clean Data
  → Validate Data
  → KPI Output
  → Alert Report
  → Dashboard-ready Dataset
```

See [`docs/pipeline_design.md`](docs/pipeline_design.md) for table purposes,
quality controls, lineage, and production extensions.

## Dataset

The fixed-seed generator creates:

- orders
- order_items
- products
- inventory
- shipments
- campaign_calendar

It intentionally introduces a duplicate order, an invalid status, missing
product metadata and an extreme transaction value so that validation logic can
be demonstrated rather than merely described.

## KPI Metrics

- Daily GMV
- Daily Order Count
- Average Order Value
- Order Fulfillment Rate
- Delayed Shipment Count
- Low Inventory Alert Count
- Product Sales Rank
- Campaign Period Sales Comparison
- Data Error Count

## Automation Rules

| Rule | Example response |
|---|---|
| Invalid order status | High-severity order alert |
| Delayed or missing shipment | Fulfillment exception queue |
| Stock at/below reorder point | Low-inventory alert |
| Product GMV decline ≥35% | Analyst review alert |
| Missing product fields | Data-quality alert |
| Extreme product unit price | Sales-amount anomaly |
| Duplicate order ID | Deduplicate and record quality error |

## Key Findings

The generated findings are written to
[`outputs/daily_operations_report.md`](outputs/daily_operations_report.md).
Each insight follows Metric → Observation → Possible Cause → Recommended
Action, making the report suitable for a daily operations review.

## Business Impact

- Reduces manual daily consolidation.
- Standardizes KPI definitions.
- Prevents silent data-quality issues from contaminating decisions.
- Prioritizes fulfillment and inventory exceptions.
- Produces CSV contracts that a BI dashboard can consume directly.

## Tech Stack

- Python
- Pandas and NumPy
- SQL
- CSV
- Airflow DAG example
- Markdown reporting

## How to Run

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python src/main.py
```

Reuse existing raw data:

```powershell
python src/main.py --skip-generate
```

Run individual stages:

```powershell
python src/extract_data.py
python src/transform_data.py
python src/validate_data.py
python src/generate_report.py
```

The Airflow example is illustrative and does not require Airflow to run the
local MVP.

## Dashboard-ready Output

| Output | Use |
|---|---|
| `daily_sales_summary.csv` | GMV, orders and AOV trends |
| `product_operation_metrics.csv` | Product GMV, units and rank |
| `alert_log.csv` | Operational and quality exception queue |
| `campaign_period_comparison.csv` | Directional campaign lift |
| `data_quality_summary.csv` | Validation scorecard |

Dashboard layout and refresh expectations are documented in
[`docs/dashboard_spec.md`](docs/dashboard_spec.md).

## Quick Demo (3 commands)

```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Run the full pipeline (generates mock data → validates → produces report)
python src/main.py

# 3. View outputs
#    outputs/daily_operations_report.md     — daily business report
#    outputs/alert_log.csv                  — inventory and fulfillment alerts
#    outputs/daily_sales_summary.csv        — KPI summary by day
#    outputs/product_operation_metrics.csv  — per-product metrics
```

Expected result: pipeline completes in ~3 seconds, 155 alerts generated, daily report covering 3,936 orders.

---

## Resume Highlight

> Built an automated e-commerce operations data pipeline using Python
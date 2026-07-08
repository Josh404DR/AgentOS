# Business Use Case: How This Toolkit Supports the Organization

This document explains, for a hiring manager or data/analytics lead, how a data quality
audit toolkit like this one plugs into real cross-functional workflows — beyond just
"running some checks."

## 1. Dashboard Accuracy

Executive and operational dashboards are only as trustworthy as the tables feeding them.
This toolkit catches the specific issues that most commonly cause dashboard numbers to be
wrong without anyone noticing immediately:

- Duplicate orders or line items silently double-counting revenue or order volume.
- Missing `customer_id` values breaking customer-level rollups (e.g. active customers,
  repeat-purchase rate).
- `item_total` values that don't reconcile with `quantity × unit_price`, which directly
  corrupts any revenue chart built on top of `order_items`.

**Application:** Run these checks before a new dashboard goes live, and on a schedule
(e.g. nightly) once it's in production, so drift is caught before a stakeholder does.

## 2. Sales Analysis Reliability

Sales and market intelligence analysis depends on being able to join order data to product
and customer master data cleanly.

- The referential integrity check (`order_items.product_id → products`) surfaces line
  items that can't be attributed to a real product — these are invisible in a naive
  `GROUP BY product_id` revenue report because they simply don't join, silently
  understating true revenue for the orphaned SKUs.
- Price and quantity outlier checks catch entry errors (e.g. a unit price entered in the
  wrong currency or unit) before they distort average order value or category-level
  trend analysis.

**Application:** Use the issue log as a pre-flight checklist before publishing a
quarterly or monthly sales analysis.

## 3. Product / Master Data Maintenance

- The ID format check flags product and order IDs that don't match the canonical
  pattern — often the result of manual entry, a legacy system export, or a partial
  migration.
- The missing-category check on `products` flags gaps that will break category-level
  reporting and any dashboard filter that groups by category.

**Application:** Feed flagged records back to whoever owns the product master (e.g.
merchandising or catalog management) as a targeted clean-up list, rather than a vague
"the data looks off" complaint.

## 4. Operational Anomaly Tracking (Inventory / Fulfillment)

- Negative stock and extreme stock outliers are strong signals of a warehouse
  reconciliation issue or a receiving/shipping data entry error.
- The date logic check (`ship_date` before `order_date`) flags fulfillment records that
  are logically impossible and would otherwise corrupt SLA and lead-time reporting.

**Application:** Route flagged inventory and fulfillment anomalies to warehouse/operations
ops as a daily or weekly exception report, rather than letting them accumulate silently
in inventory-planning models.

## 5. Cross-Department Data Communication

One of the most common sources of friction between Sales, Finance, and Operations is
disagreement over "whose number is correct." A shared, automated, and transparent data
quality process reduces this friction because:

- The rules are documented (`docs/audit_rules.md`) and consistent across every run.
- The issue log gives every stakeholder the same shared list of known problems, with a
  business risk explanation in plain language (not just a technical error code).
- The Data Quality Score gives leadership a single, trackable number to monitor over
  time — did the last data pipeline change improve or worsen quality?

**Application:** Share `outputs/data_quality_report.md` in a monthly data governance or
analytics review, and track the Overall Data Quality Score trend as a lightweight KPI for
the data pipeline's health.

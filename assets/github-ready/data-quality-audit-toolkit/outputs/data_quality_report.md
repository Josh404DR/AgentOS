# Data Quality Audit Report

**Audit Date:** 2026-07-08
**Dataset:** Synthetic e-commerce dataset (customers, products, orders, order_items, inventory)
**Prepared as part of:** Data Quality Audit Toolkit portfolio project
**Data Source Note:** 100% mock / synthetic data. No real company or customer data was used in this audit.

---

## Executive Summary

This audit reviewed **2,164 records** across 5 core e-commerce tables and identified
**20 distinct data quality issues**, affecting **399 record-level
occurrences** in total. The dataset's **Overall Data Quality Score is 97.3/100**
(Excellent).

The weakest dimension is **Consistency** (95.8/100), which should be
the first priority for remediation before this data is used to drive dashboards, sales reporting, or
operational decisions.

---

## Data Quality Scorecard

| Table | Rows | Completeness | Uniqueness | Validity | Consistency | Overall |
|---|---|---|---|---|---|---|
| customers | 204 | 98.6 | 96.1 | 100.0 | 100.0 | **98.7** (Excellent) |
| products | 60 | 99.0 | 100.0 | 93.3 | 100.0 | **98.1** (Excellent) |
| inventory | 125 | 99.6 | 100.0 | 95.2 | 100.0 | **98.7** (Excellent) |
| orders | 510 | 99.5 | 96.1 | 98.0 | 90.4 | **96.0** (Excellent) |
| order_items | 1265 | 99.7 | 96.0 | 96.0 | 88.6 | **95.1** (Excellent) |
| **ALL_TABLES** | **2164** | **99.3** | **97.6** | **96.5** | **95.8** | **97.3** (Excellent) |

**Scoring method:**
- **Completeness** = 1 − (missing cells ÷ total cells) for the table
- **Uniqueness** = 1 − (duplicate-flagged records ÷ total records)
- **Validity** = 1 − (format/range-violation records ÷ total records)
- **Consistency** = 1 − (cross-field/cross-table logic-violation records ÷ total records)
- **Overall** = simple average of the four dimension scores above

---

## Top Findings at a Glance

| Issue Type | Affected Table | # Records | Business Risk |
|---|---|---|---|
| item_total != quantity * unit_price | `order_items` | 107 | Revenue reported at the line-item level does not reconcile with unit economics; directly misstates sales da... |
| Duplicate records on 'order_item_id' | `order_items` | 50 | Double-counts records in order_items-based reports (e.g. revenue, order volume, customer counts) and can in... |
| order_items.product_id not found in products | `order_items` | 37 | Line items cannot be joined to product master data (name/category/price); product-level sales reports under... |
| Zero or negative quantity | `order_items` | 30 | Units-sold and revenue calculations are invalid for these line items; may indicate failed order cancellations. |
| orders.customer_id not found in customers | `orders` | 29 | Orders cannot be attributed to a known customer; breaks customer lifetime value and retention analysis. |

---

## Detailed Findings

### ISS-001: item_total != quantity * unit_price

- **Dimension:** Consistency
- **Affected Table:** `order_items`
- **Affected Column(s):** `item_total`
- **Number of Records:** 107
- **Sample IDs:** OI-0001210, OI-0000926, OI-0000621, OI-0000632, OI-0000082
- **Business Risk:** Revenue reported at the line-item level does not reconcile with unit economics; directly misstates sales dashboards and financial reporting.
- **Suggested Fix:** Recompute item_total from quantity * unit_price at the source system; add a calculated-field validation before it reaches reporting.

### ISS-002: Duplicate records on 'order_item_id'

- **Dimension:** Uniqueness
- **Affected Table:** `order_items`
- **Affected Column(s):** `order_item_id`
- **Number of Records:** 50
- **Sample IDs:** OI-0000995, OI-0001035, OI-0001093, OI-0000050, OI-0001009
- **Business Risk:** Double-counts records in order_items-based reports (e.g. revenue, order volume, customer counts) and can inflate KPIs presented to stakeholders.
- **Suggested Fix:** De-duplicate on 'order_item_id' keeping the most recent/authoritative record; add a unique constraint at the database level.

### ISS-003: order_items.product_id not found in products

- **Dimension:** Consistency
- **Affected Table:** `order_items`
- **Affected Column(s):** `product_id`
- **Number of Records:** 37
- **Sample IDs:** OI-0001135, OI-0000313, OI-0001032, OI-0000482, OI-0000804
- **Business Risk:** Line items cannot be joined to product master data (name/category/price); product-level sales reports undercount revenue.
- **Suggested Fix:** Investigate deleted/renamed SKUs in the product master; backfill or reconcile product_id mapping before reporting.

### ISS-004: Zero or negative quantity

- **Dimension:** Validity
- **Affected Table:** `order_items`
- **Affected Column(s):** `quantity`
- **Number of Records:** 30
- **Sample IDs:** OI-0000632, OI-0000082, OI-0000059, OI-0001186, OI-0000530
- **Business Risk:** Units-sold and revenue calculations are invalid for these line items; may indicate failed order cancellations.
- **Suggested Fix:** Reject non-positive quantities at checkout/order-entry; reconcile with order status (e.g. cancelled/returned).

### ISS-005: orders.customer_id not found in customers

- **Dimension:** Consistency
- **Affected Table:** `orders`
- **Affected Column(s):** `customer_id`
- **Number of Records:** 29
- **Sample IDs:** ORD-000435, ORD-000365, ORD-000442, ORD-000182, ORD-000426
- **Business Risk:** Orders cannot be attributed to a known customer; breaks customer lifetime value and retention analysis.
- **Suggested Fix:** Validate customer_id against the customer master at order creation; quarantine orders with unresolved customer references.

### ISS-006: Missing values in 'unit_price'

- **Dimension:** Completeness
- **Affected Table:** `order_items`
- **Affected Column(s):** `unit_price`
- **Number of Records:** 25
- **Sample IDs:** OI-0000627, OI-0000824, OI-0000200, OI-0000295, OI-0000567
- **Business Risk:** Revenue and margin calculations for affected line items are unreliable.
- **Suggested Fix:** Backfill 'unit_price' from source system or require it at data-entry time; add a NOT NULL / required-field validation upstream.

### ISS-007: Duplicate records on 'order_id'

- **Dimension:** Uniqueness
- **Affected Table:** `orders`
- **Affected Column(s):** `order_id`
- **Number of Records:** 20
- **Sample IDs:** ORD-000496, ORD-000100, ORD-000078, ORD-000447, ORD-000412
- **Business Risk:** Double-counts records in orders-based reports (e.g. revenue, order volume, customer counts) and can inflate KPIs presented to stakeholders.
- **Suggested Fix:** De-duplicate on 'order_id' keeping the most recent/authoritative record; add a unique constraint at the database level.

### ISS-008: ship_date earlier than order_date

- **Dimension:** Consistency
- **Affected Table:** `orders`
- **Affected Column(s):** `ship_date / order_date`
- **Number of Records:** 20
- **Sample IDs:** ORD-000285, ORD-000210, ORD-000443, ORD-000133, ORD-000498
- **Business Risk:** Logically impossible fulfillment timeline; breaks shipping SLA / lead-time analysis and customer-facing tracking.
- **Suggested Fix:** Add a cross-field validation rule (ship_date >= order_date) at order-management-system ingestion.

### ISS-009: Extreme quantity outlier (> Q3 + 3*IQR)

- **Dimension:** Validity
- **Affected Table:** `order_items`
- **Affected Column(s):** `quantity`
- **Number of Records:** 20
- **Sample IDs:** OI-0000045, OI-0000954, OI-0001173, OI-0000214, OI-0000043
- **Business Risk:** Possible bulk-order data entry error or bot/fraud activity; can distort demand forecasting and inventory planning.
- **Suggested Fix:** Flag for manual review against customer order history; cap or confirm with sales ops before fulfillment.

### ISS-010: Missing values in 'customer_id'

- **Dimension:** Completeness
- **Affected Table:** `orders`
- **Affected Column(s):** `customer_id`
- **Number of Records:** 14
- **Sample IDs:** ORD-000435, ORD-000442, ORD-000182, ORD-000375, ORD-000339
- **Business Risk:** Order cannot be attributed to a customer, breaking CLV/repeat-purchase analysis.
- **Suggested Fix:** Backfill 'customer_id' from source system or require it at data-entry time; add a NOT NULL / required-field validation upstream.

### ISS-011: Invalid 'order_id' format

- **Dimension:** Validity
- **Affected Table:** `orders`
- **Affected Column(s):** `order_id`
- **Number of Records:** 10
- **Sample IDs:** order000138, order000497, order000232, order000176, order000393
- **Business Risk:** Malformed 'order_id' values will fail joins/lookups against other tables, silently dropping records from cross-table reports (e.g. dashboards, SQL joins).
- **Suggested Fix:** Standardize 'order_id' to the canonical format via a validation rule at ingestion; reject or quarantine records that do not match the expected pattern.

### ISS-012: Missing values in 'email'

- **Dimension:** Completeness
- **Affected Table:** `customers`
- **Affected Column(s):** `email`
- **Number of Records:** 8
- **Sample IDs:** CUST-00016, CUST-00116, CUST-00070, CUST-00096, CUST-00031
- **Business Risk:** Cannot run CRM/email marketing campaigns or verify customer identity.
- **Suggested Fix:** Backfill 'email' from source system or require it at data-entry time; add a NOT NULL / required-field validation upstream.

### ISS-013: Duplicate records on 'customer_id'

- **Dimension:** Uniqueness
- **Affected Table:** `customers`
- **Affected Column(s):** `customer_id`
- **Number of Records:** 8
- **Sample IDs:** CUST-00074, CUST-00136, CUST-00029, CUST-00158
- **Business Risk:** Double-counts records in customers-based reports (e.g. revenue, order volume, customer counts) and can inflate KPIs presented to stakeholders.
- **Suggested Fix:** De-duplicate on 'customer_id' keeping the most recent/authoritative record; add a unique constraint at the database level.

### ISS-014: Missing values in 'city'

- **Dimension:** Completeness
- **Affected Table:** `customers`
- **Affected Column(s):** `city`
- **Number of Records:** 6
- **Sample IDs:** CUST-00057, CUST-00080, CUST-00068, CUST-00081, CUST-00038
- **Business Risk:** Regional sales dashboards will undercount or misclassify customers.
- **Suggested Fix:** Backfill 'city' from source system or require it at data-entry time; add a NOT NULL / required-field validation upstream.

### ISS-015: Negative stock_quantity

- **Dimension:** Validity
- **Affected Table:** `inventory`
- **Affected Column(s):** `stock_quantity`
- **Number of Records:** 4
- **Sample IDs:** INV-00001, INV-00076, INV-00094, INV-00105
- **Business Risk:** Physically impossible; usually caused by unreconciled returns/shipments and leads to false stockout or overselling risk.
- **Suggested Fix:** Reconcile with warehouse management system transaction log; enforce stock_quantity >= 0 constraint.

### ISS-016: Missing values in 'category'

- **Dimension:** Completeness
- **Affected Table:** `products`
- **Affected Column(s):** `category`
- **Number of Records:** 3
- **Sample IDs:** PRD-0001, prod_0006, PRD-0037
- **Business Risk:** Category-level revenue dashboards will be incomplete or misleading.
- **Suggested Fix:** Backfill 'category' from source system or require it at data-entry time; add a NOT NULL / required-field validation upstream.

### ISS-017: Missing values in 'stock_quantity'

- **Dimension:** Completeness
- **Affected Table:** `inventory`
- **Affected Column(s):** `stock_quantity`
- **Number of Records:** 2
- **Sample IDs:** INV-00022, INV-00091
- **Business Risk:** Inventory dashboards and reorder alerts cannot evaluate this row.
- **Suggested Fix:** Backfill 'stock_quantity' from source system or require it at data-entry time; add a NOT NULL / required-field validation upstream.

### ISS-018: Invalid 'product_id' format

- **Dimension:** Validity
- **Affected Table:** `products`
- **Affected Column(s):** `product_id`
- **Number of Records:** 2
- **Sample IDs:** prod_0006, prod_0027
- **Business Risk:** Malformed 'product_id' values will fail joins/lookups against other tables, silently dropping records from cross-table reports (e.g. dashboards, SQL joins).
- **Suggested Fix:** Standardize 'product_id' to the canonical format via a validation rule at ingestion; reject or quarantine records that do not match the expected pattern.

### ISS-019: Zero or negative unit_price

- **Dimension:** Validity
- **Affected Table:** `products`
- **Affected Column(s):** `unit_price`
- **Number of Records:** 2
- **Sample IDs:** PRD-0036, PRD-0047
- **Business Risk:** Products would be sold for free or at a negative margin; directly corrupts revenue and margin reporting.
- **Suggested Fix:** Enforce unit_price > 0 at data entry; route flagged SKUs to merchandising for price correction.

### ISS-020: Extreme high stock_quantity outlier (> Q3 + 3*IQR)

- **Dimension:** Validity
- **Affected Table:** `inventory`
- **Affected Column(s):** `stock_quantity`
- **Number of Records:** 2
- **Sample IDs:** INV-00021, INV-00090
- **Business Risk:** Possible duplicate receiving entry or unit-of-measure error; ties up working-capital reporting and reorder-point logic.
- **Suggested Fix:** Cross-check against purchase orders and warehouse receiving records before trusting for reorder automation.

---

## Business Impact Summary

- **Dashboard accuracy risk:** Missing values, duplicates, and calculation mismatches in
  `order_items` and `orders` directly inflate or deflate revenue and order-volume KPIs shown on
  executive dashboards.
- **Sales analysis reliability:** Referential integrity breaks (order line items pointing to
  products that don't exist) understate product-level revenue and can misdirect merchandising
  decisions.
- **Inventory / operations risk:** Negative and extreme-outlier stock values can trigger false
  stockout alerts or mask real overselling risk in the warehouse.
- **Cross-department trust:** Every unresolved issue below is a potential point of disagreement
  between Sales, Finance, and Operations when reconciling numbers — fixing these at the source
  reduces "whose number is right?" friction.

---

## Recommendations

1. Prioritize fixes in the **Consistency** dimension first — it has the largest impact on the
   Overall Data Quality Score.
2. Add the SQL checks in `sql/` as scheduled data-quality gates (e.g. run nightly, alert if any
   check returns rows) rather than relying on manual, one-off audits.
3. Treat `order_items` as the highest-leverage table to monitor — it feeds directly into revenue
   and margin reporting and had the highest concentration of issues in this audit.
4. Re-run this audit after each fix to track the Overall Data Quality Score trend over time.

---

*This report was generated automatically by `audit_report_generator.py` from the checks defined in
`data_quality_checks.py`. See `docs/audit_rules.md` for the full rule definitions and
`docs/business_use_case.md` for how this toolkit supports cross-functional data quality workflows.*

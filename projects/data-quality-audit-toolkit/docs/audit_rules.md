# Audit Rules Reference

This document defines every data quality rule implemented in
`src/data_quality_checks.py` (and mirrored in `sql/`), including which dimension
it belongs to, how it's calculated, and the approximate rate at which the
mock data generator injects the corresponding issue (for reproducibility and
transparency — this is a portfolio project, so the "answers" are documented
openly).

## Dimension definitions

| Dimension | Question it answers | Formula (per table) |
|---|---|---|
| **Completeness** | Are required fields populated? | 1 − (missing cells ÷ total cells) |
| **Uniqueness** | Is each record represented exactly once? | 1 − (duplicate-flagged records ÷ total records) |
| **Validity** | Do values conform to expected format/range? | 1 − (format/range-violation records ÷ total records) |
| **Consistency** | Do related fields/tables agree with each other? | 1 − (cross-field/cross-table violation records ÷ total records) |

**Overall Score** (per table and dataset-wide) = simple average of the four dimension scores.

## Rule catalog

### 1. Missing value check — Completeness
Flags any NULL/blank value in a business-relevant column (e.g. `customers.email`,
`customers.city`, `products.category`, `orders.customer_id`, `order_items.unit_price`,
`inventory.stock_quantity`).
- Injected in mock data at ~2–5% per targeted column.

### 2. Duplicate record check — Uniqueness
Flags records that share the same primary business key (`customer_id`, `product_id`,
`order_id`, `order_item_id`, `inventory_id`).
- Injected in mock data at ~2% per table (exact-duplicate rows appended).

### 3. ID format check — Validity
Validates ID formats against their expected pattern:
- `product_id` → `PRD-####`
- `order_id` → `ORD-######`
- `customer_id` → `CUST-#####`
- Injected in mock data at ~2–3% (prefix/casing corrupted).

### 4. Price anomaly check — Validity
Flags `products.unit_price` that is zero/negative, or an extreme statistical outlier
(> Q3 + 3×IQR, computed from valid prices only).
- Injected in mock data at ~4% (zero, negative, or inflated 20–40x price).

### 5. Quantity anomaly check — Validity
Flags `order_items.quantity` that is zero/negative, or an extreme statistical outlier
(> Q3 + 3×IQR).
- Injected in mock data at ~4% (zero, negative, or 500–2000 units).

### 6. Date logic check — Consistency
Flags orders where `ship_date` is earlier than `order_date` (a physically impossible
fulfillment timeline).
- Injected in mock data at ~4%.

### 7. Referential integrity check — Consistency
Flags orphaned foreign keys:
- `order_items.product_id` not present in `products`
- `orders.customer_id` not present in `customers`
- Injected in mock data at ~3% each.

### 8. Inventory anomaly check — Validity
Flags `inventory.stock_quantity` that is negative, or an extreme statistical outlier
(> Q3 + 3×IQR).
- Injected in mock data at ~2–3%.

### 9. Sales amount calculation check — Consistency
Flags `order_items` where `item_total` does not equal `quantity × unit_price`
(tolerance: ±0.01).
- Injected in mock data at ~5% (a random $5–$50 discrepancy added).

## Notes on thresholds

- Outlier bounds use the IQR method (`Q3 + 3×IQR`) computed dynamically from the actual
  data at runtime, rather than hard-coded cutoffs — this keeps the check valid even if
  the dataset's scale changes (e.g. more expensive product categories are added).
- The SQL versions in `sql/outlier_check.sql` include both the dynamic IQR approach and
  illustrative fixed thresholds, since fixed cutoffs are sometimes easier to operationalize
  as a first pass in a data warehouse.

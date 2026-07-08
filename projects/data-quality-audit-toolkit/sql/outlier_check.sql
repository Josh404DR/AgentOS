-- outlier_check.sql
-- Purpose: Identify price, quantity, and inventory outliers/anomalies.
-- Tables: products, order_items, inventory

-- 1. Zero or negative product price
SELECT
    product_id,
    product_name,
    unit_price,
    'Zero or negative price' AS issue_note
FROM products
WHERE unit_price <= 0;

-- 2. Extreme high product price (using IQR bounds computed from valid prices)
-- SQLite/Postgres-style approximate quantile via NTILE, adapt as needed per engine.
WITH ranked AS (
    SELECT unit_price,
           NTILE(4) OVER (ORDER BY unit_price) AS quartile
    FROM products
    WHERE unit_price > 0
),
bounds AS (
    SELECT
        MAX(CASE WHEN quartile = 1 THEN unit_price END) AS q1,
        MAX(CASE WHEN quartile = 3 THEN unit_price END) AS q3
    FROM ranked
)
SELECT
    p.product_id,
    p.product_name,
    p.unit_price,
    b.q3 + 3 * (b.q3 - b.q1) AS upper_bound,
    'Extreme high price outlier' AS issue_note
FROM products p, bounds b
WHERE p.unit_price > b.q3 + 3 * (b.q3 - b.q1);

-- 3. Zero, negative, or extreme quantity in order_items
SELECT
    order_item_id,
    order_id,
    product_id,
    quantity,
    CASE
        WHEN quantity <= 0 THEN 'Zero or negative quantity'
        WHEN quantity > 400 THEN 'Extreme high quantity'
    END AS issue_note
FROM order_items
WHERE quantity <= 0 OR quantity > 400;

-- 4. Negative or extreme high inventory stock
SELECT
    inventory_id,
    product_id,
    warehouse,
    stock_quantity,
    CASE
        WHEN stock_quantity < 0 THEN 'Negative stock'
        WHEN stock_quantity > 5000 THEN 'Extreme high stock'
    END AS issue_note
FROM inventory
WHERE stock_quantity < 0 OR stock_quantity > 5000;

-- Note: thresholds above (400, 5000) are illustrative fixed cutoffs for SQL use;
-- the Python pipeline (data_quality_checks.py) uses a statistically derived
-- IQR-based bound (Q3 + 3*IQR) computed dynamically from the actual data.

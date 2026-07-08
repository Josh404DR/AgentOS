-- referential_integrity_check.sql
-- Purpose: Identify broken foreign-key relationships and cross-field date logic errors.
-- Tables: order_items -> products, orders -> customers

-- 1. order_items.product_id not present in products (orphaned line items)
SELECT
    oi.order_item_id,
    oi.order_id,
    oi.product_id,
    'product_id not found in products table' AS issue_note
FROM order_items oi
LEFT JOIN products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- 2. orders.customer_id not present in customers (orphaned orders)
SELECT
    o.order_id,
    o.customer_id,
    'customer_id not found in customers table' AS issue_note
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- 3. Date logic error: ship_date earlier than order_date
SELECT
    order_id,
    order_date,
    ship_date,
    'ship_date earlier than order_date' AS issue_note
FROM orders
WHERE ship_date < order_date;

-- 4. Sales amount calculation check: item_total should equal quantity * unit_price
SELECT
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price,
    item_total,
    ROUND(quantity * unit_price, 2) AS expected_total,
    'item_total does not match quantity * unit_price' AS issue_note
FROM order_items
WHERE ABS(item_total - ROUND(quantity * unit_price, 2)) > 0.01;

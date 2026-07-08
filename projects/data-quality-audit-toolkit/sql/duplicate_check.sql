-- duplicate_check.sql
-- Purpose: Identify duplicate records on each table's primary business key.
-- Tables: customers, products, orders, order_items, inventory

-- 1. Duplicate customer_id
SELECT
    customer_id,
    COUNT(*) AS record_count
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- 2. Duplicate product_id
SELECT
    product_id,
    COUNT(*) AS record_count
FROM products
GROUP BY product_id
HAVING COUNT(*) > 1;

-- 3. Duplicate order_id
SELECT
    order_id,
    COUNT(*) AS record_count
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;

-- 4. Duplicate order_item_id
SELECT
    order_item_id,
    COUNT(*) AS record_count
FROM order_items
GROUP BY order_item_id
HAVING COUNT(*) > 1;

-- 5. Duplicate inventory_id
SELECT
    inventory_id,
    COUNT(*) AS record_count
FROM inventory
GROUP BY inventory_id
HAVING COUNT(*) > 1;

-- 6. Fully duplicate order_item rows (same order_id + product_id + quantity + unit_price)
-- Useful to catch accidental double line-item entry, not just duplicate IDs.
SELECT
    order_id,
    product_id,
    quantity,
    unit_price,
    COUNT(*) AS record_count
FROM order_items
GROUP BY order_id, product_id, quantity, unit_price
HAVING COUNT(*) > 1;

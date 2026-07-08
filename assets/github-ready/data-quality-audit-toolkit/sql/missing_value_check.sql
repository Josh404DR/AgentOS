-- missing_value_check.sql
-- Purpose: Identify missing (NULL) values in key business fields.
-- Tables: customers, products, orders, order_items, inventory
-- Usage: Run each SELECT independently; any returned rows are data quality issues.

-- 1. Customers with missing email or city
SELECT
    customer_id,
    customer_name,
    email,
    city,
    'Missing email or city' AS issue_note
FROM customers
WHERE email IS NULL OR TRIM(email) = ''
   OR city IS NULL OR TRIM(city) = '';

-- 2. Products with missing category
SELECT
    product_id,
    product_name,
    category,
    'Missing category' AS issue_note
FROM products
WHERE category IS NULL OR TRIM(category) = '';

-- 3. Orders with missing customer_id
SELECT
    order_id,
    customer_id,
    order_date,
    'Missing customer_id' AS issue_note
FROM orders
WHERE customer_id IS NULL OR TRIM(customer_id) = '';

-- 4. Order items with missing unit_price
SELECT
    order_item_id,
    order_id,
    product_id,
    unit_price,
    'Missing unit_price' AS issue_note
FROM order_items
WHERE unit_price IS NULL;

-- 5. Inventory rows with missing stock_quantity
SELECT
    inventory_id,
    product_id,
    warehouse,
    stock_quantity,
    'Missing stock_quantity' AS issue_note
FROM inventory
WHERE stock_quantity IS NULL;

-- Summary: missing-value count per table/column (adapt table name per run)
-- Example for customers.email:
SELECT
    'customers' AS table_name,
    'email' AS column_name,
    COUNT(*) AS missing_count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM customers), 2) AS missing_pct
FROM customers
WHERE email IS NULL OR TRIM(email) = '';

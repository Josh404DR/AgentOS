-- Daily GMV, order count, and AOV for commercial orders.
WITH order_values AS (
    SELECT
        o.order_id,
        DATE(o.order_created_at) AS order_date,
        SUM(oi.quantity * oi.unit_price) AS order_value
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status IN ('completed', 'processing')
    GROUP BY o.order_id, DATE(o.order_created_at)
)
SELECT
    order_date,
    ROUND(SUM(order_value), 2) AS daily_gmv,
    COUNT(DISTINCT order_id) AS daily_order_count,
    ROUND(AVG(order_value), 2) AS average_order_value
FROM order_values
GROUP BY order_date
ORDER BY order_date;

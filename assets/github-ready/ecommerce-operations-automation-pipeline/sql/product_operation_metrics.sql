-- Product ranking and operational sales metrics.
SELECT
    p.product_id,
    p.product_name,
    p.category,
    SUM(oi.quantity) AS units_sold,
    COUNT(DISTINCT o.order_id) AS order_count,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS gmv,
    DENSE_RANK() OVER (
        ORDER BY SUM(oi.quantity * oi.unit_price) DESC
    ) AS sales_rank
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
JOIN products p ON p.product_id = oi.product_id
WHERE o.order_status IN ('completed', 'processing')
GROUP BY p.product_id, p.product_name, p.category
ORDER BY sales_rank;

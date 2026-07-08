-- Low inventory products prioritized by sales rank.
WITH recent_sales AS (
    SELECT
        oi.product_id,
        SUM(oi.quantity) AS units_sold
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    WHERE o.order_status IN ('completed', 'processing')
      AND DATE(o.order_created_at) >= DATE('2025-03-31', '-13 day')
    GROUP BY oi.product_id
)
SELECT
    i.product_id,
    p.product_name,
    i.stock_on_hand,
    i.reorder_point,
    COALESCE(s.units_sold, 0) AS recent_units_sold,
    i.stock_on_hand - i.reorder_point AS stock_buffer
FROM inventory i
JOIN products p ON p.product_id = i.product_id
LEFT JOIN recent_sales s ON s.product_id = i.product_id
WHERE i.stock_on_hand <= i.reorder_point
ORDER BY recent_units_sold DESC, stock_buffer ASC;

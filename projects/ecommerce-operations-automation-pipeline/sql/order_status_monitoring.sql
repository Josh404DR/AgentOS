-- Status mix and fulfillment monitoring by day.
SELECT
    DATE(o.order_created_at) AS order_date,
    o.order_status,
    COUNT(DISTINCT o.order_id) AS order_count,
    SUM(CASE WHEN s.shipped_date IS NOT NULL THEN 1 ELSE 0 END) AS fulfilled_count,
    SUM(
        CASE
            WHEN s.shipped_date IS NULL
              OR DATE(s.shipped_date) > DATE(s.promised_ship_date)
            THEN 1 ELSE 0
        END
    ) AS delayed_count
FROM orders o
LEFT JOIN shipments s ON s.order_id = o.order_id
GROUP BY DATE(o.order_created_at), o.order_status
ORDER BY order_date, order_status;

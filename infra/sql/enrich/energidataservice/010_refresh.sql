-- No-op by design.
-- The enrich layer is implemented as views, so data is always derived from raw.
SELECT
    'enrich.energinet_price' AS object_name,
    NOW() AS checked_at,
    COUNT(*) AS current_row_count
FROM enrich.energinet_price;

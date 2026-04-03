-- Refresh curated layer materialized views
-- 
-- Previously: TRUNCATE TABLE + INSERT (data mutation)
-- Now: REFRESH MATERIALIZED VIEW (declarative transformation)

DO $$
DECLARE
    is_populated BOOLEAN;
BEGIN
    SELECT pm.ispopulated
    INTO is_populated
    FROM pg_matviews AS pm
    WHERE pm.schemaname = 'mart'
      AND pm.matviewname = 'power_price_15min';

    IF COALESCE(is_populated, FALSE) THEN
        -- Non-blocking read behavior for recurring refresh jobs.
        REFRESH MATERIALIZED VIEW CONCURRENTLY mart.power_price_15min;
    ELSE
        -- First refresh after WITH NO DATA must be non-concurrent.
        REFRESH MATERIALIZED VIEW mart.power_price_15min;
    END IF;
END
$$;

-- Log refresh result (optional monitoring)
SELECT
    'power_price_15min' AS view_name,
    NOW() AS refreshed_at,
    (SELECT COUNT(*) FROM mart.power_price_15min) AS row_count;

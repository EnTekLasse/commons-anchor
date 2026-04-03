-- Refresh curated API time-series materialized views.
DO $$
DECLARE
    is_populated BOOLEAN;
BEGIN
    SELECT pm.ispopulated
    INTO is_populated
    FROM pg_matviews AS pm
    WHERE pm.schemaname = 'mart'
      AND pm.matviewname = 'api_timeseries_1h';

    IF COALESCE(is_populated, FALSE) THEN
        REFRESH MATERIALIZED VIEW CONCURRENTLY mart.api_timeseries_1h;
    ELSE
        REFRESH MATERIALIZED VIEW mart.api_timeseries_1h;
    END IF;
END
$$;

SELECT
    'api_timeseries_1h' AS view_name,
    NOW() AS refreshed_at,
    (SELECT COUNT(*) FROM mart.api_timeseries_1h) AS row_count;

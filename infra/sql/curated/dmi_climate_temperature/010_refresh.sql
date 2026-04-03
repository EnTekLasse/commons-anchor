-- Refresh DMI climate curated materialized views.
DO $$
DECLARE
    is_populated BOOLEAN;
BEGIN
    SELECT pm.ispopulated
    INTO is_populated
    FROM pg_matviews AS pm
    WHERE pm.schemaname = 'mart'
      AND pm.matviewname = 'dmi_climate_temperature_hourly';

    IF COALESCE(is_populated, FALSE) THEN
        REFRESH MATERIALIZED VIEW CONCURRENTLY mart.dmi_climate_temperature_hourly;
    ELSE
        REFRESH MATERIALIZED VIEW mart.dmi_climate_temperature_hourly;
    END IF;
END
$$;

SELECT
    'dmi_climate_temperature_hourly' AS view_name,
    NOW() AS refreshed_at,
    (SELECT COUNT(*) FROM mart.dmi_climate_temperature_hourly) AS row_count;

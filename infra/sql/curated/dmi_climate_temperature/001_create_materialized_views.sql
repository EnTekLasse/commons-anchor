CREATE SCHEMA IF NOT EXISTS mart;

-- Hourly curated temperature view. The enrich layer already exposes one row per
-- hour, but the curated layer gives us a stable consumer contract and a refresh
-- point that can later combine DMI climate with energy or forecast models.
CREATE MATERIALIZED VIEW IF NOT EXISTS mart.dmi_climate_temperature_hourly AS
SELECT
    ts_from_utc,
    ts_to_utc,
    municipality_id,
    municipality_name,
    ROUND(AVG(mean_temp_c), 2) AS mean_temp_c,
    COUNT(*)::INT AS source_count,
    MAX(enriched_at) AS source_max_enriched_at,
    NOW() AS refreshed_at
FROM enrich.dmi_climate_temperature
GROUP BY 1, 2, 3, 4
WITH NO DATA;

CREATE UNIQUE INDEX IF NOT EXISTS dmi_climate_temperature_hourly_ux
    ON mart.dmi_climate_temperature_hourly (ts_from_utc, municipality_id);

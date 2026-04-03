CREATE SCHEMA IF NOT EXISTS semantic;

-- Serving view aimed at dashboards and quick inspection.
-- Keep the contract stable and intentionally narrow: one municipality-level
-- hourly temperature series with a recent sliding window.
CREATE OR REPLACE VIEW semantic.dmi_climate_temperature_last_7d AS
SELECT
    ts_from_utc,
    ts_to_utc,
    municipality_id,
    municipality_name,
    mean_temp_c,
    source_count,
    source_max_enriched_at,
    refreshed_at
FROM mart.dmi_climate_temperature_hourly
WHERE ts_from_utc >= NOW() - INTERVAL '7 days';

CREATE SCHEMA IF NOT EXISTS semantic;

CREATE OR REPLACE VIEW semantic.power_price_overview AS
SELECT
    ts_utc,
    area,
    price_dkk_mwh,
    source_count,
    refreshed_at
FROM mart.power_price_15min;

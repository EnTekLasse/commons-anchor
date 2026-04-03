CREATE SCHEMA IF NOT EXISTS mart;

CREATE MATERIALIZED VIEW IF NOT EXISTS mart.power_price_15min AS
SELECT
    ts_utc,
    area,
    ROUND(AVG(price_dkk_mwh), 4) AS price_dkk_mwh,
    COUNT(*)::INT AS source_count,
    NOW() AS refreshed_at
FROM enrich.energinet_price
WHERE dataset = 'DayAheadPrices'
GROUP BY 1, 2
WITH NO DATA;

CREATE UNIQUE INDEX IF NOT EXISTS power_price_15min_ts_area_uniq_idx
    ON mart.power_price_15min (ts_utc, area);

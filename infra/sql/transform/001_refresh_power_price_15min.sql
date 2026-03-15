DROP TABLE IF EXISTS mart.power_price_hourly;

INSERT INTO mart.power_price_15min (
    ts_utc,
    area,
    price_dkk_mwh,
    source_count,
    refreshed_at
)
SELECT
    ts_utc,
    area,
    ROUND(AVG(price_dkk_mwh), 4) AS price_dkk_mwh,
    COUNT(*) AS source_count,
    NOW() AS refreshed_at
FROM staging.energinet_raw
WHERE dataset = 'DayAheadPrices'
GROUP BY 1, 2
ON CONFLICT (ts_utc, area)
DO UPDATE SET
    price_dkk_mwh = EXCLUDED.price_dkk_mwh,
    source_count = EXCLUDED.source_count,
    refreshed_at = NOW();
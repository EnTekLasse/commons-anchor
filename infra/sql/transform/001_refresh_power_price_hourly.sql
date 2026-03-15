INSERT INTO mart.power_price_hourly (
    ts_utc,
    area,
    avg_price_dkk_mwh,
    source_count,
    refreshed_at
)
SELECT
    date_trunc('hour', ts_utc) AS ts_utc,
    area,
    ROUND(AVG(price_dkk_mwh), 4) AS avg_price_dkk_mwh,
    COUNT(*) AS source_count,
    NOW() AS refreshed_at
FROM staging.energinet_raw
GROUP BY 1, 2
ON CONFLICT (ts_utc, area)
DO UPDATE SET
    avg_price_dkk_mwh = EXCLUDED.avg_price_dkk_mwh,
    source_count = EXCLUDED.source_count,
    refreshed_at = NOW();
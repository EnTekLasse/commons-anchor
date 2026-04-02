BEGIN;

TRUNCATE TABLE mart.power_price_15min;

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
FROM enrich.energinet_price
WHERE dataset = 'DayAheadPrices'
GROUP BY 1, 2;

COMMIT;

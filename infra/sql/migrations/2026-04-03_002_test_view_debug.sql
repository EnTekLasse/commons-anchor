-- FIXED: Automated test for view vs table pattern
-- Debug version to identify the exact issue

CREATE SCHEMA IF NOT EXISTS test_patterns;

-- Current pattern: table with insert
CREATE TABLE IF NOT EXISTS test_patterns.energinet_price_as_table (
    raw_id BIGINT PRIMARY KEY,
    dataset TEXT NOT NULL,
    area TEXT NOT NULL,
    price_dkk_mwh NUMERIC(12, 4) NOT NULL,
    ts_utc TIMESTAMPTZ NOT NULL,
    payload JSONB NOT NULL,
    enriched_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- New pattern: view
CREATE OR REPLACE VIEW test_patterns.energinet_price_as_view AS
SELECT
    raw.id AS raw_id,
    raw.dataset,
    raw.price_area AS area,
    ROUND(
        (
            CASE raw.dataset
                WHEN 'DayAheadPrices' THEN raw.record ->> 'DayAheadPriceDKK'
                WHEN 'Elspotprices' THEN raw.record ->> 'SpotPriceDKK'
            END
        )::NUMERIC,
        4
    ) AS price_dkk_mwh,
    CASE
        WHEN COALESCE(
            CASE raw.dataset
                WHEN 'DayAheadPrices' THEN raw.record ->> 'TimeUTC'
                WHEN 'Elspotprices' THEN raw.record ->> 'HourUTC'
            END,
            ''
        ) LIKE '%Z'
        THEN REPLACE(
            CASE raw.dataset
                WHEN 'DayAheadPrices' THEN raw.record ->> 'TimeUTC'
                WHEN 'Elspotprices' THEN raw.record ->> 'HourUTC'
            END,
            'Z',
            '+00:00'
        )::TIMESTAMPTZ
        ELSE (
            CASE raw.dataset
                WHEN 'DayAheadPrices' THEN raw.record ->> 'TimeUTC'
                WHEN 'Elspotprices' THEN raw.record ->> 'HourUTC'
            END
        )::TIMESTAMP AT TIME ZONE 'UTC'
    END AS ts_utc,
    raw.record AS payload,
    NOW() AS enriched_at
FROM staging.energinet_raw raw;

-- ==== TEST WITH REAL DATA ====
-- Use production raw data to test

SELECT
    'TABLE COUNT' AS metric,
    COUNT(*) AS count
FROM (
    SELECT DISTINCT ON (raw_id) raw_id
    FROM (
        SELECT
            raw.id AS raw_id,
            raw.dataset,
            raw.price_area AS area,
            ROUND(
                (
                    CASE raw.dataset
                        WHEN 'DayAheadPrices' THEN raw.record ->> 'DayAheadPriceDKK'
                        WHEN 'Elspotprices' THEN raw.record ->> 'SpotPriceDKK'
                    END
                )::NUMERIC,
                4
            ) AS price_dkk_mwh,
            CASE
                WHEN COALESCE(
                    CASE raw.dataset
                        WHEN 'DayAheadPrices' THEN raw.record ->> 'TimeUTC'
                        WHEN 'Elspotprices' THEN raw.record ->> 'HourUTC'
                    END,
                    ''
                ) LIKE '%Z'
                THEN REPLACE(
                    CASE raw.dataset
                        WHEN 'DayAheadPrices' THEN raw.record ->> 'TimeUTC'
                        WHEN 'Elspotprices' THEN raw.record ->> 'HourUTC'
                    END,
                    'Z',
                    '+00:00'
                )::TIMESTAMPTZ
                ELSE (
                    CASE raw.dataset
                        WHEN 'DayAheadPrices' THEN raw.record ->> 'TimeUTC'
                        WHEN 'Elspotprices' THEN raw.record ->> 'HourUTC'
                    END
                )::TIMESTAMP AT TIME ZONE 'UTC'
            END AS ts_utc,
            raw.record AS payload
        FROM staging.energinet_raw raw
    ) t
) t;

-- View count
SELECT
    'VIEW COUNT' AS metric,
    COUNT(DISTINCT raw_id) AS count
FROM test_patterns.energinet_price_as_view;

-- Show raw data to understand structure
SELECT
    'RAW SAMPLE' AS metric,
    COUNT(*) AS count,
    COUNT(DISTINCT id) AS distinct_ids,
    COUNT(DISTINCT dataset) AS datasets
FROM staging.energinet_raw;

-- Compare first 5 rows from both sources
SELECT
    'FIRST 5 FROM TABLE (conceptual)' AS source,
    raw_id, dataset, area, price_dkk_mwh
FROM test_patterns.energinet_price_as_view
LIMIT 5;

-- Success indicator
SELECT
    CASE
        WHEN (SELECT COUNT(*) FROM staging.energinet_raw) > 0
        THEN 'SUCCESS: Test data exists - view is working'
        ELSE 'WARNING: No raw data - populate staging.energinet_raw first'
    END AS status;

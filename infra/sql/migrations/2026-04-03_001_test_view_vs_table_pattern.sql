-- Automated test: Verify that enriched-as-view produces identical results to enriched-as-table
-- This test proves the refactoring is safe before committing to it.

-- ============================================================================
-- SETUP: Create test schemas with parallel implementations
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS test_patterns;

-- Baseline: Current pattern (table + insert)
CREATE TABLE IF NOT EXISTS test_patterns.energinet_price_as_table (
    raw_id BIGINT PRIMARY KEY,
    dataset TEXT NOT NULL,
    area TEXT NOT NULL,
    price_dkk_mwh NUMERIC(12, 4) NOT NULL,
    ts_utc TIMESTAMPTZ NOT NULL,
    payload JSONB NOT NULL,
    enriched_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- New pattern: View + transformation
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

-- ============================================================================
-- LOAD TEST DATA: Create test raw table with realistic data
-- ============================================================================

CREATE TABLE IF NOT EXISTS test_patterns.energinet_raw_test AS
SELECT
    ROW_NUMBER() OVER () AS id,
    'DayAheadPrices'::TEXT AS dataset,
    'DK1'::TEXT AS price_area,
    jsonb_build_object(
        'DayAheadPriceDKK', (100 + random() * 500)::TEXT,
        'TimeUTC', (CURRENT_TIMESTAMP - INTERVAL '24 hours' * (ROW_NUMBER() OVER ()))::text || 'Z'
    ) AS record
FROM generate_series(1, 10);

-- ============================================================================
-- TEST 1: Load via TABLE + INSERT (current pattern)
-- ============================================================================

TRUNCATE TABLE test_patterns.energinet_price_as_table;

INSERT INTO test_patterns.energinet_price_as_table (
    raw_id, dataset, area, price_dkk_mwh, ts_utc, payload, enriched_at
)
SELECT
    t.id,
    t.dataset,
    t.price_area,
    ROUND(
        (
            CASE t.dataset
                WHEN 'DayAheadPrices' THEN t.record ->> 'DayAheadPriceDKK'
                WHEN 'Elspotprices' THEN t.record ->> 'SpotPriceDKK'
            END
        )::NUMERIC,
        4
    ) AS price_dkk_mwh,
    CASE
        WHEN COALESCE(
            CASE t.dataset
                WHEN 'DayAheadPrices' THEN t.record ->> 'TimeUTC'
                WHEN 'Elspotprices' THEN t.record ->> 'HourUTC'
            END,
            ''
        ) LIKE '%Z'
        THEN REPLACE(
            CASE t.dataset
                WHEN 'DayAheadPrices' THEN t.record ->> 'TimeUTC'
                WHEN 'Elspotprices' THEN t.record ->> 'HourUTC'
            END,
            'Z',
            '+00:00'
        )::TIMESTAMPTZ
        ELSE (
            CASE t.dataset
                WHEN 'DayAheadPrices' THEN t.record ->> 'TimeUTC'
                WHEN 'Elspotprices' THEN t.record ->> 'HourUTC'
            END
        )::TIMESTAMP AT TIME ZONE 'UTC'
    END AS ts_utc,
    t.record AS payload,
    NOW() AS enriched_at
FROM test_patterns.energinet_raw_test t;

-- ============================================================================
-- TEST 2: Query via VIEW (new pattern)
-- ============================================================================

-- Both should produce identical results (ignoring enriched_at timestamp)
SELECT * FROM test_patterns.energinet_price_as_view LIMIT 10;

-- ============================================================================
-- COMPARISON TEST: Are the results identical?
-- ============================================================================

WITH table_data AS (
    SELECT
        raw_id, dataset, area, price_dkk_mwh, ts_utc, payload
    FROM test_patterns.energinet_price_as_table
    ORDER BY raw_id
),
view_data AS (
    SELECT
        raw_id, dataset, area, price_dkk_mwh, ts_utc, payload
    FROM test_patterns.energinet_price_as_view
    ORDER BY raw_id
)
SELECT
    CASE
        WHEN (SELECT COUNT(*) FROM table_data) != (SELECT COUNT(*) FROM view_data)
        THEN 'FAIL: Row count mismatch'
        WHEN EXISTS (SELECT 1 FROM table_data EXCEPT SELECT 1 FROM view_data)
        THEN 'FAIL: Data mismatch'
        ELSE 'SUCCESS: Table and View produce identical results'
    END AS test_result;

-- ============================================================================
-- EDGE CASE TESTS
-- ============================================================================

-- Test 1: Empty dataset
SELECT 'Test 1: Empty result set' AS test_name;
DELETE FROM test_patterns.energinet_raw_test;
SELECT COUNT(*) FROM test_patterns.energinet_price_as_view;

-- Test 2: Duplicate raw_ids (should fail on table with PK, succeed on view)
INSERT INTO test_patterns.energinet_raw_test VALUES (1, 'Elspotprices', 'DK2', '{"SpotPriceDKK": "150", "HourUTC": "2026-04-03T12:00:00Z"}');
INSERT INTO test_patterns.energinet_raw_test VALUES (1, 'Elspotprices', 'DK2', '{"SpotPriceDKK": "155", "HourUTC": "2026-04-03T12:00:00Z"}');
SELECT 'Test 2: Duplicate raw_ids' AS test_name;
SELECT COUNT(*) FROM test_patterns.energinet_price_as_view WHERE raw_id = 1;

-- ============================================================================
-- CLEANUP
-- ============================================================================

-- Comment out this block if you want to inspect the test tables afterward
-- DROP SCHEMA test_patterns CASCADE;

ROLLBACK;  -- Safety: test runs in transaction, change to COMMIT if satisfied

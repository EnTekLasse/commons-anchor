-- Migration: Convert mart.power_price_15min from TABLE to MATERIALIZED VIEW
-- Date: 2026-04-03
--
-- Purpose:
--   Replace the TRUNCATE + INSERT pattern with a declarative MATERIALIZED VIEW.
--   This decouples refresh logic from schema, making it easier to understand
--   and maintain the transformation.
--
-- What changes:
--   - Before: TRUNCATE TABLE + INSERT (in 010_refresh.sql)
--   - After: CREATE MATERIALIZED VIEW + REFRESH MATERIALIZED VIEW
--
-- Backward compat:
--   - Queries using SELECT * FROM mart.power_price_15min continue to work
--   - No application code changes needed
--
-- Rollback:
--   - If you need to roll back, save current data from mart.power_price_15min
--     before running this migration.

BEGIN;

-- Step 1: Backup current data
CREATE TABLE IF NOT EXISTS mart.power_price_15min_backup AS
SELECT * FROM mart.power_price_15min;

-- Step 2: Drop dependent views (will be recreated)
DROP VIEW IF EXISTS semantic.power_price_overview CASCADE;

-- Step 3: Drop the old table
DROP TABLE IF EXISTS mart.power_price_15min CASCADE;

-- Step 4: Create MATERIALIZED VIEW with identical logic
CREATE MATERIALIZED VIEW mart.power_price_15min AS
SELECT
    ts_utc,
    area,
    ROUND(AVG(price_dkk_mwh), 4) AS price_dkk_mwh,
    COUNT(*)::INT AS source_count,
    NOW() AS refreshed_at
FROM enrich.energinet_price
WHERE dataset = 'DayAheadPrices'
GROUP BY 1, 2;

-- Step 5: Create index for concurrent refresh
-- Note: CONCURRENTLY requires a unique index with no WHERE clause
CREATE UNIQUE INDEX IF NOT EXISTS power_price_15min_ts_area_uniq_idx
    ON mart.power_price_15min (ts_utc, area);

-- Step 6: Recreate dependent views
CREATE OR REPLACE VIEW semantic.power_price_overview AS
SELECT
    ts_utc,
    area,
    price_dkk_mwh,
    source_count,
    refreshed_at
FROM mart.power_price_15min;

-- Step 7: Verify data looks correct
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT ts_utc) AS distinct_timestamps,
    COUNT(DISTINCT area) AS areas
FROM mart.power_price_15min;

COMMIT;

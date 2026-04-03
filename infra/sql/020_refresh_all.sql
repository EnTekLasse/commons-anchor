-- Explicit refresh orchestration for materialized views.
--
-- This script refreshes all curated and serving layer views after raw data updates.
-- It replaces the old TRUNCATE + INSERT pattern with REFRESH MATERIALIZED VIEW.
--
-- Usage:
--   docker compose --profile jobs run --rm power-price-transform
--
-- Note:
--   Includes use /sql/... absolute paths, which are provided by the transform
--   container volume mount in docker-compose.

-- Curated layer: main fact tables and metrics
\i /sql/curated/power_price/010_refresh.sql

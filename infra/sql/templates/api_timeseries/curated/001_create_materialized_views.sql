CREATE SCHEMA IF NOT EXISTS mart;

CREATE MATERIALIZED VIEW IF NOT EXISTS mart.api_timeseries_1h AS
SELECT
    date_trunc('hour', ts_utc) AS ts_hour_utc,
    source_name,
    source_key,
    ROUND(AVG(metric_value), 4) AS metric_avg,
    ROUND(MIN(metric_value), 4) AS metric_min,
    ROUND(MAX(metric_value), 4) AS metric_max,
    COUNT(*)::INT AS source_count,
    NOW() AS refreshed_at
FROM enrich.api_timeseries
GROUP BY 1, 2, 3
WITH NO DATA;

CREATE UNIQUE INDEX IF NOT EXISTS api_timeseries_1h_ux
    ON mart.api_timeseries_1h (ts_hour_utc, source_name, source_key);

CREATE SCHEMA IF NOT EXISTS semantic;

CREATE OR REPLACE VIEW semantic.api_timeseries_last_7d AS
SELECT
    ts_hour_utc,
    source_name,
    source_key,
    metric_avg,
    metric_min,
    metric_max,
    source_count,
    refreshed_at
FROM mart.api_timeseries_1h
WHERE ts_hour_utc >= NOW() - INTERVAL '7 days';

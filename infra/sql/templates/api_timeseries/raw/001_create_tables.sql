CREATE SCHEMA IF NOT EXISTS staging;

CREATE TABLE IF NOT EXISTS staging.api_timeseries_raw (
    id BIGSERIAL PRIMARY KEY,
    source_name TEXT NOT NULL,
    source_key TEXT NOT NULL,
    source_time_text TEXT NOT NULL,
    record JSONB NOT NULL,
    ingested_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS api_timeseries_raw_source_key_time_ux
    ON staging.api_timeseries_raw (source_name, source_key, source_time_text);

CREATE INDEX IF NOT EXISTS api_timeseries_raw_time_idx
    ON staging.api_timeseries_raw (source_name, source_time_text);

CREATE INDEX IF NOT EXISTS api_timeseries_raw_ingested_at_brin_idx
    ON staging.api_timeseries_raw USING BRIN (ingested_at);

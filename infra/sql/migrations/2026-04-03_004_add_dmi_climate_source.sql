BEGIN;

CREATE SCHEMA IF NOT EXISTS staging;

CREATE TABLE IF NOT EXISTS staging.dmi_climate_raw (
    id BIGSERIAL PRIMARY KEY,
    municipality_id TEXT NOT NULL,
    municipality_name TEXT NOT NULL,
    parameter_id TEXT NOT NULL,
    time_resolution TEXT NOT NULL,
    source_key TEXT NOT NULL,
    source_time_text TEXT NOT NULL,
    record JSONB NOT NULL,
    ingested_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS dmi_climate_raw_dedupe_ux
    ON staging.dmi_climate_raw (
        municipality_id,
        parameter_id,
        time_resolution,
        source_key,
        source_time_text
    );

CREATE INDEX IF NOT EXISTS dmi_climate_raw_lookup_idx
    ON staging.dmi_climate_raw (municipality_id, parameter_id, time_resolution, source_time_text);

CREATE INDEX IF NOT EXISTS dmi_climate_raw_ingested_at_brin_idx
    ON staging.dmi_climate_raw USING BRIN (ingested_at);

CREATE SCHEMA IF NOT EXISTS enrich;

CREATE OR REPLACE VIEW enrich.dmi_climate_temperature AS
SELECT
    raw.id AS raw_id,
    raw.municipality_id,
    raw.municipality_name,
    raw.parameter_id,
    raw.time_resolution,
    raw.source_key,
    CASE
        WHEN raw.source_time_text LIKE '%Z' OR raw.source_time_text LIKE '%+%'
        THEN raw.source_time_text::TIMESTAMPTZ
        ELSE raw.source_time_text::TIMESTAMP AT TIME ZONE 'UTC'
    END AS ts_from_utc,
    CASE
        WHEN (raw.record -> 'properties' ->> 'to') LIKE '%Z' OR (raw.record -> 'properties' ->> 'to') LIKE '%+%'
        THEN (raw.record -> 'properties' ->> 'to')::TIMESTAMPTZ
        ELSE (raw.record -> 'properties' ->> 'to')::TIMESTAMP AT TIME ZONE 'UTC'
    END AS ts_to_utc,
    (raw.record -> 'properties' ->> 'value')::NUMERIC(8, 2) AS mean_temp_c,
    raw.record -> 'properties' ->> 'qcStatus' AS qc_status,
    raw.record AS payload,
    raw.ingested_at AS enriched_at
FROM staging.dmi_climate_raw AS raw
WHERE raw.parameter_id = 'mean_temp'
  AND raw.time_resolution = 'hour'
  AND raw.source_time_text IS NOT NULL
  AND (raw.record -> 'properties' ->> 'value') IS NOT NULL;

CREATE SCHEMA IF NOT EXISTS mart;

CREATE MATERIALIZED VIEW IF NOT EXISTS mart.dmi_climate_temperature_hourly AS
SELECT
    ts_from_utc,
    ts_to_utc,
    municipality_id,
    municipality_name,
    ROUND(AVG(mean_temp_c), 2) AS mean_temp_c,
    COUNT(*)::INT AS source_count,
    MAX(enriched_at) AS source_max_enriched_at,
    NOW() AS refreshed_at
FROM enrich.dmi_climate_temperature
GROUP BY 1, 2, 3, 4
WITH NO DATA;

CREATE UNIQUE INDEX IF NOT EXISTS dmi_climate_temperature_hourly_ux
    ON mart.dmi_climate_temperature_hourly (ts_from_utc, municipality_id);

CREATE SCHEMA IF NOT EXISTS semantic;

CREATE OR REPLACE VIEW semantic.dmi_climate_temperature_last_7d AS
SELECT
    ts_from_utc,
    ts_to_utc,
    municipality_id,
    municipality_name,
    mean_temp_c,
    source_count,
    source_max_enriched_at,
    refreshed_at
FROM mart.dmi_climate_temperature_hourly
WHERE ts_from_utc >= NOW() - INTERVAL '7 days';

COMMIT;

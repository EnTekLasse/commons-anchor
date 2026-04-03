CREATE SCHEMA IF NOT EXISTS enrich;

CREATE OR REPLACE VIEW enrich.api_timeseries AS
SELECT
    raw.id AS raw_id,
    raw.source_name,
    raw.source_key,
    -- TODO: map and cast the source metric field.
    (raw.record ->> 'value')::NUMERIC(12, 4) AS metric_value,
    CASE
        WHEN raw.source_time_text LIKE '%Z'
        THEN REPLACE(raw.source_time_text, 'Z', '+00:00')::TIMESTAMPTZ
        ELSE raw.source_time_text::TIMESTAMP AT TIME ZONE 'UTC'
    END AS ts_utc,
    raw.record AS payload,
    raw.ingested_at AS enriched_at
FROM staging.api_timeseries_raw AS raw
WHERE raw.source_time_text IS NOT NULL
  AND (raw.record ->> 'value') IS NOT NULL;

CREATE SCHEMA IF NOT EXISTS enrich;

-- First concrete DMI climate enrich view:
-- Roskilde municipality hourly mean temperature from Climate Data API.
-- Keep this source-specific and explicit; other DMI API families should get
-- their own raw/enrich folders rather than sharing a generic weather bucket.
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

CREATE SCHEMA IF NOT EXISTS staging;

-- Raw DMI Climate values are stored source-faithfully as GeoJSON features.
-- This allows later enrich views to decide which municipality/parameter pairs
-- should become typed metrics without losing the original payload.
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

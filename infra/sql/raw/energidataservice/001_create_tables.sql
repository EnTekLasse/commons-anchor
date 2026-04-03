CREATE SCHEMA IF NOT EXISTS staging;

CREATE TABLE IF NOT EXISTS staging.energinet_raw (
    id BIGSERIAL PRIMARY KEY,
    dataset TEXT NOT NULL DEFAULT 'DayAheadPrices',
    price_area TEXT NOT NULL,
    source_time_text TEXT NOT NULL,
    record JSONB NOT NULL,
    ingested_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS energinet_raw_dataset_area_source_time_ux
    ON staging.energinet_raw (dataset, price_area, source_time_text);

CREATE INDEX IF NOT EXISTS energinet_raw_price_area_source_time_idx
    ON staging.energinet_raw (price_area, source_time_text);

CREATE INDEX IF NOT EXISTS energinet_raw_dataset_source_time_idx
    ON staging.energinet_raw (dataset, source_time_text);

-- Cheap append-heavy index for retention jobs and time-window scans.
CREATE INDEX IF NOT EXISTS energinet_raw_ingested_at_brin_idx
    ON staging.energinet_raw USING BRIN (ingested_at);

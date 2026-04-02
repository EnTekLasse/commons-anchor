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

CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS mart;

CREATE TABLE IF NOT EXISTS staging.mqtt_raw (
    id BIGSERIAL PRIMARY KEY,
    topic TEXT NOT NULL,
    payload JSONB NOT NULL,
    source TEXT NOT NULL DEFAULT 'esp32',
    ingested_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS staging.energinet_raw (
    id BIGSERIAL PRIMARY KEY,
    dataset TEXT NOT NULL DEFAULT 'DayAheadPrices',
    area TEXT NOT NULL,
    price_dkk_mwh NUMERIC(12, 4) NOT NULL,
    ts_utc TIMESTAMPTZ NOT NULL,
    payload JSONB NOT NULL,
    ingested_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS energinet_raw_dataset_area_ts_ux
    ON staging.energinet_raw (dataset, area, ts_utc);

CREATE INDEX IF NOT EXISTS energinet_raw_ts_area_idx
    ON staging.energinet_raw (ts_utc, area);

CREATE TABLE IF NOT EXISTS mart.power_price_15min (
    ts_utc TIMESTAMPTZ NOT NULL,
    area TEXT NOT NULL,
    price_dkk_mwh NUMERIC(12, 4) NOT NULL,
    source_count INT NOT NULL,
    refreshed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (ts_utc, area)
);

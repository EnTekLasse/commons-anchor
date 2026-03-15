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
    area TEXT NOT NULL,
    price_dkk_mwh NUMERIC(12, 4) NOT NULL,
    ts_utc TIMESTAMPTZ NOT NULL,
    ingested_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS mart.power_price_hourly (
    ts_utc TIMESTAMPTZ PRIMARY KEY,
    area TEXT NOT NULL,
    avg_price_dkk_mwh NUMERIC(12, 4) NOT NULL,
    source_count INT NOT NULL,
    refreshed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

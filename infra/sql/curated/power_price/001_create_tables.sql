CREATE SCHEMA IF NOT EXISTS mart;

CREATE TABLE IF NOT EXISTS mart.power_price_15min (
    ts_utc TIMESTAMPTZ NOT NULL,
    area TEXT NOT NULL,
    price_dkk_mwh NUMERIC(12, 4) NOT NULL,
    source_count INT NOT NULL,
    refreshed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (ts_utc, area)
);

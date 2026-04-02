CREATE SCHEMA IF NOT EXISTS enrich;

CREATE TABLE IF NOT EXISTS enrich.energinet_price (
    raw_id BIGINT PRIMARY KEY,
    dataset TEXT NOT NULL,
    area TEXT NOT NULL,
    price_dkk_mwh NUMERIC(12, 4) NOT NULL,
    ts_utc TIMESTAMPTZ NOT NULL,
    payload JSONB NOT NULL,
    enriched_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT energinet_price_raw_fk
        FOREIGN KEY (raw_id) REFERENCES staging.energinet_raw (id) ON DELETE CASCADE,
    CONSTRAINT energinet_price_dataset_area_ts_ux
        UNIQUE (dataset, area, ts_utc)
);

CREATE INDEX IF NOT EXISTS energinet_price_ts_area_idx
    ON enrich.energinet_price (ts_utc, area);

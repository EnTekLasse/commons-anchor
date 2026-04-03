CREATE SCHEMA IF NOT EXISTS enrich;

CREATE OR REPLACE VIEW enrich.energinet_price AS
SELECT
    raw.id AS raw_id,
    raw.dataset,
    raw.price_area AS area,
    ROUND(
        (
            CASE raw.dataset
                WHEN 'DayAheadPrices' THEN raw.record ->> 'DayAheadPriceDKK'
                WHEN 'Elspotprices' THEN raw.record ->> 'SpotPriceDKK'
            END
        )::NUMERIC,
        4
    ) AS price_dkk_mwh,
    CASE
        WHEN raw.source_time_text LIKE '%Z'
        THEN REPLACE(
            raw.source_time_text,
            'Z',
            '+00:00'
        )::TIMESTAMPTZ
        ELSE raw.source_time_text::TIMESTAMP AT TIME ZONE 'UTC'
    END AS ts_utc,
    raw.record AS payload,
    raw.ingested_at AS enriched_at
FROM staging.energinet_raw AS raw
WHERE raw.price_area IS NOT NULL
  AND raw.source_time_text IS NOT NULL
  AND (
      CASE raw.dataset
          WHEN 'DayAheadPrices' THEN raw.record ->> 'DayAheadPriceDKK'
          WHEN 'Elspotprices' THEN raw.record ->> 'SpotPriceDKK'
      END
  ) IS NOT NULL;

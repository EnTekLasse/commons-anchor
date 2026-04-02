BEGIN;

TRUNCATE TABLE enrich.energinet_price;

INSERT INTO enrich.energinet_price (
    raw_id,
    dataset,
    area,
    price_dkk_mwh,
    ts_utc,
    payload,
    enriched_at
)
SELECT
    raw.id,
    raw.dataset,
    raw.price_area,
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
        WHEN COALESCE(
            CASE raw.dataset
                WHEN 'DayAheadPrices' THEN raw.record ->> 'TimeUTC'
                WHEN 'Elspotprices' THEN raw.record ->> 'HourUTC'
            END,
            ''
        ) LIKE '%Z'
        THEN REPLACE(
            CASE raw.dataset
                WHEN 'DayAheadPrices' THEN raw.record ->> 'TimeUTC'
                WHEN 'Elspotprices' THEN raw.record ->> 'HourUTC'
            END,
            'Z',
            '+00:00'
        )::TIMESTAMPTZ
        ELSE (
            CASE raw.dataset
                WHEN 'DayAheadPrices' THEN raw.record ->> 'TimeUTC'
                WHEN 'Elspotprices' THEN raw.record ->> 'HourUTC'
            END
        )::TIMESTAMP AT TIME ZONE 'UTC'
    END AS ts_utc,
    raw.record AS payload,
    NOW() AS enriched_at
FROM staging.energinet_raw AS raw
WHERE raw.price_area IS NOT NULL
  AND raw.source_time_text IS NOT NULL
  AND (
      CASE raw.dataset
          WHEN 'DayAheadPrices' THEN raw.record ->> 'DayAheadPriceDKK'
          WHEN 'Elspotprices' THEN raw.record ->> 'SpotPriceDKK'
      END
  ) IS NOT NULL;

COMMIT;

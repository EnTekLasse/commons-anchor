# Semantic Model Blueprint: Power Price

This document defines a practical semantic layer blueprint on top of curated star schemas.
In this project, the semantic layer is the serving layer for BI consumption.

It is designed for the current Commons Anchor scope:

- Source: Energi Data Service (DayAheadPrices / Elspotprices)
- Grain: 15-minute baseline for public price data
- Consumers: Grafana and Metabase

## Purpose

- Create one shared business definition for metrics used in dashboards and analysis.
- Avoid KPI drift across tools by defining logic once.
- Keep semantic logic close to SQL models, but versioned and testable.

## Proposed Semantic Layer Structure

Logical schemas:

- `curated`: star schemas (facts + dimensions)
- `semantic`: stable serving views for BI and analytics users

Recommended objects:

1. `curated.fact_power_price_15min`
2. `curated.dim_time_15min`
3. `curated.dim_area`
4. `semantic.v_power_price_base`
5. `semantic.v_power_price_daily`
6. `semantic.v_power_price_quality`

## Star Schema Baseline

### Fact

`curated.fact_power_price_15min`

- Keys: `time_key`, `area_key`
- Measures: `price_dkk_mwh`, `source_count`
- Metadata: `dataset_name`, `refreshed_at`

### Dimensions

`curated.dim_time_15min`

- `time_key` (surrogate or deterministic key)
- `ts_utc`
- `calendar_date`
- `hour_of_day`
- `quarter_hour_slot`
- `is_weekend`
- `dk_local_hour`

`curated.dim_area`

- `area_key`
- `area_code` (DK1, DK2)
- `area_name`
- `country_code`

## Semantic Entities

### Entity: power_price

Base semantic view: `semantic.v_power_price_base`

Dimensions:

- `ts_utc`
- `calendar_date`
- `area_code`
- `dataset_name`

Measures:

- `price_dkk_mwh` (base measure)
- `source_count`

Default filters:

- dataset default: DayAheadPrices
- time default: last 48 hours

## Canonical Metrics (v1)

1. `avg_price_dkk_mwh`
   - Definition: AVG(price_dkk_mwh)
   - Grain support: 15m, hourly, daily

2. `min_price_dkk_mwh`
   - Definition: MIN(price_dkk_mwh)

3. `max_price_dkk_mwh`
   - Definition: MAX(price_dkk_mwh)

4. `spread_price_dkk_mwh`
   - Definition: MAX(price_dkk_mwh) - MIN(price_dkk_mwh)

5. `row_count`
   - Definition: COUNT(*)

6. `coverage_ratio`
   - Definition: COUNT(actual_rows) / COUNT(expected_rows)
   - Note: expected rows for 15-minute grain can be derived from selected time range x selected areas.

## Time Semantics

- Storage timezone: UTC
- Display timezone: user/browser (or Europe/Copenhagen for DK reporting)
- Calendar aggregation rules:
  - daily rollup by local calendar date for business reporting
  - keep UTC-based joins in core fact/dim models

## Quality Semantics

`semantic.v_power_price_quality` should expose:

- `missing_intervals`
- `null_price_rows`
- `duplicate_key_rows` (should be 0 after model constraints)
- `freshness_lag_minutes`

This allows dashboards to show data quality alongside business values.

## Python-Driven Semantic Metadata (Optional)

Semantic models can be managed in Python safely if metadata-first:

- Store metric definitions in YAML/JSON (name, SQL expression, dimensions, defaults).
- Use a small Python build script to generate SQL views in `semantic` schema.
- Validate generated SQL with existing SQL syntax checks and pytest assertions.

Recommended pattern:

1. Metadata file (`docs` or `infra/sql/semantic/specs`)
2. Python generator (`scripts/generate_semantic_views.py`)
3. Generated SQL (`infra/sql/semantic/*.sql`)
4. CI checks for consistency and query validity

## Rollout Plan

1. Create `curated.dim_time_15min` and `curated.dim_area`.
2. Refactor current `mart.power_price_15min` logic into `curated.fact_power_price_15min`.
3. Create `semantic.v_power_price_base` as a stable join of fact + dimensions.
4. Add `semantic.v_power_price_daily` with canonical daily aggregations.
5. Point Grafana/Metabase to semantic views instead of raw mart table.

## Non-Goals (Current Phase)

- Full enterprise semantic layer tooling migration.
- Complex row-level security in semantic layer.
- Cross-domain conformed dimensions beyond power price scope.
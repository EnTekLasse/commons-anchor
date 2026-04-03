# API Time-Series Template Guide

This guide shows a generic, repeatable path from API ingest to serving views.

## Template files

Use these templates as your starting point:

- Ingest script template: `scripts/ingest/api_timeseries_ingest_template.py`
- Raw DDL template: `infra/sql/templates/api_timeseries/raw/001_create_tables.sql`
- Enrich view template: `infra/sql/templates/api_timeseries/enrich/001_create_views.sql`
- Curated materialized view template: `infra/sql/templates/api_timeseries/curated/001_create_materialized_views.sql`
- Curated refresh template: `infra/sql/templates/api_timeseries/curated/010_refresh.sql`
- Serving view template: `infra/sql/templates/api_timeseries/serving/001_create_views.sql`

## End-to-end flow

1. Ingest pulls API records and upserts source-faithful rows into `staging`.
2. Enrich exposes typed and normalized columns as SQL views.
3. Curated builds analytics-friendly hourly/daily aggregates in materialized views.
4. Refresh updates curated materialized views after ingest.
5. Serving exposes stable semantic views for dashboards and consumers.

## Naming convention for DMI sources

Use the provider name and API family together in folder names, table names, and script names.

Recommended source identifiers:

- `dmi_climate`
- `dmi_meteorological_observations`
- `dmi_oceanographic_observations`
- `dmi_lightning`
- `dmi_radar`
- `dmi_forecast_stac`
- `dmi_forecast_edr`

Why this convention works:

- `dmi` groups related public data under one provider.
- The API family stays explicit, so multiple DMI sources do not collapse into one vague `weather` folder.
- Future curated models can combine sources without hiding lineage.

Example for Climate Data API municipality temperature:

- ingest script: `scripts/ingest/dmi_climate_ingest.py`
- raw folder: `infra/sql/raw/dmi_climate/`
- enrich folder: `infra/sql/enrich/dmi_climate/`
- curated folder: `infra/sql/curated/dmi_climate_temperature/`
- serving folder: `infra/sql/serving/dmi_climate_temperature_overview/`

## Step-by-step setup for a new source

Example source name used below: `dmi_climate`.

1. Copy template files into source-specific folders:
   - `infra/sql/raw/dmi_climate/001_create_tables.sql`
   - `infra/sql/enrich/dmi_climate/001_create_views.sql`
   - `infra/sql/curated/dmi_climate_temperature/001_create_materialized_views.sql`
   - `infra/sql/curated/dmi_climate_temperature/010_refresh.sql`
   - `infra/sql/serving/dmi_climate_temperature_overview/001_create_views.sql`

2. Add bootstrap includes in `infra/sql/001_bootstrap.sql` (dependency order):
   - raw weather create tables
   - enrich weather create views
   - curated weather create materialized views
   - serving weather create views

3. Add curated refresh include in `infra/sql/020_refresh_all.sql`:
   - `\i /sql/curated/dmi_climate_temperature/010_refresh.sql`

4. Copy the ingest template script to:
   - `scripts/ingest/dmi_climate_ingest.py`

5. In `dmi_climate_ingest.py`, customize:
   - API URL and auth headers
   - request params and pagination
   - record key mapping (`source_key`, `source_time_text`)
   - value mapping to raw `record` payload
   - target raw table name

6. In raw SQL, decide dedupe key:
   - Usually `(source_name, source_key, source_time_text)`

7. In enrich SQL, map/cast fields clearly:
   - Always convert timestamps to UTC (`ts_utc`)
   - Cast numerics with explicit precision
   - Keep `payload` for traceability

8. In curated SQL, build only required aggregates first:
   - Start with hourly granularity
   - Add daily or rolling windows when needed

9. In serving SQL, expose stable columns only:
   - Avoid leaking source-specific JSON details
   - Keep names consistent for BI tools

10. Validate with the short pipeline wrappers:
   - Windows: `powershell -ExecutionPolicy Bypass -File scripts/ingest/run_pipeline.ps1`
   - Linux: `./scripts/ingest/run_pipeline.sh`
   - Optional DMI Climate run: `powershell -ExecutionPolicy Bypass -File scripts/ingest/run_pipeline.ps1 -IncludeDmiClimate`
   - Optional DMI Climate run: `INCLUDE_DMI_CLIMATE=1 ./scripts/ingest/run_pipeline.sh`
   - The optional DMI step uses `--since-latest` to make repeat runs incremental.

## Generic API example contract

Assume upstream API record shape:

```json
{
  "station_id": "COPENHAGEN_01",
  "timestamp": "2026-04-03T12:00:00Z",
  "temperature_c": 9.6,
  "humidity_pct": 72.4
}
```

Suggested mapping:

- `source_name`: `dmi_climate`
- `source_key`: `station_id`
- `source_time_text`: `timestamp`
- `record`: full JSON payload

In enrich view:

- `metric_value`: use `temperature_c` (or split into multiple enrich views)
- `ts_utc`: parsed from `source_time_text`

In curated view:

- `metric_avg`: hourly average temperature
- `metric_min`: hourly min temperature
- `metric_max`: hourly max temperature

In serving view:

- expose last 7 days for dashboard queries

## Operational recommendations

- Keep raw append-friendly and source-faithful.
- Keep enrich purely declarative (views, no refresh scripts).
- Keep curated refresh explicit and ordered in `020_refresh_all.sql`.
- Use first-refresh-safe logic (non-concurrent if mat view is not populated).
- Add one smoke test per new source: raw count, curated count, serving count.

## Definition of done for a new API source

- Ingest script can run idempotently.
- Raw table has stable dedupe key and JSON payload.
- Enrich view exposes typed columns and UTC timestamp.
- Curated materialized view refreshes successfully on first and subsequent runs.
- Serving view returns data with stable column names.
- Bootstrap and refresh include files are updated.
- Docs for source-specific field mapping are added.

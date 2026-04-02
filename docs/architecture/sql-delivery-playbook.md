# SQL Delivery Playbook

This guide describes how SQL work should be added and changed in Commons Anchor.

## Core Rules

- Raw is source-faithful.
- Enrich is where typing, cleanup, renaming, and business-safe standardization begin.
- Curated is where business-facing marts and star schemas are built.
- Serving is where stable views for Grafana, Metabase, and APIs are published.
- `001_bootstrap.sql` is only for fresh database initialization.
- `020_refresh_all.sql` is only for rebuildable layers such as Enrich and Curated.
- Existing databases are changed through migrations under `infra/sql/migrations`, not by hoping bootstrap files will be re-run.

## SQL Layout

```text
infra/sql/
  001_bootstrap.sql
  020_refresh_all.sql
  migrations/
  raw/
    <source>/
      001_create_tables.sql
  enrich/
    <source>/
      001_create_tables.sql
      010_refresh.sql
  curated/
    <star_schema>/
      001_create_tables.sql
      010_refresh.sql
  serving/
    <usecase>/
      001_create_views.sql
```

Naming rules:

- Use one folder per source, star schema, or serving use case.
- Reuse the same filenames inside those folders.
- Use `001_...` for create/bootstrap definitions.
- Use `010_refresh.sql` for rerunnable rebuild logic.
- Keep folders aligned with ingest scripts and business models.

## Add a New Source

Example: add a weather API source.

1. Add the ingest script under `scripts/ingest/weather_ingest.py`.
2. Add raw DDL under `infra/sql/raw/weather/001_create_tables.sql`.
3. Make the ingest script write source-faithful rows only.
4. Add enrich DDL under `infra/sql/enrich/weather/001_create_tables.sql`.
5. Add enrich transform logic under `infra/sql/enrich/weather/010_refresh.sql`.
6. If the source feeds an existing mart, update that curated refresh file.
7. If the source needs a new mart, create `infra/sql/curated/<star_schema>/001_create_tables.sql` and `010_refresh.sql`.
8. Add the new create scripts to `infra/sql/001_bootstrap.sql` in dependency order.
9. Add the new refresh script to `infra/sql/020_refresh_all.sql` in dependency order.
10. Add or update tests for the ingest script and smoke checks for raw/enrich data presence.

Definition of done for a new source:

- Raw rows land with source fields preserved.
- Enrich rows expose typed columns with clear names.
- Downstream marts still rebuild cleanly.
- Bootstrap works on an empty database.
- Refresh works on an existing populated database.

## Change an Enrich Transformation Without Resetting the Database

There are two types of change.

### A. Logic-only change

Example: rename a derived expression in SQL logic or multiply a numeric value by 2.

Use this path when the table shape does not change.

1. Edit the relevant `infra/sql/enrich/<source>/010_refresh.sql`.
2. If the output meaning changes, update downstream curated or serving SQL.
3. Run the refresh flow.
4. Validate the enriched rows and the downstream mart rows.

This kind of change does not need a migration.

### B. Schema change

Example: rename an enrich column from `price_dkk_mwh` to `price_dkk_per_mwh_adjusted`.

Use this path when table structure changes.

1. Add a migration file under `infra/sql/migrations/`.
2. Apply the migration to the target database.
3. Update `infra/sql/enrich/<source>/001_create_tables.sql` so fresh bootstrap matches the new schema.
4. Update `infra/sql/enrich/<source>/010_refresh.sql`.
5. Update downstream curated and serving SQL.
6. Run the refresh flow.
7. Validate the result.

Example migration:

```sql
ALTER TABLE enrich.energinet_price
RENAME COLUMN price_dkk_mwh TO price_dkk_mwh_adjusted;
```

Example logic change after that:

```sql
ROUND((raw.record ->> 'DayAheadPriceDKK')::NUMERIC * 2, 4) AS price_dkk_mwh_adjusted
```

## Refresh Workflow

For existing databases, use the explicit refresh runner:

```powershell
docker compose --profile jobs run --rm power-price-transform
```

Today this job runs `infra/sql/020_refresh_all.sql`, which in turn includes refresh files in dependency order.

Keep this ordering discipline:

1. Enrich refreshes first.
2. Curated refreshes second.
3. Serving refreshes only if they are materialized or otherwise rebuildable.

## Bootstrap Workflow

For a clean database bootstrap:

```powershell
docker compose down -v
docker compose up -d postgres
```

The Postgres container reads `infra/sql/001_bootstrap.sql`, which includes all create scripts in dependency order.

## Safe Lenovo Rollout

When deploying SQL changes to Lenovo without reset:

1. Commit and push from laptop.
2. Pull on Lenovo.
3. Review changed SQL files.
4. If schema changed, apply migration first.
5. Run refresh job.
6. Check raw, enrich, and curated row samples.
7. Check Grafana or Metabase queries that depend on the changed fields.

## Review Checklist

Before merging a SQL change, verify:

- Is Raw still source-faithful?
- Does the new SQL belong in Raw, Enrich, Curated, or Serving?
- Is this a logic-only change or a schema change?
- If schema changed, is there a migration?
- Did `001_bootstrap.sql` stay in sync with create files?
- Did `020_refresh_all.sql` stay in sync with refresh files?
- Did downstream marts or views need updates?

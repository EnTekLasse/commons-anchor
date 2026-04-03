# SQL Delivery Playbook

This guide describes how SQL work should be added and changed in Commons Anchor.

## Core Rules

- Raw is source-faithful.
- Enrich is where typing, cleanup, renaming, and business-safe standardization begin, implemented as views.
- Curated is where business-facing marts and star schemas are built, implemented as materialized views.
- Serving is where stable views for Grafana, Metabase, and APIs are published.
- `001_bootstrap.sql` is only for fresh database initialization.
- `020_refresh_all.sql` is only for refreshable materialized layers (currently Curated).
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
      001_create_views.sql
  curated/
    <star_schema>/
      001_create_materialized_views.sql
      010_refresh.sql
  serving/
    <usecase>/
      001_create_views.sql
```

Naming rules:

- Use one folder per source, star schema, or serving use case.
- Reuse the same filenames inside those folders.
- Use `001_create_tables.sql` for raw layer table DDL.
- Use `001_create_views.sql` for enrich or serving view DDL.
- Use `001_create_materialized_views.sql` for curated materialized views.
- Use `010_refresh.sql` for rerunnable refresh logic on materialized views.
- Keep folders aligned with ingest scripts and business models.

## Add a New Source

Example: add a weather API source.

If you want a ready-to-copy template set (ingest + raw/enrich/curated/serving), start with [docs/architecture/api-timeseries-ingest-template-guide.md](api-timeseries-ingest-template-guide.md).

1. Add the ingest script under `scripts/ingest/weather_ingest.py`.
2. Add raw DDL under `infra/sql/raw/weather/001_create_tables.sql`.
3. Make the ingest script write source-faithful rows only.
4. Add enrich DDL under `infra/sql/enrich/weather/001_create_views.sql`.
5. Keep enrich logic declarative in the view definition (no enrich refresh file).
6. If the source feeds an existing mart, update that curated refresh file.
7. If the source needs a new mart, create `infra/sql/curated/<star_schema>/001_create_materialized_views.sql` and `010_refresh.sql`.
8. Add the new create scripts to `infra/sql/001_bootstrap.sql` in dependency order.
9. Add the new curated refresh script to `infra/sql/020_refresh_all.sql` in dependency order.
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

Example: change a derived expression in a view or adjust a numeric conversion.

Use this path when the view output contract does not break downstream dependencies.

1. Edit the relevant `infra/sql/enrich/<source>/001_create_views.sql`.
2. If the output meaning changes, update downstream curated or serving SQL.
3. Run the curated refresh flow.
4. Validate the enriched view rows and downstream mart rows.

This kind of change does not need a migration.

### B. Schema change

Example: rename an exposed enrich view column from `price_dkk_mwh` to `price_dkk_mwh_adjusted`.

Use this path when SQL interface changes impact downstream objects.

1. Add a migration file under `infra/sql/migrations/`.
2. Apply the migration to the target database.
3. Update `infra/sql/enrich/<source>/001_create_views.sql` so fresh bootstrap matches the new interface.
4. Update curated and serving objects that select the renamed field.
5. Update downstream curated and serving SQL.
6. Run the refresh flow.
7. Validate the result.

Example migration:

```sql
CREATE OR REPLACE VIEW enrich.energinet_price AS
SELECT
  ...,
  ROUND((raw.record ->> 'DayAheadPriceDKK')::NUMERIC * 2, 4) AS price_dkk_mwh_adjusted,
  ...
FROM staging.energinet_raw AS raw;
```

## Refresh Workflow

For existing databases, use the explicit refresh runner:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/ingest/run_pipeline.ps1
```

Linux equivalent:

```bash
./scripts/ingest/run_pipeline.sh
```

For container-only refresh (without ingest), use:

```powershell
docker compose --profile jobs run --rm power-price-transform
```

This job runs `infra/sql/020_refresh_all.sql`, which includes curated refresh files in dependency order.

Keep this ordering discipline:

1. Ingest writes raw data.
2. Enrich views expose transformed rows automatically.
3. Curated materialized views refresh after ingest.
4. Serving views read curated data immediately after refresh.

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

## PowerShell + SSH Quoting Pitfalls

When running long `ssh ... "..."` commands from PowerShell, local parsing can break arguments before they reach the remote shell.

Typical symptom:

- `* : The term '*' is not recognized ...`

Why it happens:

- PowerShell parses native command arguments first.
- Nested escaped quotes plus semicolon chains can cause parts of SQL (for example `COUNT(*)`) to be interpreted locally instead of remotely.

This behavior is consistent with Microsoft docs for `about_Parsing` and `about_Quoting_Rules`.

### Preferred pattern: split into multiple SSH calls

Use short, explicit calls instead of one huge chained command.

```powershell
ssh lenovo-wg "cd ~/serverprojekt/commons-anchor; docker compose --profile jobs run --rm power-price-transform"
ssh lenovo-wg "cd ~/serverprojekt/commons-anchor; docker compose exec -T postgres psql -U dw_admin -d dw -c 'SELECT COUNT(*) AS raw_energinet_rows FROM staging.energinet_raw;'"
ssh lenovo-wg "cd ~/serverprojekt/commons-anchor; docker compose exec -T postgres psql -U dw_admin -d dw -c 'SELECT COUNT(*) AS enrich_energinet_rows FROM enrich.energinet_price;'"
ssh lenovo-wg "cd ~/serverprojekt/commons-anchor; docker compose exec -T postgres psql -U dw_admin -d dw -c 'SELECT COUNT(*) AS mart_rows FROM mart.power_price_15min;'"
```

This is the most robust and easiest to debug.

### Preferred pattern: send a script over SSH stdin

For longer sequences, send a script to remote `bash`.

```powershell
@'
set -euo pipefail
cd ~/serverprojekt/commons-anchor
docker compose --profile jobs run --rm energidata-ingest
docker compose --profile jobs run --rm power-price-transform
docker compose exec -T postgres psql -U dw_admin -d dw -c "SELECT COUNT(*) AS raw_energinet_rows FROM staging.energinet_raw;"
docker compose exec -T postgres psql -U dw_admin -d dw -c "SELECT COUNT(*) AS enrich_energinet_rows FROM enrich.energinet_price;"
docker compose exec -T postgres psql -U dw_admin -d dw -c "SELECT COUNT(*) AS mart_rows FROM mart.power_price_15min;"
'@ | ssh lenovo-wg 'bash -s'
```

This avoids most nested-quote edge cases.

### Optional workaround: stop-parsing token

PowerShell supports `--%` to stop further parsing for native commands.

```powershell
ssh --% lenovo-wg "cd ~/serverprojekt/commons-anchor; docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
```

Use this only when needed. The split-command or stdin-script patterns are generally clearer.

## Review Checklist

Before merging a SQL change, verify:

- Is Raw still source-faithful?
- Does the new SQL belong in Raw, Enrich, Curated, or Serving?
- Is this a logic-only change or a schema change?
- If schema changed, is there a migration?
- Did `001_bootstrap.sql` stay in sync with create files?
- Did `020_refresh_all.sql` stay in sync with refresh files?
- Did downstream marts or views need updates?
- Does the change preserve first-run behavior for unpopulated materialized views?

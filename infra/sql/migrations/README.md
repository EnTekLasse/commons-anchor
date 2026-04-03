# SQL Migrations

Init scripts under `infra/sql` are for fresh database bootstrap only.

When an existing database must be changed without reset:

1. Add a dated migration file in this folder.
2. Apply the migration manually on the target database.
3. Update the matching bootstrap file (`001_create_tables.sql`, `001_create_views.sql`, or `001_create_materialized_views.sql`) so fresh bootstrap matches current reality.

Suggested file naming:

- `2026-04-02_001_rename_enrich_column.sql`
- `2026-04-02_002_add_mqtt_enrich_table.sql`

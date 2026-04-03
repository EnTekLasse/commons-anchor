# Data Warehouse Refactoring: Views Instead of Tables

**Date:** 2026-04-03  
**Status:** Implementation guide  
**Migration Pattern:** Incremental (no downtime, no data loss)

---

## What's Changing

### From:
```sql
-- Old pattern (still in place for enriched layer)
TRUNCATE TABLE mart.power_price_15min;
INSERT INTO mart.power_price_15min SELECT ...;
```

### To:
```sql
-- New pattern (materialized views)
REFRESH MATERIALIZED VIEW CONCURRENTLY mart.power_price_15min;
```

---

## Why This Matters

| Aspect | Before | After |
|--------|--------|-------|
| **Data flow type** | ETL (extract/transform load) | ELT (extract/load/transform) |
| **Schema evolution** | Coupled to data flow | Decoupled |
| **Refresh** | Implicit in migrations | Explicit and controllable |
| **Logic location** | Split between SQL + migrations | All in SQL |
| **Backfilling** | Manual data manipulation | Automatic (next refresh) |
| **Query performance** | Depends on INSERT strategy | Configurable with indexes |

---

## Implementation Steps

### Step 1: Apply Migration

This converts `mart.power_price_15min` from TABLE to MATERIALIZED VIEW:

```bash
cd commons-anchor

# Apply the migration
docker exec -e PGPASSWORD=$(cat infra/secrets/postgres_password.secret) \
  ca-postgres psql -U dw_admin -d dw \
  -f /docker-entrypoint-initdb.d/migrations/2026-04-03_003_convert_power_price_to_materialized_view.sql
```

**What this does:**
- Backs up current data to `mart.power_price_15min_backup`
- Drops the old TABLE
- Creates MATERIALIZED VIEW with identical query logic
- Creates indexes for performance

### Step 2: Update `010_refresh.sql`

Already done! The file now uses:
```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY mart.power_price_15min;
```

Instead of:
```sql
TRUNCATE TABLE ...; INSERT INTO ...;
```

### Step 3: Test the Refresh

```bash
# Option A: Via Docker
docker exec -e PGPASSWORD=$(cat infra/secrets/postgres_password.secret) \
  ca-postgres psql -U dw_admin -d dw \
  -f /docker-entrypoint-initdb.d/curated/power_price/010_refresh.sql

# Option B: Via Python script (after migration)
python scripts/ingest/refresh_curated.py --view power_price --verbose

# Option C: Daily wrapper (ingest + refresh)
./scripts/ingest/run_pipeline.sh

# Option C2: Daily wrapper with optional DMI climate ingest
INCLUDE_DMI_CLIMATE=1 ./scripts/ingest/run_pipeline.sh

# Option D: Via psql
psql -h localhost -U dw_admin -d dw \
  -c "REFRESH MATERIALIZED VIEW CONCURRENTLY mart.power_price_15min;"
```

---

## Scheduling Refresh

### Option 1: After Raw Data Loads (CI/CD)

```yaml
# Example: GitHub Actions or similar
- name: Refresh serving layer
  run: |
    export PGPASSWORD=$(cat infra/secrets/postgres_password.secret)
    psql -h db.example.com -U dw_admin -d dw \
      -c "REFRESH MATERIALIZED VIEW CONCURRENTLY mart.power_price_15min;"
```

### Option 2: Daily Cron

```bash
# Linux cron (add to crontab -e)
0 1 * * * cd /home/app/commons-anchor && .venv/bin/python scripts/ingest/refresh_curated.py --view all --host 127.0.0.1
```

### Option 3: Manual

```bash
# When you need to update serving layer
python scripts/ingest/refresh_curated.py --view power_price --verbose
```

---

## Backward Compatibility

### Existing Queries Continue to Work

```sql
-- Before migration: queried a TABLE
SELECT * FROM mart.power_price_15min WHERE ts_utc > now() - interval '1 day';

-- After migration: queries a MATERIALIZED VIEW (same interface)
SELECT * FROM mart.power_price_15min WHERE ts_utc > now() - interval '1 day';

-- No application code changes needed ✓
```

### Performance Notes

- **First refresh:** May take longer (full rebuild)
- **Subsequent refreshes:** CONCURRENTLY flag allows reads during refresh
- **Indexes:** Still available and used by query planner
- **Size:** Same as before (materialized view = materialized data)

---

## Monitoring & Troubleshooting

### Check View Status

```sql
-- What views exist?
SELECT schemaname, matviewname 
FROM pg_matviews 
WHERE schemaname = 'mart';

-- When was last refresh?
SELECT * FROM mart.power_price_15min 
ORDER BY refreshed_at DESC 
LIMIT 1;

-- How many rows?
SELECT COUNT(*) FROM mart.power_price_15min;
```

### If Refresh Fails

```sql
-- Check for locks
SELECT * FROM pg_locks WHERE relation = 'mart.power_price_15min'::regclass;

-- Try without CONCURRENTLY (will lock reads)
REFRESH MATERIALIZED VIEW mart.power_price_15min;

-- If that fails, check view definition
\d+ mart.power_price_15min
```

### Rollback

If you need to revert:

```sql
-- Restore from backup
DROP MATERIALIZED VIEW mart.power_price_15min;

CREATE TABLE mart.power_price_15min AS
SELECT * FROM mart.power_price_15min_backup;

-- Recreate indexes
CREATE INDEX power_price_15min_ts_area_idx
  ON mart.power_price_15min (ts_utc, area);
```

---

## Next Steps

1. ✅ **Test this migration** in dev/staging
2. ⏳ **Apply to `enrich.energinet_price`** (convert TABLE → VIEW)
3. ⏳ **Apply to other enrich tables** as confidence grows
4. ⏳ **Consolidate refresh logic** into Python orchestration
5. ⏳ **Consider Flyway** for version control (when ready)

---

## Files Changed

- `infra/sql/curated/power_price/010_refresh.sql` - Now uses REFRESH instead of INSERT
- `infra/sql/020_refresh_all.sql` - Points to new enrich-as-view architecture
- `infra/sql/migrations/2026-04-03_003_convert_power_price_to_materialized_view.sql` - Migration script
- `scripts/ingest/refresh_curated.py` - Python CLI for curated refresh orchestration
- `scripts/ingest/run_pipeline.ps1` and `scripts/ingest/run_pipeline.sh` - Daily wrappers

---

## Questions?

**Q: Will queries be slower?**  
A: No. Materialized views = pre-computed data, just like tables. Performance is identical.

**Q: How often should I refresh?**  
A: Depends on your use case. Daily is common. Hourly for dashboards. Manual when logic changes.

**Q: Can I still use TRUNCATE + INSERT?**  
A: Technically yes, but why? REFRESH is simpler and doesn't hold locks.

**Q: What about views that depend on this one?**  
A: They automatically see updated data on next read. Refresh cascades naturally.

---

## Architecture Summary

```
raw.energinet_raw (TABLE)
         ↓
enrich.energinet_price (VIEW)
         ↓
mart.power_price_15min (MATERIALIZED VIEW)
         ↓
semantic.power_price_overview (VIEW)
```

**Data layers:**
- **raw**: persistent, append-only
- **enrich**: declarative transformation (VIEW)
- **mart**: pre-computed aggregate (MATERIALIZED VIEW)
- **semantic**: business-friendly interface (VIEW)

**Refresh strategy:**
- raw: implicit (data ingest)
- enrich: automatic (VIEW follows raw)
- mart: explicit REFRESH (scheduled or triggered)
- semantic: automatic (VIEW follows mart)

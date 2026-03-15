# Environment Validation Gates

This document defines the minimum professional validation flow before deploying on Lenovo Tiny.

## Gate model
- V1 Local smoke test gate
- V2 Data integrity gate
- V3 Backup and restore drill
- V4 Cross-machine parity test

Lenovo Tiny deployment starts only after V1-V4 pass on laptop.

## V1 Local smoke test gate
Pass criteria:
- Docker stack starts from cold state without manual fixes.
- Service health checks pass for PostgreSQL and dashboards.
- API and MQTT ingestion workers can start and run.
- Core endpoints are reachable (Grafana, Metabase, Postgres, MQTT).

Evidence:
- Command log and timestamped screenshots.

## V2 Data integrity gate
Pass criteria:
- Raw ingestion rows are present for both API and MQTT paths.
- Enriched transformations run without errors.
- Curated outputs are produced and queryable.
- Row-count and freshness checks pass for at least one full cycle.

Evidence:
- SQL query results for row counts and freshness.

## V3 Backup and restore drill
Pass criteria:
- Logical backup of PostgreSQL is created successfully.
- Restore into clean instance succeeds.
- Restored curated tables match expected row counts.

Evidence:
- Backup artifact metadata and restore verification queries.

## V4 Cross-machine parity test
Pass criteria:
- Same compose stack runs on second machine with environment-specific .env.
- Same smoke tests pass on both machines.
- No critical config drift between laptop and target host setup.

Evidence:
- Two run reports (laptop and target machine) using same checklist.

## Go/No-Go for Lenovo Tiny deployment
Go:
- All V1-V4 gates passed and evidence recorded.

No-Go:
- Any failed gate, unresolved health check, or failed restore validation.

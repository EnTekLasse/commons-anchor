# Product Backlog (Story Points)

## Scoring model
- 1: Tiny (1-2 hours)
- 2: Small (half day)
- 3: Medium (1 day)
- 5: Large (2-3 days)
- 8: XL (up to 1 week)

## Epic A - Foundation and repo hygiene
- A1: Add branching strategy and PR template (3)
- A2: Add lint/format/check pipeline in CI (5)
- A3: Add ADR template and first architecture decisions (2)

## Epic B - Data platform core
- B1: Stand up Postgres layered model (Raw/Enriched/Curated) (3)
- B2: Build first ETL script for Energinet API into Raw (5)
- B3: Create first Curated transformation for hourly prices (3)
- B4: Add db migration flow (Alembic or dbmate) (5)

## Epic C - IoT ingestion (ESP32 over MQTT)
- C1: Define MQTT topic naming convention and payload schema (3)
- C2: Build MQTT to Postgres ingestion worker (8)
- C3: Add replay/dead-letter strategy for malformed payloads (5)

## Epic D - Observability and dashboards
- D1: Provision Grafana datasource + first dashboard (5)
- D2: Build Metabase questions for project demo storyline (3)
- D3: Add data quality dashboard (freshness + row count) (5)

## Epic E - Security and remote operations
- E1: WireGuard server baseline (docker or host-level) (8)
- E2: SSH hardening + key-only + fail2ban (5)
- E3: Secrets strategy (dotenv -> vault/sops) (5)

## Epic F - Production host (Lenovo Tiny Ubuntu)
- F1: Install Ubuntu Server and baseline hardening (5)
- F2: Install Docker and compose plugin, rootless or least-privilege model (3)
- F3: Deploy stack with systemd and backup/restore jobs (8)

## Epic H - Environment validation gates (pre-Lenovo)
- H1: V1 local smoke test gate (3)
- H2: V2 data integrity gate (3)
- H3: V3 backup and restore drill (5)
- H4: V4 cross-machine parity test (5)

## Epic G - Project polish
- G1: Record architecture walkthrough and demo script (3)
- G2: Add screenshots and operational runbook (3)
- G3: Add benchmark and cost profile section (2)

## Candidate sprint order
- Sprint 1 (13 SP): A3, B1, B2, D2
- Sprint 2 (16 SP): B3, C1, C2
- Sprint 3 (16 SP): D1, E2, H1, H2
- Sprint 4 (18 SP): E1, H3, H4, F2
- Sprint 5 (13 SP): F1, F3
- Sprint 6 (8 SP): G1, G2, G3

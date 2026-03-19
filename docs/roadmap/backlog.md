# Product Backlog (Story Points)

Source of truth for visual planning:
- `docs/architecture/diagram-model.json` (`delivery.workItems`)

Backlog policy:
- Items in this document must map 1:1 to IDs/titles/story points in `diagram-model.json`.
- New ideas that are not yet promoted to kanban/tech-tree go to the parking lot section.

## Scoring model
- 1: Tiny (1-2 hours)
- 2: Small (half day)
- 3: Medium (1 day)
- 5: Large (2-3 days)
- 8: XL (up to 1 week)

## Synchronized Work Items (1:1 with diagram-model)

## Foundation
- A1: Docker baseline (5)
- A2: Postgres schemas (3)

## Ingestion and Modeling
- B1: API ingestion (5)
- B2: MQTT ingestion (8)
- C1: Enriched standardization (3)
- C2: Curated star schema build (5)
- C3: Semantic serving views (3)

## BI and Operations
- D1: Grafana dashboards (5)
- D2: Metabase showcase (3)
- E1: Ops monitoring (5)
- F1: Project demo (3)

## Validation Gates
- V1: Local smoke test gate (3)
- V2: Data integrity gate (3)
- V3: Backup and restore drill (5)
- V4: Cross-machine parity test (5)

## Production and Security
- G1: Production host (8)
- H1: WireGuard + SSH hardening (8)
- H2: Secrets hardening pass (3)
- S1: Local secrets baseline (2)
- S2: DB password rotation (2)

## Standards and Toolchain
- N1: Verify source numeric formats (2)
- N2: Define project numeric standard (3)
- T1: Toolchain baseline document (2)
- T2: Toolchain automation baseline (3)
- T3: Toolchain hardening pass (3)
- HW1: Hardware bring-up baseline (3)

## Parking Lot (Not Yet in Kanban/Tech-Tree)
- P1: Add branching strategy and PR template (3)
- P2: Add ADR template and first architecture decisions (2)
- P3: Add db migration flow (Alembic or dbmate) (5)
- P4: Define MQTT topic naming convention and payload schema (3)
- P5: Add replay/dead-letter strategy for malformed payloads (5)
- P6: Add data quality dashboard (freshness + row count) (5)
- P7: Apply numeric formatting standard in dashboards and docs (3)
- P8: Secrets strategy (dotenv -> vault/sops) (5)
- P9: Record architecture walkthrough and demo script (3)
- P10: Add screenshots and operational runbook (3)
- P11: Add benchmark and cost profile section (2)

## Candidate sprint order
- Sprint 1 (13 SP): A1, A2, B1
- Sprint 2 (16 SP): B2, C1, C2
- Sprint 3 (16 SP): C3, D1, D2, V1
- Sprint 4 (16 SP): V2, V3, N1, N2, T2
- Sprint 5 (18 SP): V4, E1, G1
- Sprint 6 (15 SP): H1, H2, S2, T3

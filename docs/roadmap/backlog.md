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
- B1: API ingestion (5) — inkl. EUR elspotprice ingest (P12)
- B2: MQTT ingestion (8)
- C1: Enriched standardization (3)
- C2: Curated star schema build (5)
- C3: Semantic serving views (3)

## BI and Operations
- D1: Grafana dashboards (5)
- D2: Metabase showcase (3)
- E1: Ops monitoring (5) — inkl. screenshots og operational runbook (P10)
- F1: Project demo (3) — inkl. architecture walkthrough og demo script (P9)

## Validation Gates
- V1: Local smoke test gate (3)
- V2: Data integrity gate (3)
- V3: Backup and restore drill (5)
- V4: Cross-machine parity test (5)

## Production and Security
- G1: Production host (8)
- H1: WireGuard + SSH hardening (8)
- H2: Secrets hardening pass (3) — inkl. secrets strategy evaluation (dotenv → vault/sops) (P8)
- S1: Local secrets baseline (2)
- S2: DB password rotation (2)

## Standards and Toolchain
- N1a: Verify Energinet numeric formats (1) ✅
- N1b: Verify MQTT telemetry numeric contract (2)
- N2: Define project numeric standard (3) — inkl. anvend standard i dashboards og docs (P7)
- T1: Toolchain baseline document (2)
- T2: Toolchain automation baseline (3)
- T3: Toolchain hardening pass (3) — inkl. scripts-mappe og sql-mappe reorganisering (P13, P14)
- HW1: Hardware bring-up baseline (3)

## Process and Governance
- W1: Branching strategy og PR template (3)
- W2: ADR template og første architecture decisions (2)

## ML Platform Foundation
- M1: ML data readiness baseline (3)
- M2: Feature pipeline template (5)
- M3: Model registry and versioning baseline (3)
- M4: Training and evaluation workflow baseline (5)
- M5: Inference serving contract (3)
- M6: ML monitoring baseline (3)

## Parking Lot (Not Yet in Kanban/Tech-Tree)
- P11: Add benchmark and cost profile section (2)

## Candidate sprint order
- Sprint 1 (13 SP): A1, A2, B1
- Sprint 2 (16 SP): B2, C1, C2
- Sprint 3 (16 SP): C3, D1, D2, V1
- Sprint 4 (21 SP): V2, V3, N1b, N2, T2, W1, W2
- Sprint 5 (18 SP): V4, E1, G1
- Sprint 6 (15 SP): H1, H2, S2, T3
- Sprint 7 (19 SP): M1, M2, M3, M4, M5
- Sprint 8 (3 SP): M6

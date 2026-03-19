# commons-anchor

Open-source home-lab data platform for applied learning and technical demonstration.

This project demonstrates end-to-end data engineering and applied data science on self-hosted Linux infrastructure:
- PostgreSQL-based data warehouse
- IoT ingestion from ESP32 via MQTT
- Public API ingestion (for example Energinet data)
- Dashboard delivery for analysis and operations
- Secure remote administration with VPN and SSH

## Project intent

Primary profile:
- Energy domain understanding + data scientist mindset
- Infrastructure as enablement, not as the main role

Primary project value order:
1. Learning progression and engineering discipline
2. Business and decision value
3. Climate and citizen-science relevance

## Professional summary

This repository is built as a practical showcase of:
- data architecture design
- SQL and Python delivery
- reproducible analytics workflows
- operational responsibility on Linux and containers

The long-term target runtime is a used Lenovo Tiny running Ubuntu Server, with a fully self-hosted stack.

## Contributor setup (5 min)

Use this when a new person clones the repository and wants a working local setup quickly.

1. Create local env from template:

```powershell
Copy-Item .env.example .env
```

2. Create local secret files (never committed):

```powershell
New-Item -ItemType Directory -Force infra/secrets | Out-Null
Set-Content infra/secrets/postgres_password.secret "<strong-postgres-password>"
Set-Content infra/secrets/grafana_admin_password.secret "<strong-grafana-password>"
```

3. Start core services:

```powershell
docker compose up -d
```

4. Verify secrets are ignored:

```powershell
git check-ignore -v .env
git check-ignore -v infra/secrets/postgres_password.secret
git check-ignore -v wg-client.conf
```

5. Open Grafana and verify login:
- URL: http://localhost:3000
- User: value of `GF_SECURITY_ADMIN_USER` in `.env`
- Password: value stored in `infra/secrets/grafana_admin_password.secret`

For the full security/reproducibility contract, see [docs/security/local-secrets-baseline.md](docs/security/local-secrets-baseline.md).

## Motivation

The project is intentionally designed as a long-term learning system.
The tech-tree is not only planning documentation, but a personal motivation tool to keep progress measurable and visible.

## Architecture diagrams

System architecture:

<!-- AUTO_SYSTEMARCH_START -->
```mermaid
%% AUTO-GENERATED FROM docs/architecture/diagram-model.json
flowchart TB
  subgraph Ops access
    direction TB
    U["Remote admin"]
    WG["WireGuard"]
    SSH["SSH on private LAN"]
    H["Ubuntu Server<br/>Lenovo Tiny"]
  end

  subgraph Sources
    direction LR
    E["ESP32"]
    A["Energinet API"]
  end

  subgraph Ingestion and Warehouse
    direction LR
    M[("Mosquitto")]
    I["Ingestion jobs"]
    B[("PostgreSQL<br/>Raw layer")]
    TR["Raw -> Enriched transforms"]
    S[("PostgreSQL<br/>Enriched layer")]
  end

  subgraph Serving and BI
    direction LR
    TC["Enriched -> Curated modeling"]
    G1[("PostgreSQL<br/>Curated layer")]
    TS["Curated -> Semantic serving"]
    SV[("PostgreSQL<br/>Semantic/Serving views")]
    G["Grafana"]
    MB["Metabase"]
  end

  subgraph Legend
    direction LR
    L1["Legend:<br/>solid arrows = data/access flow<br/>edge labels = protocol/action"]
  end


  E -->|MQTT| M
  A -->|HTTP pull| I
  M -->|subscribe/read| I
  I -->|upsert raw| B
  B -->|SQL transform| TR
  TR -->|standardize| S
  S -->|modeling input| TC
  TC -->|star schema build| G1
  G1 -->|semantic prep| TS
  TS -->|create views| SV
  SV -->|query| G
  SV -->|query| MB
  U -->|WireGuard VPN| WG
  WG -->|private tunnel| SSH
  SSH -->|admin session| H
```
<!-- AUTO_SYSTEMARCH_END -->

Project kanban:

<!-- AUTO_KANBAN_START -->
```mermaid
%% AUTO-GENERATED FROM docs/architecture/diagram-model.json
kanban
  Backlog
    [5 SP - DB migration flow]

    [3 SP - Enriched standardization]

    [5 SP - Curated star schema build]

    [3 SP - Semantic serving views]

    [3 SP - MQTT topic and payload contract]

    [5 SP - MQTT replay and dead-letter strategy]

    [5 SP - Grafana dashboards]

    [3 SP - Metabase showcase]

    [5 SP - Data quality dashboard]

    [5 SP - Ops monitoring]

    [3 SP - Project demo]

    [3 SP - Data integrity gate]

    [5 SP - Backup and restore drill]

    [5 SP - Cross-machine parity test]

    [8 SP - Production host]

    [2 SP - Verify source numeric formats]

    [3 SP - Define project numeric standard]

    [3 SP - Secrets hardening pass]

    [3 SP - Toolchain automation baseline]

    [3 SP - Toolchain hardening pass]

    [3 SP - Hardware bring-up baseline]

  [In Progress]
    [5 SP - API ingestion]

    [3 SP - Local smoke test gate]

    [8 SP - WireGuard + SSH hardening prep]

  Done
    [5 SP - Docker baseline]

    [3 SP - Postgres schemas]

    [8 SP - MQTT ingestion]

    [2 SP - Local secrets baseline]

    [2 SP - DB password rotation]

    [2 SP - Toolchain baseline document]
```
<!-- AUTO_KANBAN_END -->

Tech-tree (dependency path):

<!-- AUTO_TECHTREE_START -->
```mermaid
%% AUTO-GENERATED FROM docs/architecture/diagram-model.json
flowchart TD
  A1[Node A1<br/>Docker baseline<br/>5 SP]
  A2[Node A2<br/>Postgres schemas<br/>3 SP]
  B1[Node B1<br/>API ingestion<br/>5 SP]
  B2[Node B2<br/>MQTT ingestion<br/>8 SP]
  B3[Node B3<br/>DB migration flow<br/>5 SP]
  C1[Node C1<br/>Enriched standardization<br/>3 SP]
  C2[Node C2<br/>Curated star schema build<br/>5 SP]
  C3[Node C3<br/>Semantic serving views<br/>3 SP]
  C4[Node C4<br/>MQTT topic and payload contract<br/>3 SP]
  C5[Node C5<br/>MQTT replay and dead-letter strategy<br/>5 SP]
  D1[Node D1<br/>Grafana dashboards<br/>5 SP]
  D2[Node D2<br/>Metabase showcase<br/>3 SP]
  D3[Node D3<br/>Data quality dashboard<br/>5 SP]
  E1[Node E1<br/>Ops monitoring<br/>5 SP]
  F1[Node F1<br/>Project demo<br/>3 SP]
  V1[Node V1<br/>Local smoke test gate<br/>3 SP]
  V2[Node V2<br/>Data integrity gate<br/>3 SP]
  V3[Node V3<br/>Backup and restore drill<br/>5 SP]
  V4[Node V4<br/>Cross-machine parity test<br/>5 SP]
  G1[Node G1<br/>Production host<br/>8 SP]
  S1[Node S1<br/>Local secrets baseline<br/>2 SP]
  S2[Node S2<br/>DB password rotation<br/>2 SP]
  N1[Node N1<br/>Verify source numeric formats<br/>2 SP]
  N2[Node N2<br/>Define project numeric standard<br/>3 SP]
  H1[Node H1<br/>WireGuard + SSH hardening prep<br/>8 SP]
  H2[Node H2<br/>Secrets hardening pass<br/>3 SP]
  T1[Node T1<br/>Toolchain baseline document<br/>2 SP]
  T2[Node T2<br/>Toolchain automation baseline<br/>3 SP]
  T3[Node T3<br/>Toolchain hardening pass<br/>3 SP]
  HW1[Node HW1<br/>Hardware bring-up baseline<br/>3 SP]

  A1 --> A2
  A2 --> B1
  A2 --> B2
  A2 --> B3
  B1 --> C1
  B2 --> C1
  C1 --> C2
  C2 --> C3
  B2 --> C4
  C4 --> C5
  C3 --> D1
  C3 --> D2
  C3 --> D3
  V2 --> D3
  D1 --> E1
  D2 --> F1
  C3 --> V1
  D1 --> V1
  V1 --> V2
  V2 --> V3
  V3 --> V4
  E1 --> G1
  F1 --> G1
  V4 --> G1
  A1 --> S1
  S1 --> S2
  A2 --> S2
  B1 --> N1
  N1 --> N2
  C3 --> N2
  D1 --> N2
  S2 --> H1
  T3 --> H1
  S2 --> H2
  T3 --> H2
  A1 --> T1
  T1 --> T2
  A2 --> T2
  T2 --> T3
  B2 --> HW1
  T1 --> HW1

  classDef done fill:#d8f5d0,stroke:#2f7a2f,stroke-width:1px,color:#1c311c
  classDef inProgress fill:#fff1c7,stroke:#8a6a00,stroke-width:1px,color:#3a2a00
  classDef backlog fill:#e8edf3,stroke:#5a6b7d,stroke-width:1px,color:#1f2b38
  class A1 done
  class A2 done
  class B1 inProgress
  class B2 done
  class B3 backlog
  class C1 backlog
  class C2 backlog
  class C3 backlog
  class C4 backlog
  class C5 backlog
  class D1 backlog
  class D2 backlog
  class D3 backlog
  class E1 backlog
  class F1 backlog
  class V1 inProgress
  class V2 backlog
  class V3 backlog
  class V4 backlog
  class G1 backlog
  class S1 done
  class S2 done
  class N1 backlog
  class N2 backlog
  class H1 inProgress
  class H2 backlog
  class T1 done
  class T2 backlog
  class T3 backlog
  class HW1 backlog
```
<!-- AUTO_TECHTREE_END -->

Validation gates:
- [docs/infra/environment-validation.md](docs/infra/environment-validation.md)
- [Platform Smoke Gate workflow](.github/workflows/platform-smoke.yml)

Diagram standards and templates:
- [docs/architecture/mermaid-guidelines.md](docs/architecture/mermaid-guidelines.md)
- [docs/architecture/mermaid-templates.md](docs/architecture/mermaid-templates.md)

Terminology glossary:
- [docs/glossary.md](docs/glossary.md)

Toolchain definition:
- [docs/toolchain.md](docs/toolchain.md)

Data warehouse strategy:
- [docs/architecture/data-warehouse-strategy.md](docs/architecture/data-warehouse-strategy.md)

Local secrets baseline:
- [docs/security/local-secrets-baseline.md](docs/security/local-secrets-baseline.md)

## SQL syntax checks (PostgreSQL)

If you come from SQL Server, it is easy to accidentally use T-SQL syntax that PostgreSQL rejects.
Use the built-in parser-based checker to validate all SQL scripts under `infra/sql`:

```bash
python -m pip install .[dev]
check-sql-syntax
```

Optional custom path:

```bash
check-sql-syntax --root path/to/sql
```

## Data architecture (layered model)

Target warehouse model is Raw/Enriched/Curated/Serving:
- Raw: raw, immutable ingestion from APIs and MQTT
- Enriched: cleaned, standardized, quality-checked datasets
- Curated: analytics-ready marts for dashboards and ML features
- Serving: semantic views for stable BI consumption (Grafana/Metabase)

Modeling direction:
- Raw and Enriched are source-oriented (each source has its own grouping/module).
- Curated is business-oriented and modeled as star schemas (facts and dimensions).

MVP schema mapping (conceptual -> physical):
- Raw -> `staging`
- Curated -> `mart`
- Enriched -> planned as a dedicated schema in a later phase

This keeps the conceptual model stable while the physical schema evolves incrementally.

See the full strategy in [docs/architecture/data-warehouse-strategy.md](docs/architecture/data-warehouse-strategy.md).

## Terminology (short glossary)

- Raw: raw source data with minimal processing
- Enriched: cleaned and standardized datasets
- Curated: analytics-ready datasets
- Baseline model: first reference model used for iterative improvement
- Tech-tree: dependency map for planned delivery path

See the full glossary in [docs/glossary.md](docs/glossary.md).

## ML strategy

Approach:
- Iterative modeling and forecasting in the same loop

Execution cycle:
1. Train simple baseline models
2. Forecast on 15-minute grain for public data
3. Compare predictions with actual observations
4. Improve features, transformations, and model choices

Data grain policy:
- Public spot prices: 15-minute intervals (MVP baseline)
- IoT telemetry: around 5-minute intervals, aggregated to hourly for shared analysis

## Technology choices

Core stack:
- PostgreSQL 16
- Eclipse Mosquitto 2
- Grafana 11
- Metabase 0.53
- Docker Compose

Principles:
- Open-source first
- Professional tooling and reproducibility
- Low-cost setup (hardware + power + internet are main non-software costs)

## Quick start (local)

Windows note (recommended):
- If your shell cannot find `python`, `pip`, or `pytest`, use the virtualenv executable explicitly:

  ```powershell
  .\.venv\Scripts\python.exe -m pip install -e .[dev]
  .\.venv\Scripts\python.exe -m pytest -q
  ```

  This avoids PATH issues and ensures all commands run in the same environment.

1. Copy env file

	```powershell
	Copy-Item .env.example .env
	```

2. Create local secret files (not tracked by git)

  ```powershell
  New-Item -ItemType Directory -Force infra/secrets | Out-Null
  Set-Content infra/secrets/postgres_password.secret "<strong-postgres-password>"
  Set-Content infra/secrets/grafana_admin_password.secret "<strong-grafana-password>"
  ```

  For contributor onboarding and the full local secrets contract, see [docs/security/local-secrets-baseline.md](docs/security/local-secrets-baseline.md).

3. Update non-secret settings in .env if needed

4. Start stack

	```powershell
	docker compose up -d
	```

5. Smoke-test Energi Data Service ingestion into PostgreSQL

  ```powershell
  docker compose --profile jobs run --rm energidata-ingest
  ```

6. Verify raw rows landed in PostgreSQL

  ```powershell
  docker compose exec postgres psql -U $env:POSTGRES_USER -d $env:POSTGRES_DB -c "SELECT dataset, area, ts_utc, price_dkk_mwh FROM staging.energinet_raw ORDER BY ts_utc DESC LIMIT 10;"
  ```

7. Run first mart transformation (15-minute curated)

  ```powershell
  docker compose --profile jobs run --rm power-price-transform
  ```

8. Verify curated quarter-hour rows landed in mart

  ```powershell
  docker compose exec postgres psql -U $env:POSTGRES_USER -d $env:POSTGRES_DB -c "SELECT ts_utc, area, price_dkk_mwh FROM mart.power_price_15min ORDER BY ts_utc DESC, area ASC LIMIT 10;"
  ```

9. MQTT ingestion smoke test (phone/ESP32 -> MQTT -> Postgres)

  ```powershell
  docker compose up -d --build mqtt mqtt-ingest postgres
  ```

  MQTT ingest defaults:
  - Topic filter: `ca/dev/+/telemetry`
  - QoS: `1` (configurable with `MQTT_QOS` in `.env`)
  - Source tag: `phone_or_esp32` (configurable with `MQTT_SOURCE`)

  Expected payload contract (JSON object):

  ```json
  {"device_id":"phone01","temp_c":22.7,"hum_pct":41.8,"ts":"2026-03-17T20:30:00Z"}
  ```

  Required fields:
  - `device_id` (non-empty string)
  - `ts` (ISO timestamp)

  Worker behavior:
  - Valid JSON + valid contract -> row inserted into `staging.mqtt_raw`
  - Invalid JSON or invalid contract -> message skipped and logged

  Publish JSON telemetry to topic `ca/dev/phone01/telemetry`, then verify:

  ```powershell
  docker compose logs --tail 20 mqtt-ingest
  docker exec ca-postgres psql -U dw_admin -d dw -c "SELECT id, topic, payload, ingested_at FROM staging.mqtt_raw ORDER BY id DESC LIMIT 5;"
  ```

  Android runbook (IoT MQTT Panel with dashboard + text input panel):
  - [docs/infra/android-mqtt-smoke-test.md](docs/infra/android-mqtt-smoke-test.md)

10. Open services
- Grafana: http://localhost:3000
- Metabase: http://localhost:3001
- PostgreSQL: localhost:5432
- MQTT broker: localhost:1883

11. Open the first dashboard in Grafana
- Login with `GF_SECURITY_ADMIN_USER` from `.env`
- Use password from `infra/secrets/grafana_admin_password.secret`
- Navigate to Dashboards -> Commons Anchor -> Power Price Overview

Notes:
- The ingestion job defaults to the active `DayAheadPrices` dataset.
- Historical backfill can later use `Elspotprices` for dates before 2025-10-01.
- If you need a clean bootstrap after schema changes, run `docker compose down -v` before bringing the stack up again.
- For manual MQTT app validation on Android, follow [docs/infra/android-mqtt-smoke-test.md](docs/infra/android-mqtt-smoke-test.md).
- MQTT ingest stability defaults live in `.env` (`MQTT_TOPIC`, `MQTT_QOS`, `MQTT_SOURCE`).

## Local quality gate

Run the same checks locally that are enforced in CI:

```powershell
.\.venv\Scripts\python.exe -m ruff format --check scripts tests
.\.venv\Scripts\python.exe -m ruff check scripts tests
.\.venv\Scripts\python.exe -m pyright --pythonpath .\.venv\Scripts\python.exe
.\.venv\Scripts\python.exe -m scripts.check_sql_syntax
.\.venv\Scripts\python.exe -m pytest -q
```

## Repository structure

```text
.
|- pyproject.toml
|- docker-compose.yml
|- .env.example
|- .github/workflows/mermaid-validate.yml
|- infra/
|  |- mosquitto/config/mosquitto.conf
|  \- sql/init/001_init.sql
\- docs/
	|- architecture/
	|  |- adr-0001-platform-scope.md
	|  |- mermaid-guidelines.md
	|  |- mermaid-templates.md
	|  \- diagrams/
  |- toolchain.md
	|- infra/ubuntu-lenovo-tiny.md
	|- roadmap/backlog.md
	\- security/wireguard-remote-access.md
```

## Delivery model

- Work is split into story-point sized tasks
- Dependencies are tracked in the tech-tree
- Architecture decisions are recorded as ADRs
- Mermaid diagrams are source-controlled and CI-validated
- Lenovo Tiny deployment is gated by environment validation (V1-V4)

## Project outcomes

Target deliverables:
1. Clear Raw/Enriched/Curated warehouse design and SQL transformations
2. Reproducible baseline ML and forecasting workflow
3. Live dashboards combining public and IoT data
4. Documented operational model for secure self-hosting
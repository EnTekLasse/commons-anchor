# Toolchain v1 (Open Source and Free)

This document defines a practical default toolchain for the project.

## Goals
- Keep the stack free and open source.
- Stay professional and reproducible.
- Start simple, then harden gradually.

## Principles
- One tool per concern whenever possible.
- Prefer widely adopted, actively maintained tools.
- Avoid early over-engineering.
- Automate checks in CI when setup is stable.

## Required now

### Runtime and environment
- Python 3.11+
- venv (or uv later)
- Docker + Docker Compose
- Environment files (`.env` per machine)

### Firmware and device development
- ESP-IDF extension for VS Code
- ESP-IDF toolchain managed separately from the project Python venv
- One firmware workspace subtree per board family under `firmware/`
- Shared MQTT topic/payload contract documented in `docs/`

### Python quality
- Ruff for linting and formatting
- Pytest for tests
- Pylance/Pyright type checking set to standard initially
- Single-command local gate via `local-quality-gate`

Current baseline commands:
- `ruff format scripts`
- `ruff format --check scripts`
- `ruff check scripts`
- `check-mermaid-compile --changed-only`
- `local-quality-gate`

Recommended local order:
1. `ruff format scripts`
2. `ruff check scripts`
3. `local-quality-gate`

### Data and database
- PostgreSQL 16
- requests for public API ingestion
- psycopg for direct PostgreSQL writes
- SQLAlchemy later if the ingestion/transform layer grows in complexity
- Alembic for migrations (planned)

### Documentation and architecture
- Mermaid diagrams generated from `docs/architecture/diagram-model.json`
- Mermaid compile validation via `check-mermaid-compile` (full) or `check-mermaid-compile --changed-only` (fast local)
- README as canonical architecture surface
- ESP-IDF onboarding and setup notes for beginner contributors

### CI baseline
- GitHub Actions
- Mermaid sync and render validation
- Ruff format check
- Ruff lint check

## Add next (recommended)
- pre-commit hooks for Ruff and basic checks
- pytest-cov coverage reporting
- SQLFluff for SQL style/lint
- Basic smoke test script for V1 gate
- First ESP-IDF onboarding guide and firmware project template

## Add later (when needed)
- Strict type checking in selected critical modules
- Structured JSON logging
- Secrets encryption workflow (for example sops)
- Workflow orchestration tool if scheduling complexity grows

## Suggested defaults
- Formatter/linter: Ruff
- Tests: Pytest
- Types: Pylance standard first, strict by module over time
- Diagrams: model-driven Mermaid generation script
- Firmware IDE: VS Code + ESP-IDF extension
- Firmware Python environment: ESP-IDF managed environment, not the root project `.venv`

## Non-goals for v1
- Kubernetes
- Complex multi-node orchestration
- Paid SaaS dependencies for core workflow

## Review cadence
- Revisit this toolchain after each major milestone.
- Promote tools from "next" to "required" only when team friction is low.

## ESP-IDF note
- Do not reuse the repo root Python virtual environment for ESP-IDF.
- ESP-IDF brings its own Python packages and toolchain expectations, and mixing them with the data-platform venv will create avoidable breakage.
- Treat firmware tooling as a separate concern even when it lives in the same Git repository.

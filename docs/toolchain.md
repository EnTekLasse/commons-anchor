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

### Python quality
- Ruff for linting and formatting
- Pytest for tests
- Pylance/Pyright type checking set to standard initially

Current baseline commands:
- `ruff format scripts`
- `ruff format --check scripts`
- `ruff check scripts`

Recommended local order:
1. `ruff format scripts`
2. `ruff check scripts`

### Data and database
- PostgreSQL 16
- requests for public API ingestion
- psycopg for direct PostgreSQL writes
- SQLAlchemy later if the ingestion/transform layer grows in complexity
- Alembic for migrations (planned)

### Documentation and architecture
- Mermaid diagrams generated from `docs/architecture/diagram-model.json`
- README as canonical architecture surface

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

## Non-goals for v1
- Kubernetes
- Complex multi-node orchestration
- Paid SaaS dependencies for core workflow

## Review cadence
- Revisit this toolchain after each major milestone.
- Promote tools from "next" to "required" only when team friction is low.

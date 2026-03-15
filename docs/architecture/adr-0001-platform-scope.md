# ADR-0001: Platform Scope and MVP Boundaries

## Status
Accepted

## Context
Project must demonstrate practical data engineering and DevOps skills through an end-to-end implementation.

## Decision
MVP scope includes:
- PostgreSQL as core warehouse store
- MQTT ingestion path for ESP32 telemetry
- Public API ingestion path (Energinet)
- Dashboarding with Grafana/Metabase
- Containerized runtime using Docker Compose

Not in MVP:
- Kubernetes
- Multi-node clustering
- Enterprise IAM integration

## Consequences
- Faster delivery of a demonstrable, end-to-end system
- Clear upgrade path toward orchestration and scaling in later phases

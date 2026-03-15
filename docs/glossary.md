# Terminology Glossary

Short reference for consistent terms used across this project.

## Core architecture terms
- Data platform: The full system for ingestion, storage, transformation, and analytics.
- Data warehouse: The structured analytical storage layer in PostgreSQL.
- Layered model: Data architecture with Raw, Enriched, Curated datasets.

## Layer types
- Raw: Raw, append-only source data with minimal processing.
- Enriched: Cleaned, standardized, validated datasets.
- Curated: Analytics-ready datasets for dashboards and ML features.

## Pipeline and modeling terms
- Ingestion: Data collection from APIs and MQTT into Raw.
- Transformation: SQL or code-based processing from Raw to Enriched/Curated.
- Baseline model: Simple first ML model used as reference quality.
- Forecasting: Predicting future values from historical data.
- Iterative loop: Train, evaluate, compare with actuals, and improve.

## Operations terms
- Self-hosted: Running the platform on owned hardware (Lenovo Tiny target).
- Observability: Monitoring health, freshness, and service behavior.
- Runbook: Practical operating instructions for setup, incidents, and recovery.

## Planning terms
- Story points: Relative effort estimate for planning work.
- Tech-tree: Dependency map showing development path and unlock order.
- ADR (Architecture Decision Record): Documented architecture choices and rationale.

## Current implementation note
- Physical schema today uses staging/mart names.
- Conceptual model in documentation uses Raw/Enriched/Curated.
- Mapping: staging -> Raw/Enriched transition zone, mart -> Curated-focused outputs.

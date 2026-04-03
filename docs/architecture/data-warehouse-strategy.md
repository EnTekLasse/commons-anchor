# Data Warehouse Strategy

This document describes the target strategy for the warehouse model in Commons Anchor.

## Goals

- Keep ingestion simple, reliable, and auditable.
- Build stable curated datasets for dashboards and later ML features.
- Allow incremental delivery without breaking the conceptual model.

## Layered Model

Conceptual layers:

- Raw: immutable source-level records with minimal normalization.
- Enriched: standardized and quality-checked records used as reusable foundation.
- Curated: business-facing marts optimized for analytics and dashboards.
- Serving: semantic and consumption-facing models for BI tools and APIs.

Current physical mapping in MVP:

- Raw -> `staging`
- Enriched -> `enrich`
- Curated -> `mart`
- Serving -> planned as `semantic` views on top of curated star schemas


Planned mapping:

- Ingestion: Python scripts in `scripts/ingest` load source-faithful rows into Raw.
- Raw folder: `raw/<source>/001_create_tables.sql`
- Enrich folder: `enrich/<source>/001_create_views.sql`
- Curated folder: `curated/<star_schema>/001_create_materialized_views.sql` and `010_refresh.sql`
- Serving folder: `serving/<usecase>/001_create_views.sql`
- ML Feature folder: `ml_feature/<feature_group>/001_create_tables.sql` and `010_refresh.sql`
- Refresh orchestration: `infra/sql/020_refresh_all.sql`
- Existing-database changes: `infra/sql/migrations/*.sql`


### Physical Organization Rules

- Raw is source-oriented: each source gets its own namespace/grouping (for example API-specific and MQTT-specific areas) to keep lineage explicit.
- Enriched is also source-oriented: standardized tables remain grouped per source before cross-source modeling.
- Curated is business-oriented: models are built as star schemas with conformed dimensions and fact tables for analytics.
- Serving is consumer-oriented: stable semantic views expose canonical metrics for Grafana/Metabase.

Target convention:

- Raw: one source, one folder/module, one primary ingestion table family.
- Enriched: one source, one folder/module, standardized source tables plus shared reference mappings.
- Curated: domain marts organized as star schemas (facts + dimensions), independent of source folder boundaries.
- Serving: semantic views organized by business entity/metric groups, independent of source-specific raw/enriched modules.
- Use consistent filenames inside folders so related create/refresh files sort together visually.
- For providers with multiple APIs, use `<provider>_<api_family>` naming in folders and script names.

Examples:

- `dmi_climate`
- `dmi_meteorological_observations`
- `dmi_oceanographic_observations`
- `dmi_lightning`
- `dmi_radar`
- `dmi_forecast_stac`
- `dmi_forecast_edr`

## Data Contracts

- Every ingest job must define required fields and timestamp semantics.
- Raw tables preserve source payloads and source field values as-is where practical.
- Raw tables may add operational metadata columns such as ingest timestamp, source system, topic, or deterministic dedupe keys.
- Time values are normalized to UTC in Enriched, not in Raw.
- Numeric fields use explicit conversion and validation in Enriched/Curated logic, not in Raw.

## Quality Gates

- Ingestion idempotency where practical (upsert or deterministic keys).
- Non-null checks on mart-critical columns.
- Basic freshness checks in smoke and CI workflows.
- SQL syntax validation for all warehouse scripts before merge.

## Modeling Principles

- Prefer append-friendly raw ingestion.
- Keep Raw source-faithful: same semantics and as-close-as-practical source datatypes first, typed business conversion later.
- Keep transforms deterministic and rerunnable.
- Separate source-specific logic from reusable business transforms.
- Avoid dashboard-specific calculations in raw/staging layers.
- Keep source boundaries strong in Raw and Enriched; only Curated should cross sources for business models.

## Operational Strategy

- Start with one curated table per clear user question.
- Expand marts only when there is a concrete dashboard or analysis need.
- Add schema evolution in small, reversible steps.
- Document each major model decision in ADRs or focused docs.
- Use bootstrap files only for empty-database initialization; use migrations for existing databases.
- Keep refresh orchestration explicit rather than implicit recursive folder execution.
- Use [docs/architecture/sql-delivery-playbook.md](sql-delivery-playbook.md) as the practical workflow guide for adding sources and changing transforms.

## Semantic Layer Direction

- Curated star schemas are the modeling base for semantic definitions.
- Business metrics should be exposed through stable semantic views.
- See concrete v1 blueprint: [docs/architecture/semantic-model-power-price.md](semantic-model-power-price.md)

## Near-Term Roadmap

1. Introduce explicit Enriched schema for shared standardized tables.
2. Add source-level quality metrics (invalid payloads, late arrivals, missing intervals).
3. Add lightweight data quality assertions as SQL checks in CI.
4. Define retention and archival policy for raw/staging data.

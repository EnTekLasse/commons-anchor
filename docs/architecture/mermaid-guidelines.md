# Mermaid Guidelines (Robust Cross-Renderer)

## Goal
Keep diagrams readable and stable across:
- VS Code markdown preview
- Mermaid extension preview
- GitHub README rendering

## Repository convention
- README is the canonical display surface for project diagrams.
- `.mmd` files are optional editing helpers and must stay aligned with README blocks.

## Core rules
- Prefer simple, conservative Mermaid syntax.
- Use `flowchart` and `kanban` as default diagram types for this repo.
- Use `<br/>` for line breaks inside nodes.
- Avoid `\\n` in labels, because some renderers display it as plain text.
- Keep node labels short and explicit.
- Avoid special characters in labels when possible.
- Use consistent left-to-right (`LR`) or top-down (`TD`) direction.

## Flowchart conventions
- IDs: short and stable (`A1`, `B2`, `ETL`, `DB`).
- Labels: human readable and action focused.
- Edges: add edge text only when it improves clarity.
- Grouping: use subgraph for source/system boundaries.

### Recommended pattern
```mermaid
flowchart LR
  subgraph Sources
    API[Public APIs<br/>Energinet]
    IoT[ESP32 devices]
  end

  IoT -->|MQTT| Broker[(Mosquitto)]
  API -->|HTTP pull| ETL[Ingestion jobs]
  Broker --> ETL
  ETL --> Raw[(PostgreSQL<br/>Raw)]
  Raw --> Transform[Transform jobs]
  Transform --> Enriched[(PostgreSQL<br/>Enriched)]
  Enriched --> Curated[(PostgreSQL<br/>Curated)]
```

## Kanban conventions
- Use plain section names and card labels.
- Keep one card per line and add a blank line between cards.
- Keep story points as prefix text: `3 SP - ...`
- Avoid parentheses-heavy card labels if renderer behaves oddly.

### Recommended pattern
```mermaid
kanban
  Backlog
    [3 SP - Define MQTT topic schema]

    [5 SP - Build Energinet ingestion script]

  [In Progress]
    [5 SP - Build dashboard baseline]

  Done
    [Repo initialized]
```

## Tech-tree conventions
- Use flowchart `TD` and explicit node IDs.
- Keep each node to three lines max:
  - Node ID/title
  - capability
  - story points

### Recommended pattern
```mermaid
flowchart TD
  A1[Node A1<br/>Docker baseline<br/>5 SP] --> A2[Node A2<br/>Postgres schemas<br/>3 SP]
  A2 --> B1[Node B1<br/>API ingestion<br/>5 SP]
  A2 --> B2[Node B2<br/>MQTT ingestion<br/>8 SP]
```

## Validation workflow
1. Edit diagram in markdown.
2. Validate Mermaid syntax before commit.
3. Check both VS Code preview and GitHub rendering.
4. If rendering differs, simplify syntax and remove advanced features first.

## Troubleshooting quick checks
- If you see literal `\\n`: replace with `<br/>`.
- If kanban cards disappear: simplify labels and spacing.
- If parser errors point at card lines: test with minimal kanban first, then add cards back incrementally.
- If preview seems stale: reload VS Code window.

# Mermaid Templates

Use these templates when adding new diagrams.

## 1) Architecture flowchart

```mermaid
flowchart LR
  subgraph Sources
    S1[Source A]
    S2[Source B]
  end

  S1 --> P[Process]
  S2 --> P
  P --> D[(Data Store)]
  D --> V[Visualization]
```

## 2) Project kanban

```mermaid
kanban
  Backlog
    [3 SP - First task]

    [5 SP - Second task]

  [In Progress]
    [2 SP - Current task]

  Done
    [Completed baseline]
```

## 3) Dependency tech-tree

```mermaid
flowchart TD
  A1[Node A1<br/>Foundation<br/>3 SP] --> B1[Node B1<br/>Capability 1<br/>5 SP]
  A1 --> B2[Node B2<br/>Capability 2<br/>5 SP]
  B1 --> C1[Node C1<br/>Delivery<br/>3 SP]
  B2 --> C1
```

## Naming and readability checklist
- Stable node IDs
- Short labels
- `<br/>` for line breaks
- Story points as plain text
- No renderer-specific tricks unless necessary

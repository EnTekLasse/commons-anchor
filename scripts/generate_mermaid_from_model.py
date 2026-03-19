import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODEL_PATH = ROOT / "docs" / "architecture" / "diagram-model.json"
SYSTEM_ARCH_PATH = ROOT / "docs" / "architecture" / "diagrams" / "system-architecture.mmd"
KANBAN_PATH = ROOT / "docs" / "architecture" / "diagrams" / "project-kanban.mmd"
TECH_TREE_PATH = ROOT / "docs" / "architecture" / "diagrams" / "tech-tree.mmd"
README_PATH = ROOT / "README.md"

SYSTEM_START = "<!-- AUTO_SYSTEMARCH_START -->"
SYSTEM_END = "<!-- AUTO_SYSTEMARCH_END -->"
KANBAN_START = "<!-- AUTO_KANBAN_START -->"
KANBAN_END = "<!-- AUTO_KANBAN_END -->"
TECH_START = "<!-- AUTO_TECHTREE_START -->"
TECH_END = "<!-- AUTO_TECHTREE_END -->"


def load_model() -> dict:
    return json.loads(MODEL_PATH.read_text(encoding="utf-8"))


def _escape_label(label: str) -> str:
    return label.replace('"', r"\"")


def _shape(node_id: str, label: str, shape: str) -> str:
    safe_label = _escape_label(label)
    if shape == "db":
        return f'{node_id}[("{safe_label}")]'
    return f'{node_id}["{safe_label}"]'


def render_system_architecture(model: dict) -> str:
    arch = model["systemArchitecture"]
    nodes = {n["id"]: n for n in arch["nodes"]}
    lines = [
        "%% AUTO-GENERATED FROM docs/architecture/diagram-model.json",
        f"flowchart {arch.get('direction', 'LR')}",
    ]

    in_subgraph = set()
    for subgraph in arch.get("subgraphs", []):
        subgraph_id = subgraph.get("id")
        subgraph_label = subgraph.get("label")
        if subgraph_id and subgraph_label is not None:
            lines.append(f'  subgraph {subgraph_id}["{_escape_label(subgraph_label)}"]')
        else:
            lines.append(f"  subgraph {subgraph['name']}")
        if subgraph.get("direction"):
            lines.append(f"    direction {subgraph['direction']}")
        for node_id in subgraph["nodes"]:
            node = nodes[node_id]
            lines.append("    " + _shape(node_id, node["label"], node.get("shape", "rect")))
            in_subgraph.add(node_id)
        lines.append("  end")
        lines.append("")

    for node_id, node in nodes.items():
        if node_id not in in_subgraph:
            lines.append("  " + _shape(node_id, node["label"], node.get("shape", "rect")))
    lines.append("")

    for edge in arch["edges"]:
        if len(edge) == 3 and edge[2]:
            lines.append(f"  {edge[0]} -->|{edge[2]}| {edge[1]}")
        else:
            lines.append(f"  {edge[0]} --> {edge[1]}")

    return "\n".join(lines) + "\n"


def render_kanban(model: dict) -> str:
    items = model["delivery"]["workItems"]
    status_order = [
        ("backlog", "Backlog", False),
        ("in_progress", "In Progress", True),
        ("done", "Done", False),
    ]

    lines = ["%% AUTO-GENERATED FROM docs/architecture/diagram-model.json", "kanban"]
    for status_key, title, bracketed in status_order:
        if bracketed:
            lines.append(f"  [{title}]")
        else:
            lines.append(f"  {title}")

        for item in items:
            if item.get("status") != status_key:
                continue
            card = f"{item['storyPoints']} SP - {item['title']}"
            lines.append(f"    [{card}]")
            lines.append("")

    while lines and lines[-1] == "":
        lines.pop()
    return "\n".join(lines) + "\n"


def render_tech_tree(model: dict) -> str:
    delivery = model["delivery"]
    items = delivery["workItems"]
    by_id = {item["id"]: item for item in items}

    lines = [
        "%% AUTO-GENERATED FROM docs/architecture/diagram-model.json",
        f"flowchart {delivery.get('direction', 'TD')}",
    ]

    for item in items:
        label = f"Node {item['id']}<br/>{item['title']}<br/>{item['storyPoints']} SP"
        lines.append(f"  {item['id']}[{label}]")

    lines.append("")

    for item in items:
        for dep in item.get("dependsOn", []):
            if dep not in by_id:
                raise ValueError(f"Unknown dependency '{dep}' in work item '{item['id']}'")
            lines.append(f"  {dep} --> {item['id']}")

    lines.append("")
    lines.append("  classDef done fill:#d8f5d0,stroke:#2f7a2f,stroke-width:1px,color:#1c311c")
    lines.append("  classDef inProgress fill:#fff1c7,stroke:#8a6a00,stroke-width:1px,color:#3a2a00")
    lines.append("  classDef backlog fill:#e8edf3,stroke:#5a6b7d,stroke-width:1px,color:#1f2b38")

    for item in items:
        status = item.get("status", "backlog")
        if status == "done":
            mermaid_class = "done"
        elif status == "in_progress":
            mermaid_class = "inProgress"
        else:
            mermaid_class = "backlog"
        lines.append(f"  class {item['id']} {mermaid_class}")

    return "\n".join(lines) + "\n"


def replace_section(text: str, start: str, end: str, replacement: str) -> str:
    pattern = re.compile(re.escape(start) + r".*?" + re.escape(end), flags=re.DOTALL)
    block = f"{start}\n{replacement}{end}"
    if not pattern.search(text):
        raise ValueError(f"Markers not found: {start} ... {end}")
    return pattern.sub(block, text)


def render_readme_block(mermaid_text: str) -> str:
    return "```mermaid\n" + mermaid_text.rstrip() + "\n```\n"


def expected_outputs(model: dict) -> dict:
    system_arch = render_system_architecture(model)
    kanban = render_kanban(model)
    tech = render_tech_tree(model)

    readme = README_PATH.read_text(encoding="utf-8")
    readme = replace_section(readme, SYSTEM_START, SYSTEM_END, render_readme_block(system_arch))
    readme = replace_section(readme, KANBAN_START, KANBAN_END, render_readme_block(kanban))
    readme = replace_section(readme, TECH_START, TECH_END, render_readme_block(tech))

    return {
        "system": system_arch,
        "kanban": kanban,
        "tech": tech,
        "readme": readme,
    }


def run_check(model: dict) -> int:
    expected = expected_outputs(model)
    ok = True

    if SYSTEM_ARCH_PATH.read_text(encoding="utf-8") != expected["system"]:
        print("Out of sync: docs/architecture/diagrams/system-architecture.mmd")
        ok = False
    if KANBAN_PATH.read_text(encoding="utf-8") != expected["kanban"]:
        print("Out of sync: docs/architecture/diagrams/project-kanban.mmd")
        ok = False
    if TECH_TREE_PATH.read_text(encoding="utf-8") != expected["tech"]:
        print("Out of sync: docs/architecture/diagrams/tech-tree.mmd")
        ok = False
    if README_PATH.read_text(encoding="utf-8") != expected["readme"]:
        print("Out of sync: README.md")
        ok = False

    if ok:
        print("Diagram artifacts are in sync.")
        return 0
    return 1


def run_write(model: dict) -> int:
    expected = expected_outputs(model)
    SYSTEM_ARCH_PATH.write_text(expected["system"], encoding="utf-8")
    KANBAN_PATH.write_text(expected["kanban"], encoding="utf-8")
    TECH_TREE_PATH.write_text(expected["tech"], encoding="utf-8")
    README_PATH.write_text(expected["readme"], encoding="utf-8")
    print("Updated Mermaid artifacts from diagram model.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate Mermaid artifacts from central JSON model"
    )
    parser.add_argument("--check", action="store_true", help="Check if generated files are in sync")
    args = parser.parse_args()

    model = load_model()
    if args.check:
        return run_check(model)
    return run_write(model)


if __name__ == "__main__":
    sys.exit(main())

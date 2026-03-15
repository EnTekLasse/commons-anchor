# Diagram Workspace

README is the primary diagram surface for this project.
The diagrams are embedded directly in README so they render with standard Markdown preview.

Central source-of-truth for system architecture, kanban, and tech-tree is:
- `docs/architecture/diagram-model.json`

Generated artifacts:
- `docs/architecture/diagrams/system-architecture.mmd`
- `docs/architecture/diagrams/project-kanban.mmd`
- `docs/architecture/diagrams/tech-tree.mmd`
- Embedded Mermaid blocks in `README.md`

## Files
- system-architecture.mmd
- project-kanban.mmd
- tech-tree.mmd

## Workflow
1. Edit `docs/architecture/diagram-model.json`.
2. Run `python scripts/generate_mermaid_from_model.py`.
3. Review generated changes in README and `.mmd` files.
4. Ensure CI Mermaid validation passes.

## VS Code preview quick steps
1. Open README and run Markdown preview (`Ctrl+Shift+V`).
2. For single-diagram editing, open any `.mmd` file and run `Mermaid: Open Preview`.
3. If preview does not appear, run `Developer: Reload Window`.
4. Confirm workspace uses `.vscode/settings.json` association for `*.mmd`.

## Why this structure
- Makes diagram rendering work with standard Markdown preview.
- Keeps architecture communication centralized in README.
- Keeps dependency and board data in one central model.

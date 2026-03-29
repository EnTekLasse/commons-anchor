# Test folder structure

Current rule:
- Keep `tests/` flat while the project has only a small number of test files.

When to introduce subfolders:
- Add `tests/unit/` and `tests/integration/` once test count grows (for example > 10 files) or responsibilities become mixed.
- Move files only when it improves discoverability and CI clarity.

Rationale:
- Flat structure is faster to navigate in early phases.
- Avoid premature hierarchy churn while scope is still evolving.

# Copilot Repository Instructions

These instructions apply to all Copilot-assisted work in this repository.

## Commit-Time Quality Gate

When preparing, validating, or finalizing changes for commit, always run and report the local quality gate using the workspace virtual environment.

Use this exact sequence from the repository root:

```powershell
.\.venv\Scripts\python.exe -m ruff format --check scripts tests
.\.venv\Scripts\python.exe -m ruff check scripts tests
.\.venv\Scripts\python.exe -m pyright --pythonpath .\.venv\Scripts\python.exe
.\.venv\Scripts\python.exe -m scripts.check_sql_syntax
.\.venv\Scripts\python.exe -m pytest -q
```

## Ruff Scope Rules

- Ruff must only be run against Python targets in this repo: `scripts` and `tests`.
- Do not run Ruff against Markdown, YAML, or workflow files.
- If formatting/linting is needed for non-Python files, use tools appropriate for those file types.

## Safety and Commit Hygiene

- Do not stage unrelated files.
- Keep commits focused and easy to review.
- If quality checks fail, fix issues first, then re-run the full gate before commit.

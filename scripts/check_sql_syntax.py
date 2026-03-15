from __future__ import annotations

import argparse
import sys
from pathlib import Path

from pglast import Error, parse_sql


def _line_col_from_position(text: str, position: int) -> tuple[int, int]:
    if position <= 0:
        return (1, 1)

    idx = min(position - 1, len(text))
    before = text[:idx]
    line = before.count("\n") + 1
    last_newline = before.rfind("\n")
    col = idx + 1 if last_newline == -1 else idx - last_newline
    return (line, col)


def _collect_sql_files(root: Path) -> list[Path]:
    return sorted(root.rglob("*.sql"))


def _check_file(path: Path) -> str | None:
    sql_text = path.read_text(encoding="utf-8")
    try:
        parse_sql(sql_text)
        return None
    except Error as exc:
        line = getattr(exc, "lineno", None)
        col = getattr(exc, "cursorpos", None)

        if line is None and isinstance(col, int):
            line, col = _line_col_from_position(sql_text, col)

        if line is None:
            return f"{path}: {exc}"
        if col is None:
            return f"{path}:{line}: {exc}"
        return f"{path}:{line}:{col}: {exc}"


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Validate PostgreSQL SQL syntax for all .sql files under a directory "
            "(default: infra/sql)."
        )
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=Path("infra/sql"),
        help="Directory to scan recursively for .sql files",
    )
    args = parser.parse_args()

    root = args.root
    if not root.exists():
        print(f"ERROR: root directory does not exist: {root}", file=sys.stderr)
        return 2

    sql_files = _collect_sql_files(root)
    if not sql_files:
        print(f"No SQL files found under {root}")
        return 0

    errors: list[str] = []
    for file_path in sql_files:
        err = _check_file(file_path)
        if err:
            errors.append(err)

    if errors:
        print("PostgreSQL SQL syntax check failed:\n")
        for err in errors:
            print(f"- {err}")
        return 1

    print(f"PostgreSQL SQL syntax check passed for {len(sql_files)} file(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

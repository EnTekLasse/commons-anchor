from __future__ import annotations

import importlib.util
import subprocess
import sys


def _run_step(label: str, args: list[str]) -> int:
    print(f"[quality-gate] {label}")
    completed = subprocess.run(args, check=False)
    if completed.returncode != 0:
        print(f"[quality-gate] failed: {label}")
        return completed.returncode
    print(f"[quality-gate] ok: {label}")
    return 0


def _missing_modules(modules: list[str]) -> list[str]:
    missing: list[str] = []
    for module in modules:
        if importlib.util.find_spec(module) is None:
            missing.append(module)
    return missing


def main() -> int:
    python = sys.executable
    required_modules = ["ruff", "pyright", "pytest", "pglast"]
    missing = _missing_modules(required_modules)
    if missing:
        names = ", ".join(missing)
        print(f"[quality-gate] missing Python modules: {names}")
        print("[quality-gate] install with: python -m pip install -e '.[dev]'")
        # Return a dedicated exit code so wrapper scripts can warn and continue.
        return 3

    steps: list[tuple[str, list[str]]] = [
        (
            "ruff format --check",
            [python, "-m", "ruff", "format", "--check", "scripts", "tests"],
        ),
        ("ruff check", [python, "-m", "ruff", "check", "scripts", "tests"]),
        (
            "pyright",
            [python, "-m", "pyright", "--pythonpath", python],
        ),
        ("check SQL syntax", [python, "-m", "scripts.check_sql_syntax"]),
        (
            "check Mermaid compile (changed-only)",
            [python, "-m", "scripts.check_mermaid_compile", "--changed-only"],
        ),
        ("pytest", [python, "-m", "pytest", "-q"]),
    ]

    for label, args in steps:
        code = _run_step(label, args)
        if code != 0:
            return code

    print("[quality-gate] all checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

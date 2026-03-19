from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DIAGRAMS_DIR = ROOT / "docs" / "architecture" / "diagrams"
README_PATH = ROOT / "README.md"


def _cli_base() -> list[str]:
    mmdc = shutil.which("mmdc")
    if mmdc:
        return [mmdc]

    npx = shutil.which("npx")
    if npx:
        return [npx, "--yes", "@mermaid-js/mermaid-cli"]

    raise SystemExit(
        "Mermaid CLI not found. Install Node.js and run 'npm install -g @mermaid-js/mermaid-cli' "
        "or ensure 'npx' is available."
    )


def _run(args: list[str]) -> int:
    completed = subprocess.run(args, check=False)
    return completed.returncode


def _changed_paths() -> set[Path]:
    # Include tracked modifications and untracked files.
    changed: set[Path] = set()

    tracked = subprocess.run(
        ["git", "diff", "--name-only", "HEAD"],
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    if tracked.returncode == 0:
        for line in tracked.stdout.splitlines():
            line = line.strip()
            if line:
                changed.add(ROOT / line)

    untracked = subprocess.run(
        ["git", "ls-files", "--others", "--exclude-standard"],
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    if untracked.returncode == 0:
        for line in untracked.stdout.splitlines():
            line = line.strip()
            if line:
                changed.add(ROOT / line)

    return changed


def _extract_readme_blocks(temp_dir: Path) -> list[Path]:
    blocks: list[Path] = []
    lines = README_PATH.read_text(encoding="utf-8").splitlines()
    in_block = False
    current: list[str] = []

    for line in lines:
        if line.strip().startswith("```mermaid"):
            in_block = True
            current = []
            continue
        if in_block and line.strip() == "```":
            in_block = False
            path = temp_dir / f"readme-mermaid-{len(blocks) + 1}.mmd"
            path.write_text("\n".join(current) + "\n", encoding="utf-8")
            blocks.append(path)
            continue
        if in_block:
            current.append(line)

    if not blocks:
        raise SystemExit("No Mermaid blocks found in README.md")
    return blocks


def _compile_mmd(src: Path, cli: list[str], out_dir: Path) -> int:
    out = out_dir / (src.stem + ".svg")
    cmd = [*cli, "-i", str(src), "-o", str(out)]
    try:
        display_path = str(src.relative_to(ROOT))
    except ValueError:
        display_path = str(src)
    print(f"[mermaid-check] validating {display_path}")
    return _run(cmd)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate Mermaid artifacts by compiling .mmd files and README Mermaid blocks."
    )
    parser.add_argument(
        "--changed-only",
        action="store_true",
        help="Validate only changed Mermaid files and README blocks when README.md changed.",
    )
    args = parser.parse_args()

    python = sys.executable
    sync_check = [python, "scripts/generate_mermaid_from_model.py", "--check"]
    if _run(sync_check) != 0:
        print("[mermaid-check] failed: artifacts are out of sync with diagram model")
        return 1

    cli = _cli_base()
    diagrams = sorted(DIAGRAMS_DIR.glob("*.mmd"))
    include_readme = True

    if args.changed_only:
        changed = _changed_paths()
        if changed:
            diagrams = [src for src in diagrams if src in changed]
            include_readme = README_PATH in changed
        else:
            diagrams = []
            include_readme = False

        if not diagrams and not include_readme:
            print("[mermaid-check] no Mermaid-related changes detected; skipping compile")
            return 0

    with tempfile.TemporaryDirectory() as td:
        temp_dir = Path(td)

        for src in diagrams:
            if _compile_mmd(src, cli, temp_dir) != 0:
                return 1

        if include_readme:
            for src in _extract_readme_blocks(temp_dir):
                if _compile_mmd(src, cli, temp_dir) != 0:
                    return 1

    print("[mermaid-check] all Mermaid files compiled successfully")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

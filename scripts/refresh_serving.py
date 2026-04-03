#!/usr/bin/env python3
"""Compatibility wrapper; use scripts/ingest/refresh_curated.py going forward."""

from scripts.ingest.refresh_curated import main


if __name__ == "__main__":
    raise SystemExit(main())

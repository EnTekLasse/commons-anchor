#!/usr/bin/env python3
"""Refresh curated materialized views with automatic secret resolution."""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path
from typing import Optional

try:
    import psycopg
except ImportError:
    print("ERROR: psycopg not installed. Run: pip install psycopg", file=sys.stderr)
    sys.exit(1)


def _read_secret_file(secret_path: str) -> Optional[str]:
    path = Path(secret_path)
    if not path.exists():
        return None
    value = path.read_text(encoding="utf-8").strip()
    return value or None


def resolve_password(cli_password: Optional[str], cli_password_file: Optional[str]) -> Optional[str]:
    if cli_password:
        return cli_password

    for env_name in ("POSTGRES_PASSWORD", "DW_PASSWORD"):
        env_value = os.environ.get(env_name)
        if env_value:
            return env_value

    file_candidates: list[str] = []
    if cli_password_file:
        file_candidates.append(cli_password_file)

    env_file = os.environ.get("POSTGRES_PASSWORD_FILE")
    if env_file:
        file_candidates.append(env_file)

    default_secret = Path(__file__).resolve().parents[2] / "infra" / "secrets" / "postgres_password.secret"
    file_candidates.append(str(default_secret))

    for secret_path in file_candidates:
        secret = _read_secret_file(secret_path)
        if secret:
            return secret

    return None


def get_db_connection(
    host: str = "127.0.0.1",
    port: int = 5432,
    database: str = "dw",
    user: str = "dw_admin",
    password: Optional[str] = None,
) -> psycopg.Connection:
    try:
        return psycopg.connect(
            host=host,
            port=port,
            dbname=database,
            user=user,
            password=password,
            connect_timeout=10,
        )
    except psycopg.OperationalError as exc:
        print(f"ERROR: Failed to connect to PostgreSQL: {exc}", file=sys.stderr)
        sys.exit(1)


def refresh_materialized_view(conn: psycopg.Connection, view_name: str) -> dict:
    cursor = conn.cursor()
    try:
        schema_name, object_name = view_name.split(".", 1)
        cursor.execute(
            """
            SELECT ispopulated
            FROM pg_matviews
            WHERE schemaname = %s
              AND matviewname = %s
            """,
            (schema_name, object_name),
        )
        row = cursor.fetchone()
        is_populated = bool(row[0]) if row is not None else False

        if is_populated:
            cursor.execute(f"REFRESH MATERIALIZED VIEW CONCURRENTLY {view_name};")
        else:
            cursor.execute(f"REFRESH MATERIALIZED VIEW {view_name};")

        cursor.execute(f"SELECT COUNT(*) FROM {view_name};")
        row_count = cursor.fetchone()[0]
        conn.commit()
        return {"status": "success", "view": view_name, "row_count": row_count, "error": None}
    except psycopg.errors.UndefinedTable as exc:
        conn.rollback()
        return {"status": "error", "view": view_name, "row_count": None, "error": f"View not found: {exc}"}
    except Exception as exc:  # noqa: BLE001
        conn.rollback()
        return {"status": "error", "view": view_name, "row_count": None, "error": str(exc)}
    finally:
        cursor.close()


def main() -> int:
    parser = argparse.ArgumentParser(description="Refresh curated materialized views")
    parser.add_argument("--view", type=str, default="all")
    parser.add_argument("--host", type=str, default="127.0.0.1")
    parser.add_argument("--port", type=int, default=5432)
    parser.add_argument("--db", type=str, default="dw")
    parser.add_argument("--user", type=str, default="dw_admin")
    parser.add_argument("--password", type=str, default=None)
    parser.add_argument("--password-file", type=str, default=None)
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    views = {
        "dmi_climate_temperature": "mart.dmi_climate_temperature_hourly",
        "power_price": "mart.power_price_15min",
    }
    if args.view.lower() == "all":
        views_to_refresh = list(views.values())
    elif args.view in views:
        views_to_refresh = [views[args.view]]
    elif args.view.startswith("mart.") or args.view.startswith("serving."):
        views_to_refresh = [args.view]
    else:
        print(f"ERROR: Unknown view '{args.view}'. Available: all, {', '.join(views.keys())}", file=sys.stderr)
        return 1

    if args.verbose:
        print(f"Connecting to {args.host}:{args.port}/{args.db}...")

    conn = get_db_connection(
        host=args.host,
        port=args.port,
        database=args.db,
        user=args.user,
        password=resolve_password(args.password, args.password_file),
    )

    if args.verbose:
        print("Connected ✓")

    results = []
    for view in views_to_refresh:
        if args.verbose:
            print(f"Refreshing {view}...", end="", flush=True)
        result = refresh_materialized_view(conn, view)
        results.append(result)
        if args.verbose:
            if result["status"] == "success":
                print(f" OK ({result['row_count']} rows)")
            else:
                print(f" ERROR: {result['error']}")

    conn.close()

    successes = [r for r in results if r["status"] == "success"]
    errors = [r for r in results if r["status"] == "error"]

    print(f"\n✓ {len(successes)} views refreshed")
    if errors:
        print(f"✗ {len(errors)} views had errors:")
        for err in errors:
            print(f"  - {err['view']}: {err['error']}")
        return 1

    if args.verbose:
        print("\nRefresh details:")
        for result in results:
            print(f"  {result['view']}: {result['row_count']} rows")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""
Refresh materialized views in the data warehouse.

Usage:
    python refresh_serving.py --view power_price_15min
    python refresh_serving.py --view all
    python refresh_serving.py --view all --db dw --host localhost

This replaces the old TRUNCATE + INSERT pattern with REFRESH MATERIALIZED VIEW.
"""

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

    # Common env names used across local/dev/server setups.
    for env_name in ("POSTGRES_PASSWORD", "DW_PASSWORD"):
        env_value = os.environ.get(env_name)
        if env_value:
            return env_value

    # File-based secret via CLI, env var, then repository default.
    file_candidates: list[str] = []
    if cli_password_file:
        file_candidates.append(cli_password_file)

    env_file = os.environ.get("POSTGRES_PASSWORD_FILE")
    if env_file:
        file_candidates.append(env_file)

    default_secret = Path(__file__).resolve().parents[1] / "infra" / "secrets" / "postgres_password.secret"
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
    """
    Create a PostgreSQL connection.

    Password can be provided via:
    1. --password argument
    2. DW_PASSWORD env var
    3. ~/.pgpass file
    4. Interactive prompt
    """
    try:
        conn = psycopg.connect(
            host=host,
            port=port,
            dbname=database,
            user=user,
            password=password,
            connect_timeout=10,
        )
        return conn
    except psycopg.OperationalError as e:
        print(f"ERROR: Failed to connect to PostgreSQL: {e}", file=sys.stderr)
        sys.exit(1)


def refresh_materialized_view(conn: psycopg.Connection, view_name: str) -> dict:
    """
    Refresh a single materialized view.

    Args:
        conn: PostgreSQL connection
        view_name: Full view name (e.g., 'mart.power_price_15min')

    Returns:
        dict with status, row_count, and error (if any)
    """
    cursor = conn.cursor()
    
    try:
        # Use CONCURRENTLY to avoid locking reads
        cursor.execute(f"REFRESH MATERIALIZED VIEW CONCURRENTLY {view_name};")
        
        # Get row count
        schema, view = view_name.split(".")
        cursor.execute(f"SELECT COUNT(*) FROM {view_name};")
        row_count = cursor.fetchone()[0]
        
        conn.commit()
        
        return {
            "status": "success",
            "view": view_name,
            "row_count": row_count,
            "error": None,
        }
    except psycopg.errors.UndefinedTable as e:
        conn.rollback()
        return {
            "status": "error",
            "view": view_name,
            "row_count": None,
            "error": f"View not found: {e}",
        }
    except Exception as e:
        conn.rollback()
        return {
            "status": "error",
            "view": view_name,
            "row_count": None,
            "error": str(e),
        }
    finally:
        cursor.close()


def main():
    parser = argparse.ArgumentParser(
        description="Refresh data warehouse materialized views",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Refresh single view
  python refresh_serving.py --view mart.power_price_15min
  
  # Refresh all serving views
  python refresh_serving.py --view all
  
  # Use environment variables for credentials
  export DW_PASSWORD=my_password
  python refresh_serving.py --view all --host db.production.example.com

    # Use secret file (no manual password)
    python refresh_serving.py --view all --password-file ./infra/secrets/postgres_password.secret
        """,
    )
    
    parser.add_argument(
        "--view",
        type=str,
        default="all",
        help="View to refresh: 'all', 'mart.power_price_15min', etc. (default: all)",
    )
    parser.add_argument(
        "--host", type=str, default="127.0.0.1", help="Database host (default: 127.0.0.1)"
    )
    parser.add_argument("--port", type=int, default=5432, help="Database port (default: 5432)")
    parser.add_argument("--db", type=str, default="dw", help="Database name (default: dw)")
    parser.add_argument(
        "--user", type=str, default="dw_admin", help="Database user (default: dw_admin)"
    )
    parser.add_argument(
        "--password",
        type=str,
        default=None,
        help="Database password (or use POSTGRES_PASSWORD / DW_PASSWORD)",
    )
    parser.add_argument(
        "--password-file",
        type=str,
        default=None,
        help="Path to password file (falls back to POSTGRES_PASSWORD_FILE or infra/secrets/postgres_password.secret)",
    )
    parser.add_argument(
        "--verbose", action="store_true", help="Show detailed output"
    )
    
    args = parser.parse_args()
    
    # Map of view names
    VIEWS = {
        "power_price": "mart.power_price_15min",
    }
    
    # Determine which views to refresh
    if args.view.lower() == "all":
        views_to_refresh = list(VIEWS.values())
    elif args.view in VIEWS:
        views_to_refresh = [VIEWS[args.view]]
    elif args.view.startswith("mart.") or args.view.startswith("serving."):
        views_to_refresh = [args.view]
    else:
        print(f"ERROR: Unknown view '{args.view}'", file=sys.stderr)
        print(f"Available: all, {', '.join(VIEWS.keys())}", file=sys.stderr)
        sys.exit(1)
    
    # Connect
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
    
    # Refresh views
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
    
    # Summary
    successes = [r for r in results if r["status"] == "success"]
    errors = [r for r in results if r["status"] == "error"]
    
    print(f"\n✓ {len(successes)} views refreshed")
    if errors:
        print(f"✗ {len(errors)} views had errors:")
        for err in errors:
            print(f"  - {err['view']}: {err['error']}")
        sys.exit(1)
    
    # Detailed output
    if args.verbose:
        print("\nRefresh details:")
        for r in results:
            if r["status"] == "success":
                print(f"  {r['view']}: {r['row_count']} rows")
    
    conn.close()


if __name__ == "__main__":
    main()

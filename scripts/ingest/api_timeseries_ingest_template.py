from __future__ import annotations

import argparse
import os
from dataclasses import dataclass
from typing import Any

import psycopg
import requests
from psycopg.types.json import Jsonb


@dataclass(frozen=True)
class Settings:
    source_name: str
    api_url: str
    start: str
    end: str | None
    limit: int
    db_host: str
    db_port: int
    db_name: str
    db_user: str
    db_password: str
    db_connect_timeout: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Template: fetch generic API time series and upsert into PostgreSQL raw layer.",
    )
    parser.add_argument("--source-name")
    parser.add_argument("--api-url")
    parser.add_argument("--start")
    parser.add_argument("--end")
    parser.add_argument("--limit", type=int)
    parser.add_argument("--db-host")
    parser.add_argument("--db-port", type=int)
    parser.add_argument("--db-name")
    parser.add_argument("--db-user")
    parser.add_argument("--db-password")
    parser.add_argument("--db-connect-timeout", type=int)
    return parser.parse_args()


def load_settings(args: argparse.Namespace) -> Settings:
    db_password = args.db_password or os.getenv("POSTGRES_PASSWORD")
    if not db_password:
        raise SystemExit("POSTGRES_PASSWORD or --db-password must be set.")

    return Settings(
        source_name=args.source_name or os.getenv("GENERIC_SOURCE_NAME", "weather_api"),
        api_url=args.api_url or os.getenv("GENERIC_API_URL", "https://example.com/timeseries"),
        start=args.start or os.getenv("GENERIC_API_START", "now-PT24H"),
        end=args.end or os.getenv("GENERIC_API_END") or None,
        limit=(args.limit if args.limit is not None else int(os.getenv("GENERIC_API_LIMIT", "500"))),
        db_host=args.db_host or os.getenv("DW_HOST", "127.0.0.1"),
        db_port=args.db_port or int(os.getenv("DW_PORT", "5432")),
        db_name=args.db_name or os.getenv("POSTGRES_DB", "dw"),
        db_user=args.db_user or os.getenv("POSTGRES_USER", "dw_admin"),
        db_password=db_password,
        db_connect_timeout=(
            args.db_connect_timeout
            if args.db_connect_timeout is not None
            else int(os.getenv("DW_CONNECT_TIMEOUT", "10"))
        ),
    )


def fetch_records(settings: Settings) -> list[dict[str, Any]]:
    # Replace params/headers with the target API contract.
    response = requests.get(
        settings.api_url,
        params={"start": settings.start, "end": settings.end, "limit": settings.limit},
        timeout=30,
    )
    response.raise_for_status()

    payload = response.json()
    records = payload.get("records", payload)
    if not isinstance(records, list):
        raise SystemExit("Expected JSON array or object with 'records' array.")
    return records


def build_raw_rows(settings: Settings, records: list[dict[str, Any]]) -> list[tuple[Any, ...]]:
    rows: list[tuple[Any, ...]] = []
    for record in records:
        # TODO: map source-specific id and timestamp fields.
        source_key = record.get("id")
        source_time_text = record.get("timestamp")

        if source_key is None or source_time_text is None:
            continue

        rows.append(
            (
                settings.source_name,
                str(source_key),
                str(source_time_text),
                Jsonb(record),
            )
        )
    return rows


def write_records(settings: Settings, rows: list[tuple[Any, ...]]) -> None:
    if not rows:
        return

    with psycopg.connect(
        host=settings.db_host,
        port=settings.db_port,
        dbname=settings.db_name,
        user=settings.db_user,
        password=settings.db_password,
        connect_timeout=settings.db_connect_timeout,
    ) as connection:
        with connection.cursor() as cursor:
            cursor.executemany(
                """
                INSERT INTO staging.api_timeseries_raw (
                    source_name,
                    source_key,
                    source_time_text,
                    record
                )
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (source_name, source_key, source_time_text)
                DO UPDATE SET
                    record = EXCLUDED.record,
                    ingested_at = NOW()
                """,
                rows,
            )
        connection.commit()


def main() -> int:
    args = parse_args()
    settings = load_settings(args)
    records = fetch_records(settings)
    rows = build_raw_rows(settings, records)
    write_records(settings, rows)
    print(
        f"Ingested {len(rows)} rows for {settings.source_name} into "
        f"{settings.db_name}@{settings.db_host}:{settings.db_port}."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

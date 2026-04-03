from __future__ import annotations

import argparse
import os
from dataclasses import dataclass
from typing import Any

import psycopg
import requests
from psycopg.types.json import Jsonb


API_URL = "https://opendataapi.dmi.dk/v2/climateData/collections/municipalityValue/items"


@dataclass(frozen=True)
class Settings:
    municipality_id: str
    parameter_id: str
    time_resolution: str
    start: str
    end: str | None
    limit: int
    since_latest: bool
    db_host: str
    db_port: int
    db_name: str
    db_user: str
    db_password: str
    db_connect_timeout: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Fetch DMI Climate municipality values and upsert them into PostgreSQL raw layer.",
    )
    parser.add_argument("--municipality-id")
    parser.add_argument("--parameter-id")
    parser.add_argument("--time-resolution")
    parser.add_argument("--start")
    parser.add_argument("--end")
    parser.add_argument("--limit", type=int)
    parser.add_argument("--since-latest", action="store_true")
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

    municipality_id = args.municipality_id or os.getenv("DMI_CLIMATE_MUNICIPALITY_ID", "0265")
    if len(municipality_id) == 3:
        municipality_id = f"0{municipality_id}"

    return Settings(
        municipality_id=municipality_id,
        parameter_id=args.parameter_id or os.getenv("DMI_CLIMATE_PARAMETER_ID", "mean_temp"),
        time_resolution=args.time_resolution or os.getenv("DMI_CLIMATE_TIME_RESOLUTION", "hour"),
        start=args.start or os.getenv("DMI_CLIMATE_START", "2024-01-01T00:00:00Z"),
        end=args.end or os.getenv("DMI_CLIMATE_END") or None,
        limit=(args.limit if args.limit is not None else int(os.getenv("DMI_CLIMATE_LIMIT", "500"))),
        since_latest=args.since_latest or os.getenv("DMI_CLIMATE_SINCE_LATEST", "0") == "1",
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


def build_request_params(settings: Settings) -> dict[str, str]:
    params = {
        "municipalityId": settings.municipality_id,
        "parameterId": settings.parameter_id,
        "timeResolution": settings.time_resolution,
        "limit": str(settings.limit),
    }

    if settings.end:
        params["datetime"] = f"{settings.start}/{settings.end}"
    else:
        params["datetime"] = f"{settings.start}/.."

    return params


def resolve_incremental_start(settings: Settings) -> str:
    with psycopg.connect(
        host=settings.db_host,
        port=settings.db_port,
        dbname=settings.db_name,
        user=settings.db_user,
        password=settings.db_password,
        connect_timeout=settings.db_connect_timeout,
    ) as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT MAX(source_time_text)
                FROM staging.dmi_climate_raw
                WHERE municipality_id = %s
                  AND parameter_id = %s
                  AND time_resolution = %s
                """,
                (settings.municipality_id, settings.parameter_id, settings.time_resolution),
            )
            row = cursor.fetchone()

    if row is None or row[0] is None:
        return settings.start

    return str(row[0])


def fetch_records(settings: Settings) -> list[dict[str, Any]]:
    request_settings = settings
    if settings.since_latest:
        request_settings = Settings(
            municipality_id=settings.municipality_id,
            parameter_id=settings.parameter_id,
            time_resolution=settings.time_resolution,
            start=resolve_incremental_start(settings),
            end=settings.end,
            limit=settings.limit,
            since_latest=settings.since_latest,
            db_host=settings.db_host,
            db_port=settings.db_port,
            db_name=settings.db_name,
            db_user=settings.db_user,
            db_password=settings.db_password,
            db_connect_timeout=settings.db_connect_timeout,
        )

    response = requests.get(API_URL, params=build_request_params(request_settings), timeout=30)
    response.raise_for_status()
    payload = response.json()
    records = payload.get("features")
    if not isinstance(records, list):
        raise SystemExit("DMI Climate response did not contain a features array.")
    return records


def build_raw_rows(settings: Settings, records: list[dict[str, Any]]) -> list[tuple[Any, ...]]:
    rows: list[tuple[Any, ...]] = []
    for feature in records:
        properties = feature.get("properties", {})
        feature_id = feature.get("id")
        from_ts = properties.get("from")
        municipality_name = properties.get("municipalityName")

        if feature_id is None or from_ts is None or municipality_name is None:
            continue

        rows.append(
            (
                settings.municipality_id,
                str(municipality_name),
                settings.parameter_id,
                settings.time_resolution,
                str(feature_id),
                str(from_ts),
                Jsonb(feature),
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
                INSERT INTO staging.dmi_climate_raw (
                    municipality_id,
                    municipality_name,
                    parameter_id,
                    time_resolution,
                    source_key,
                    source_time_text,
                    record
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (municipality_id, parameter_id, time_resolution, source_key, source_time_text)
                DO UPDATE SET
                    municipality_name = EXCLUDED.municipality_name,
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
        f"Ingested {len(rows)} DMI Climate rows for municipality {settings.municipality_id} "
        f"and parameter {settings.parameter_id} into {settings.db_name}@{settings.db_host}:{settings.db_port} "
        f"(since_latest={settings.since_latest})."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

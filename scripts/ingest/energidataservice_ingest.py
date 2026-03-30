from __future__ import annotations

import argparse
import json
import os
from dataclasses import dataclass
from datetime import UTC, datetime
from decimal import Decimal
from typing import Any

import psycopg
import requests
from psycopg.types.json import Jsonb


@dataclass(frozen=True)
class DatasetSpec:
    time_column: str
    price_column: str


DATASET_SPECS: dict[str, DatasetSpec] = {
    "DayAheadPrices": DatasetSpec(time_column="TimeUTC", price_column="DayAheadPriceDKK"),
    "Elspotprices": DatasetSpec(time_column="HourUTC", price_column="SpotPriceDKK"),
}


@dataclass(frozen=True)
class Settings:
    dataset: str
    start: str
    end: str | None
    price_areas: tuple[str, ...]
    limit: int
    api_base_url: str
    db_host: str
    db_port: int
    db_name: str
    db_user: str
    db_password: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Fetch Energi Data Service prices and upsert them into PostgreSQL.",
    )
    parser.add_argument("--dataset")
    parser.add_argument("--start")
    parser.add_argument("--end")
    parser.add_argument("--price-areas")
    parser.add_argument("--limit", type=int)
    parser.add_argument("--db-host")
    parser.add_argument("--db-port", type=int)
    parser.add_argument("--db-name")
    parser.add_argument("--db-user")
    parser.add_argument("--db-password")
    return parser.parse_args()


def load_settings(args: argparse.Namespace) -> Settings:
    dataset = args.dataset or os.getenv("ENERGIDATASERVICE_DATASET", "DayAheadPrices")
    if dataset not in DATASET_SPECS:
        supported_datasets = ", ".join(sorted(DATASET_SPECS))
        raise SystemExit(f"Unsupported dataset '{dataset}'. Supported values: {supported_datasets}")

    price_areas_value = args.price_areas or os.getenv("ENERGIDATASERVICE_PRICE_AREAS", "DK1,DK2")
    price_areas = tuple(area.strip() for area in price_areas_value.split(",") if area.strip())
    if not price_areas:
        raise SystemExit("At least one price area is required.")

    db_name = args.db_name or os.getenv("POSTGRES_DB", "dw")
    db_user = args.db_user or os.getenv("POSTGRES_USER", "dw_admin")
    db_password = args.db_password or os.getenv("POSTGRES_PASSWORD")
    if not db_password:
        raise SystemExit("POSTGRES_PASSWORD or --db-password must be set.")

    return Settings(
        dataset=dataset,
        start=args.start or os.getenv("ENERGIDATASERVICE_START", "now-P2D"),
        end=args.end or os.getenv("ENERGIDATASERVICE_END") or None,
        price_areas=price_areas,
        limit=(
            args.limit if args.limit is not None else int(os.getenv("ENERGIDATASERVICE_LIMIT", "0"))
        ),
        api_base_url="https://api.energidataservice.dk/dataset",
        db_host=args.db_host or os.getenv("DW_HOST", "localhost"),
        db_port=args.db_port or int(os.getenv("DW_PORT", "5432")),
        db_name=db_name,
        db_user=db_user,
        db_password=db_password,
    )


def build_request_params(settings: Settings) -> dict[str, str]:
    spec = DATASET_SPECS[settings.dataset]
    params = {
        "start": settings.start,
        "filter": json.dumps({"PriceArea": list(settings.price_areas)}, separators=(",", ":")),
        "columns": f"{spec.time_column},PriceArea,{spec.price_column}",
        "sort": f"{spec.time_column} asc,PriceArea",
        "timezone": "UTC",
        "limit": str(settings.limit),
    }
    if settings.end:
        params["end"] = settings.end
    return params


def fetch_records(settings: Settings) -> list[dict[str, Any]]:
    response = requests.get(
        f"{settings.api_base_url}/{settings.dataset}",
        params=build_request_params(settings),
        timeout=30,
    )
    response.raise_for_status()
    payload = response.json()
    records = payload.get("records")
    if not isinstance(records, list):
        raise SystemExit("Energi Data Service response did not contain a records array.")
    return records


def parse_utc_timestamp(value: str) -> datetime:
    parsed = datetime.fromisoformat(value)
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=UTC)
    return parsed.astimezone(UTC)


def normalize_records(settings: Settings, records: list[dict[str, Any]]) -> list[tuple[Any, ...]]:
    # Price precision policy: API values are converted via str() before Decimal
    # to avoid float rounding errors. DB column is NUMERIC(12, 4).
    # Null prices are skipped: the API occasionally omits prices for future hours.
    spec = DATASET_SPECS[settings.dataset]
    normalized_rows: list[tuple[Any, ...]] = []
    for record in records:
        raw_price = record[spec.price_column]
        if raw_price is None:
            continue
        normalized_rows.append(
            (
                settings.dataset,
                str(record["PriceArea"]),
                Decimal(str(raw_price)),
                parse_utc_timestamp(str(record[spec.time_column])),
                Jsonb(record),
            )
        )
    return normalized_rows


def write_records(settings: Settings, rows: list[tuple[Any, ...]]) -> None:
    if not rows:
        return

    with psycopg.connect(
        host=settings.db_host,
        port=settings.db_port,
        dbname=settings.db_name,
        user=settings.db_user,
        password=settings.db_password,
    ) as connection:
        with connection.cursor() as cursor:
            cursor.executemany(
                """
                INSERT INTO staging.energinet_raw (
                    dataset,
                    area,
                    price_dkk_mwh,
                    ts_utc,
                    payload
                )
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT (dataset, area, ts_utc)
                DO UPDATE SET
                    price_dkk_mwh = EXCLUDED.price_dkk_mwh,
                    payload = EXCLUDED.payload,
                    ingested_at = NOW()
                """,
                rows,
            )
        connection.commit()


def main() -> int:
    args = parse_args()
    settings = load_settings(args)
    records = fetch_records(settings)
    rows = normalize_records(settings, records)
    write_records(settings, rows)
    print(
        f"Ingested {len(rows)} rows from {settings.dataset} into "
        f"{settings.db_name}@{settings.db_host}:{settings.db_port}."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

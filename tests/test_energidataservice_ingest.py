from argparse import Namespace

from scripts.ingest.energidataservice_ingest import (
    build_raw_rows,
    build_request_params,
    load_settings,
)


def test_load_settings_defaults(monkeypatch):
    monkeypatch.setenv("POSTGRES_PASSWORD", "secret")
    args = Namespace(
        dataset=None,
        start=None,
        end=None,
        price_areas=None,
        limit=None,
        db_host=None,
        db_port=None,
        db_name=None,
        db_user=None,
        db_password=None,
    )

    settings = load_settings(args)

    assert settings.dataset == "DayAheadPrices"
    assert settings.price_areas == ("DK1", "DK2")
    assert settings.db_host == "localhost"
    assert settings.limit == 0


def test_build_request_params_uses_dataset_specific_columns(monkeypatch):
    monkeypatch.setenv("POSTGRES_PASSWORD", "secret")
    monkeypatch.setenv("ENERGIDATASERVICE_DATASET", "Elspotprices")
    args = Namespace(
        dataset=None,
        start=None,
        end=None,
        price_areas=None,
        limit=None,
        db_host=None,
        db_port=None,
        db_name=None,
        db_user=None,
        db_password=None,
    )

    settings = load_settings(args)
    params = build_request_params(settings)

    assert params["columns"] == "HourUTC,PriceArea,SpotPriceDKK"
    assert params["timezone"] == "UTC"


def test_build_raw_rows_keeps_null_price_in_source_record(monkeypatch):
    monkeypatch.setenv("POSTGRES_PASSWORD", "secret")
    args = Namespace(
        dataset="DayAheadPrices",
        start=None,
        end=None,
        price_areas="DK1",
        limit=None,
        db_host=None,
        db_port=None,
        db_name=None,
        db_user=None,
        db_password=None,
    )

    settings = load_settings(args)
    rows = build_raw_rows(
        settings,
        [
            {
                "PriceArea": "DK1",
                "TimeUTC": "2026-03-16T22:00:00",
                "DayAheadPriceDKK": None,
            }
        ],
    )

    dataset, price_area, source_time_text, payload = rows[0]
    assert dataset == "DayAheadPrices"
    assert price_area == "DK1"
    assert source_time_text == "2026-03-16T22:00:00"
    assert payload.obj["DayAheadPriceDKK"] is None


def test_build_raw_rows_preserves_source_timestamp_and_price(monkeypatch):
    monkeypatch.setenv("POSTGRES_PASSWORD", "secret")
    args = Namespace(
        dataset="DayAheadPrices",
        start=None,
        end=None,
        price_areas="DK1",
        limit=None,
        db_host=None,
        db_port=None,
        db_name=None,
        db_user=None,
        db_password=None,
    )

    settings = load_settings(args)
    rows = build_raw_rows(
        settings,
        [
            {
                "PriceArea": "DK1",
                "TimeUTC": "2026-03-16T22:00:00",
                "DayAheadPriceDKK": 834.47,
            }
        ],
    )

    dataset, area, source_time_text, payload = rows[0]
    assert dataset == "DayAheadPrices"
    assert area == "DK1"
    assert source_time_text == "2026-03-16T22:00:00"
    assert payload.obj["DayAheadPriceDKK"] == 834.47

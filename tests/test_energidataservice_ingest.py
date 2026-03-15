from datetime import UTC, datetime
from types import SimpleNamespace

from scripts.energidataservice_ingest import build_request_params, load_settings, normalize_records


def test_load_settings_defaults(monkeypatch):
    monkeypatch.setenv("POSTGRES_PASSWORD", "secret")
    args = SimpleNamespace(
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
    args = SimpleNamespace(
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


def test_normalize_records_converts_timestamp_and_price(monkeypatch):
    monkeypatch.setenv("POSTGRES_PASSWORD", "secret")
    args = SimpleNamespace(
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
    rows = normalize_records(
        settings,
        [
            {
                "PriceArea": "DK1",
                "TimeUTC": "2026-03-16T22:00:00",
                "DayAheadPriceDKK": 834.47,
            }
        ],
    )

    dataset, area, price, ts_utc, _payload = rows[0]
    assert dataset == "DayAheadPrices"
    assert area == "DK1"
    assert str(price) == "834.47"
    assert ts_utc == datetime(2026, 3, 16, 22, 0, tzinfo=UTC)

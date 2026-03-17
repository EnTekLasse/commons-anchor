from types import SimpleNamespace

import pytest
from scripts.mqtt_ingest import decode_payload, load_settings


def test_load_settings_defaults(monkeypatch):
    monkeypatch.setenv("POSTGRES_PASSWORD", "secret")
    args = SimpleNamespace(
        mqtt_host=None,
        mqtt_port=None,
        mqtt_topic=None,
        mqtt_source=None,
        db_host=None,
        db_port=None,
        db_name=None,
        db_user=None,
        db_password=None,
    )

    settings = load_settings(args)

    assert settings.mqtt_host == "localhost"
    assert settings.mqtt_port == 1883
    assert settings.mqtt_topic == "ca/dev/+/telemetry"
    assert settings.mqtt_source == "phone_or_esp32"


def test_decode_payload_json_object():
    payload = decode_payload(b'{"device_id":"phone01","temp_c":22.4}')
    assert payload["device_id"] == "phone01"
    assert payload["temp_c"] == 22.4


def test_decode_payload_invalid_json_raises():
    with pytest.raises(ValueError):
        decode_payload(b"not-json")
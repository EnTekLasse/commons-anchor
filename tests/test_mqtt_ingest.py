from types import SimpleNamespace

import pytest
from scripts.mqtt_ingest import decode_payload, load_settings, validate_payload


def test_load_settings_defaults(monkeypatch):
    monkeypatch.setenv("POSTGRES_PASSWORD", "secret")
    args = SimpleNamespace(
        mqtt_host=None,
        mqtt_port=None,
        mqtt_topic=None,
        mqtt_qos=None,
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
    assert settings.mqtt_qos == 1
    assert settings.mqtt_source == "phone_or_esp32"


def test_load_settings_rejects_invalid_qos(monkeypatch):
    monkeypatch.setenv("POSTGRES_PASSWORD", "secret")
    monkeypatch.setenv("MQTT_QOS", "3")
    args = SimpleNamespace(
        mqtt_host=None,
        mqtt_port=None,
        mqtt_topic=None,
        mqtt_qos=None,
        mqtt_source=None,
        db_host=None,
        db_port=None,
        db_name=None,
        db_user=None,
        db_password=None,
    )

    with pytest.raises(SystemExit):
        load_settings(args)


def test_decode_payload_json_object():
    payload = decode_payload(b'{"device_id":"phone01","temp_c":22.4}')
    assert payload["device_id"] == "phone01"
    assert payload["temp_c"] == 22.4


def test_decode_payload_invalid_json_raises():
    with pytest.raises(ValueError):
        decode_payload(b"not-json")


def test_validate_payload_accepts_expected_fields():
    payload = {
        "device_id": "phone01",
        "temp_c": 22.4,
        "hum_pct": 41.2,
        "ts": "2026-03-17T20:30:00Z",
    }

    validated = validate_payload(payload)
    assert validated["device_id"] == "phone01"


def test_validate_payload_rejects_missing_device_id():
    with pytest.raises(ValueError):
        validate_payload({"ts": "2026-03-17T20:30:00Z"})


def test_validate_payload_rejects_invalid_timestamp():
    with pytest.raises(ValueError):
        validate_payload({"device_id": "phone01", "ts": "not-a-time"})
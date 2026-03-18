from argparse import Namespace

import psycopg
import pytest
from scripts.mqtt_ingest import (
    DatabaseWriter,
    Settings,
    decode_payload,
    load_settings,
    validate_payload,
)


class _FakeCursor:
    def __init__(self, connection: "_FakeConnection") -> None:
        self._connection = connection

    def __enter__(self) -> "_FakeCursor":
        return self

    def __exit__(self, exc_type, exc, tb) -> bool:
        return False

    def execute(self, _query: str, _params: tuple[object, ...]) -> None:
        if self._connection.errors:
            error = self._connection.errors.pop(0)
            if error is not None:
                raise error


class _FakeConnection:
    def __init__(self, errors: list[Exception | None]) -> None:
        self.errors = errors
        self.closed = False
        self.commit_count = 0

    def cursor(self) -> _FakeCursor:
        return _FakeCursor(self)

    def commit(self) -> None:
        self.commit_count += 1

    def close(self) -> None:
        self.closed = True


def _build_settings() -> Settings:
    return Settings(
        mqtt_host="localhost",
        mqtt_port=1883,
        mqtt_topic="ca/dev/+/telemetry",
        mqtt_qos=1,
        mqtt_source="phone_or_esp32",
        db_host="localhost",
        db_port=5432,
        db_name="dw",
        db_user="dw_admin",
        db_password="secret",
    )


def test_load_settings_defaults(monkeypatch):
    monkeypatch.setenv("POSTGRES_PASSWORD", "secret")
    args = Namespace(
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
    args = Namespace(
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


def test_connection_error_classifier_is_precise():
    assert DatabaseWriter._is_connection_error(psycopg.OperationalError("dropped"))
    assert DatabaseWriter._is_connection_error(psycopg.InterfaceError("disconnected"))
    assert not DatabaseWriter._is_connection_error(psycopg.DatabaseError("constraint"))


def test_insert_row_retries_once_on_connection_error(monkeypatch):
    writer = DatabaseWriter(_build_settings())
    first_connection = _FakeConnection([psycopg.OperationalError("connection dropped")])
    second_connection = _FakeConnection([None])
    writer.connection = first_connection

    def fake_connect() -> None:
        writer.connection = second_connection

    monkeypatch.setattr(writer, "connect", fake_connect)

    writer.insert_row(
        topic="ca/dev/phone01/telemetry",
        payload={"device_id": "phone01", "ts": "2026-03-17T20:30:00Z"},
        source="phone_or_esp32",
    )

    assert first_connection.closed
    assert second_connection.commit_count == 1


def test_insert_row_raises_non_connection_psycopg_error(monkeypatch):
    writer = DatabaseWriter(_build_settings())
    first_connection = _FakeConnection([psycopg.DatabaseError("invalid row")])
    writer.connection = first_connection

    def fail_if_reconnect() -> None:
        raise AssertionError("connect should not be called for non-connection errors")

    monkeypatch.setattr(writer, "connect", fail_if_reconnect)

    with pytest.raises(psycopg.DatabaseError):
        writer.insert_row(
            topic="ca/dev/phone01/telemetry",
            payload={"device_id": "phone01", "ts": "2026-03-17T20:30:00Z"},
            source="phone_or_esp32",
        )

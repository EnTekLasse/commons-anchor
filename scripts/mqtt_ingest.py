from __future__ import annotations

import argparse
import json
import os
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

import paho.mqtt.client as mqtt


@dataclass(frozen=True)
class Settings:
    mqtt_host: str
    mqtt_port: int
    mqtt_topic: str
    mqtt_qos: int
    mqtt_source: str
    db_host: str
    db_port: int
    db_name: str
    db_user: str
    db_password: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Subscribe to MQTT telemetry and write payloads to "
            "PostgreSQL staging.mqtt_raw."
        ),
    )
    parser.add_argument("--mqtt-host")
    parser.add_argument("--mqtt-port", type=int)
    parser.add_argument("--mqtt-topic")
    parser.add_argument("--mqtt-qos", type=int)
    parser.add_argument("--mqtt-source")
    parser.add_argument("--db-host")
    parser.add_argument("--db-port", type=int)
    parser.add_argument("--db-name")
    parser.add_argument("--db-user")
    parser.add_argument("--db-password")
    return parser.parse_args()


def load_settings(args: argparse.Namespace) -> Settings:
    db_name = args.db_name or os.getenv("POSTGRES_DB", "dw")
    db_user = args.db_user or os.getenv("POSTGRES_USER", "dw_admin")
    db_password = args.db_password or os.getenv("POSTGRES_PASSWORD")
    if not db_password:
        raise SystemExit("POSTGRES_PASSWORD or --db-password must be set.")

    mqtt_qos = args.mqtt_qos if args.mqtt_qos is not None else int(os.getenv("MQTT_QOS", "1"))
    if mqtt_qos not in (0, 1, 2):
        raise SystemExit("MQTT_QOS must be one of 0, 1, or 2.")

    return Settings(
        mqtt_host=args.mqtt_host or os.getenv("MQTT_HOST", "localhost"),
        mqtt_port=args.mqtt_port or int(os.getenv("MQTT_PORT", "1883")),
        mqtt_topic=args.mqtt_topic or os.getenv("MQTT_TOPIC", "ca/dev/+/telemetry"),
        mqtt_qos=mqtt_qos,
        mqtt_source=args.mqtt_source or os.getenv("MQTT_SOURCE", "phone_or_esp32"),
        db_host=args.db_host or os.getenv("DW_HOST", "localhost"),
        db_port=args.db_port or int(os.getenv("DW_PORT", "5432")),
        db_name=db_name,
        db_user=db_user,
        db_password=db_password,
    )


def decode_payload(payload_bytes: bytes) -> Any:
    payload_text = payload_bytes.decode("utf-8")
    return json.loads(payload_text)


def validate_payload(payload: Any) -> dict[str, Any]:
    if not isinstance(payload, dict):
        raise ValueError("Payload must be a JSON object.")

    device_id = payload.get("device_id")
    if not isinstance(device_id, str) or not device_id.strip():
        raise ValueError("Payload field 'device_id' must be a non-empty string.")

    timestamp_raw = payload.get("ts")
    if not isinstance(timestamp_raw, str) or not timestamp_raw.strip():
        raise ValueError("Payload field 'ts' must be a non-empty string.")

    ts_value = timestamp_raw.replace("Z", "+00:00")
    parsed = datetime.fromisoformat(ts_value)
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=UTC)

    return payload


class DatabaseWriter:
    def __init__(self, settings: Settings):
        self.settings = settings
        self.connection: Any | None = None

    def connect(self) -> None:
        import psycopg

        self.connection = psycopg.connect(
            host=self.settings.db_host,
            port=self.settings.db_port,
            dbname=self.settings.db_name,
            user=self.settings.db_user,
            password=self.settings.db_password,
        )

    def close(self) -> None:
        if self.connection is not None and not self.connection.closed:
            self.connection.close()

    def insert_row(self, *, topic: str, payload: dict[str, Any], source: str) -> None:
        from psycopg.types.json import Jsonb

        if self.connection is None or self.connection.closed:
            self.connect()

        try:
            assert self.connection is not None
            with self.connection.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO staging.mqtt_raw (topic, payload, source)
                    VALUES (%s, %s, %s)
                    """,
                    (topic, Jsonb(payload), source),
                )
            self.connection.commit()
        except Exception:
            # Reconnect once in case the database connection dropped in a long-running worker.
            self.close()
            self.connect()
            assert self.connection is not None
            with self.connection.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO staging.mqtt_raw (topic, payload, source)
                    VALUES (%s, %s, %s)
                    """,
                    (topic, Jsonb(payload), source),
                )
            self.connection.commit()


def run(settings: Settings) -> None:
    print(
        f"Connecting MQTT ingest worker to {settings.mqtt_host}:{settings.mqtt_port} "
        f"topic '{settings.mqtt_topic}' and writing to "
        f"{settings.db_name}@{settings.db_host}:{settings.db_port}."
    )

    writer = DatabaseWriter(settings)
    writer.connect()
    try:
        client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
        client.reconnect_delay_set(min_delay=1, max_delay=30)

        def on_connect(
            mqtt_client: mqtt.Client,
            _userdata: Any,
            _flags: dict[str, Any],
            reason_code: mqtt.ReasonCode,
            _properties: mqtt.Properties | None,
        ) -> None:
            if reason_code.is_failure:
                print(f"MQTT connect failed: {reason_code}")
                return
            print(f"MQTT connected, subscribing to {settings.mqtt_topic}")
            mqtt_client.subscribe(settings.mqtt_topic, qos=settings.mqtt_qos)

        def on_message(
            _mqtt_client: mqtt.Client,
            _userdata: Any,
            message: mqtt.MQTTMessage,
        ) -> None:
            try:
                payload = decode_payload(bytes(message.payload))
            except (UnicodeDecodeError, json.JSONDecodeError) as exc:
                print(f"Skipping message on {message.topic}: invalid JSON payload ({exc})")
                return

            try:
                normalized_payload = validate_payload(payload)
            except ValueError as exc:
                print(f"Skipping message on {message.topic}: invalid telemetry payload ({exc})")
                return

            writer.insert_row(
                topic=message.topic,
                payload=normalized_payload,
                source=settings.mqtt_source,
            )
            print(f"Stored MQTT message from topic {message.topic}")

        client.on_connect = on_connect
        client.on_message = on_message

        client.connect(settings.mqtt_host, settings.mqtt_port, keepalive=60)
        client.loop_forever()
    finally:
        writer.close()


def main() -> int:
    args = parse_args()
    settings = load_settings(args)
    run(settings)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
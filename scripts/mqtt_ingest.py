from __future__ import annotations

import argparse
import json
import os
from dataclasses import dataclass
from typing import Any

import paho.mqtt.client as mqtt
import psycopg
from psycopg.types.json import Jsonb


@dataclass(frozen=True)
class Settings:
    mqtt_host: str
    mqtt_port: int
    mqtt_topic: str
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

    return Settings(
        mqtt_host=args.mqtt_host or os.getenv("MQTT_HOST", "localhost"),
        mqtt_port=args.mqtt_port or int(os.getenv("MQTT_PORT", "1883")),
        mqtt_topic=args.mqtt_topic or os.getenv("MQTT_TOPIC", "ca/dev/+/telemetry"),
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


def insert_row(
    connection: psycopg.Connection[Any], *, topic: str, payload: Any, source: str
) -> None:
    with connection.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO staging.mqtt_raw (topic, payload, source)
            VALUES (%s, %s, %s)
            """,
            (topic, Jsonb(payload), source),
        )
    connection.commit()


def run(settings: Settings) -> None:
    print(
        f"Connecting MQTT ingest worker to {settings.mqtt_host}:{settings.mqtt_port} "
        f"topic '{settings.mqtt_topic}' and writing to "
        f"{settings.db_name}@{settings.db_host}:{settings.db_port}."
    )

    with psycopg.connect(
        host=settings.db_host,
        port=settings.db_port,
        dbname=settings.db_name,
        user=settings.db_user,
        password=settings.db_password,
    ) as connection:
        client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)

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
            mqtt_client.subscribe(settings.mqtt_topic)

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

            insert_row(
                connection,
                topic=message.topic,
                payload=payload,
                source=settings.mqtt_source,
            )
            print(f"Stored MQTT message from topic {message.topic}")

        client.on_connect = on_connect
        client.on_message = on_message

        client.connect(settings.mqtt_host, settings.mqtt_port, keepalive=60)
        client.loop_forever()


def main() -> int:
    args = parse_args()
    settings = load_settings(args)
    run(settings)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
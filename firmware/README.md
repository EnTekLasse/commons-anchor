# firmware/

Firmware for IoT devices used in the Commons Anchor platform.

## Current projects

| Folder | Target | Purpose |
| --- | --- | --- |
| `hello_c6/` | ESP32-C6 | Sensor-less MQTT datalogger skeleton for early pipeline testing |

## Role in the platform

Firmware devices publish telemetry to Mosquitto via MQTT. The server-side MQTT ingest worker reads those messages and inserts them into `staging.mqtt_raw` in PostgreSQL.

Data flow:
- ESP32-C6 samples (or simulates) sensor data
- Publishes to topic `ca/dev/<device_id>/telemetry`
- MQTT worker consumes and writes to database

## Development toolchain

See [docs/iot/esp-idf-toolchain.md](../docs/iot/esp-idf-toolchain.md) for full setup instructions.

## Future firmware projects

New ESP32 projects should be added as sibling folders under `firmware/`, each with their own `README.md` and `CMakeLists.txt`.

Security note: WireGuard and SSH keys must never be embedded in or generated alongside firmware build artifacts.

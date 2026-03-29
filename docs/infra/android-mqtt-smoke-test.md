# Android MQTT Smoke Test (IoT MQTT Panel)

This runbook validates the MQTT ingestion path end-to-end using an Android phone.

Flow under test:
- Android app publish
- Mosquitto broker receive
- MQTT ingest worker store
- PostgreSQL row visible in `staging.mqtt_raw`

## Preconditions
- Docker Desktop is running.
- Phone and laptop are on the same Wi-Fi network.
- `.env` contains:
  - `MQTT_BIND_ADDRESS=0.0.0.0`
  - `MQTT_WS_BIND_ADDRESS=0.0.0.0`

## 1) Start services

```powershell
docker compose up -d --build postgres mqtt mqtt-ingest
```

Optional guided helper on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/testing/manual_mqtt_check.ps1
```

This helper prints the host/topic/payload, shows `Send MQTT now`, then waits and confirms whether a new row arrives in `staging.mqtt_raw`.

## 2) Find laptop Wi-Fi IP

```powershell
Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object { $_.InterfaceAlias -eq 'Wi-Fi' } |
  Select-Object IPAddress
```

Use this IP as MQTT host in the app (example: `192.168.1.17`).

## 3) Configure IoT MQTT Panel connection
- App: IoT MQTT Panel (Android)
- Protocol: TCP
- Host: laptop Wi-Fi IP
- Port: `1883`
- Client ID: `android-phone-01`
- Username/Password: empty
- SSL/TLS: Off

## 4) Create dashboard and publish panel
- Create or open a dashboard.
- Add panel with text input / publisher behavior.
- Connection: select the connection above.
- Topic: `ca/dev/phone01/telemetry`
- QoS: `0`
- Retain: Off
- Payload template (valid JSON):

```json
{"device_id":"phone01","temp_c":22.7,"hum_pct":41.8,"ts":"2026-03-17T20:30:00Z"}
```

Publish once from the panel.

## 5) Verify worker processing

```powershell
docker compose logs --tail 20 mqtt-ingest
```

Expected line:
- `Stored MQTT message from topic ca/dev/phone01/telemetry`

## 6) Verify data in PostgreSQL

```powershell
docker exec ca-postgres psql -U dw_admin -d dw -c "SELECT id, topic, payload, ingested_at FROM staging.mqtt_raw ORDER BY id DESC LIMIT 5;"
```

Expected:
- New row with topic `ca/dev/phone01/telemetry`
- JSON payload fields present (`device_id`, `temp_c`, `hum_pct`, `ts`)

## Troubleshooting
- Connect fails from phone:
  - Confirm same Wi-Fi network.
  - Confirm host is Wi-Fi IP, not `localhost`.
  - Confirm `MQTT_BIND_ADDRESS=0.0.0.0` and restart `mqtt` service.
- Message seen but not stored:
  - Check `mqtt-ingest` logs for invalid JSON.
  - Ensure payload uses double quotes and valid JSON syntax.

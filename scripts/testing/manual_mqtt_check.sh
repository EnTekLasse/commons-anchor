#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCKER_BIN="${DOCKER_BIN:-docker}"
TOPIC="${TOPIC:-ca/dev/phone01/telemetry}"
WAIT_SECONDS="${WAIT_SECONDS:-45}"
SKIP_PREFLIGHT="${SKIP_PREFLIGHT:-0}"

get_mqtt_row_count() {
  "$DOCKER_BIN" exec ca-postgres psql -U dw_admin -d dw -tAc "select count(*) from staging.mqtt_raw" | tr -d '[:space:]'
}

get_recent_mqtt_rows() {
  "$DOCKER_BIN" exec ca-postgres psql -U dw_admin -d dw -c "SELECT id, topic, payload, ingested_at FROM staging.mqtt_raw ORDER BY id DESC LIMIT 5;"
}

get_host_ip() {
  hostname -I 2>/dev/null | awk '{print $1}'
}

if [[ "$SKIP_PREFLIGHT" != "1" ]]; then
  "${SCRIPT_DIR}/ensure_docker_ready.sh"
fi

cd "$REPO_ROOT"

host_ip="$(get_host_ip)"
baseline_count="$(get_mqtt_row_count)"
payload='{"device_id":"phone01","temp_c":22.7,"hum_pct":41.8,"ts":"2026-03-29T20:30:00Z"}'

echo "[manual-mqtt] Host: ${host_ip}"
echo "[manual-mqtt] Port: 1883"
echo "[manual-mqtt] Topic: ${TOPIC}"
echo "[manual-mqtt] Payload: ${payload}"
echo "[manual-mqtt] Baseline staging.mqtt_raw rows: ${baseline_count}"
echo "[manual-mqtt] Send MQTT now"

for elapsed in $(seq 1 "$WAIT_SECONDS"); do
  sleep 1
  current_count="$(get_mqtt_row_count)"
  if [[ "$current_count" -gt "$baseline_count" ]]; then
    delta=$(( current_count - baseline_count ))
    echo "[manual-mqtt] Received ${delta} new MQTT row(s)"
    echo "[manual-mqtt] Latest rows:"
    get_recent_mqtt_rows
    exit 0
  fi

  if (( elapsed % 5 == 0 )); then
    echo "[manual-mqtt] Waiting... ${elapsed}s/${WAIT_SECONDS}s"
  fi
done

echo "No new MQTT rows arrived within ${WAIT_SECONDS}s" >&2
exit 1
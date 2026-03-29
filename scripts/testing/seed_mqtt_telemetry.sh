#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCKER_BIN="${DOCKER_BIN:-docker}"
TOPIC="${TOPIC:-ca/dev/phone01/telemetry}"
DEVICE_ID="${DEVICE_ID:-phone01}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-15}"
SLEEP_SECONDS="${SLEEP_SECONDS:-2}"
SKIP_PREFLIGHT="${SKIP_PREFLIGHT:-0}"

get_mqtt_row_count() {
  "$DOCKER_BIN" compose exec -T postgres sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "select count(*) from staging.mqtt_raw"' | tr -d '[:space:]'
}

if [[ "$SKIP_PREFLIGHT" != "1" ]]; then
  "${SCRIPT_DIR}/ensure_docker_ready.sh"
fi

cd "$REPO_ROOT"

initial_count="$(get_mqtt_row_count)"
echo "[mqtt-seed] initial staging.mqtt_raw rows: ${initial_count}"

for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  temp_c="$(awk -v n="$attempt" 'BEGIN { printf "%.1f", 22.0 + (n / 10.0) }')"
  hum_pct="$(awk -v n="$attempt" 'BEGIN { printf "%.1f", 41.0 + (n / 10.0) }')"
  payload=$(printf '{"device_id":"%s","temp_c":%s,"hum_pct":%s,"ts":"%s"}' "$DEVICE_ID" "$temp_c" "$hum_pct" "$timestamp")

  echo "[mqtt-seed] publish attempt ${attempt} to ${TOPIC}"
  "$DOCKER_BIN" compose exec -T mqtt sh -lc "mosquitto_pub -h localhost -t '$TOPIC' -q 1 -m '$payload'"

  sleep "$SLEEP_SECONDS"
  current_count="$(get_mqtt_row_count)"
  if [[ "$current_count" -gt "$initial_count" ]]; then
    echo "[mqtt-seed] stored MQTT row successfully (${initial_count} -> ${current_count})"
    exit 0
  fi
done

echo "MQTT seed message was published but no new row appeared in staging.mqtt_raw" >&2
exit 1
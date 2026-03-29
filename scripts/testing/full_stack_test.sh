#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCKER_BIN="${DOCKER_BIN:-docker}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
SEED_MQTT="${SEED_MQTT:-0}"

"${SCRIPT_DIR}/ensure_docker_ready.sh"

cd "$REPO_ROOT"

echo "[full] compose up all services"
"$DOCKER_BIN" compose up -d

if [[ "$SEED_MQTT" == "1" ]]; then
  echo "[full] seed MQTT telemetry"
  SKIP_PREFLIGHT=1 "${SCRIPT_DIR}/seed_mqtt_telemetry.sh"
fi

echo "[full] run batch jobs"
"$DOCKER_BIN" compose --profile jobs run --rm energidata-ingest
"$DOCKER_BIN" compose --profile jobs run --rm power-price-transform

if command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "[full] run local quality gate"
  "$PYTHON_BIN" -m scripts.local_quality_gate
else
  echo "[full] warning: python not found, skipping local quality gate"
fi

echo "[full] check Grafana HTTP"
for i in $(seq 1 20); do
  if curl -fsS "http://localhost:3000" >/dev/null 2>&1; then
    echo "[full] Grafana HTTP 200"
    break
  fi
  sleep 3
  if [[ "$i" == "20" ]]; then
    echo "Grafana did not return HTTP 200" >&2
    exit 1
  fi
done

echo "[full] check Metabase HTTP"
for i in $(seq 1 20); do
  if curl -fsS "http://localhost:3001" >/dev/null 2>&1; then
    echo "[full] Metabase HTTP 200"
    break
  fi
  sleep 3
  if [[ "$i" == "20" ]]; then
    echo "Metabase did not return HTTP 200" >&2
    exit 1
  fi
done

echo "[full] final compose status"
"$DOCKER_BIN" compose ps

echo "[full] completed successfully"

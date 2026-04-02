#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REPORT_PATH="${REPO_ROOT}/docs/testing/parity-report-linux-host.md"
DOCKER_BIN="${DOCKER_BIN:-docker}"
PYTHON_BIN="${PYTHON_BIN:-python3}"

run_step() {
  local name="$1"
  shift
  if "$@"; then
    STEP_RESULTS+=("| ${name} | PASS | OK |")
  else
    STEP_RESULTS+=("| ${name} | FAIL | Exit code $? |")
    OVERALL="FAIL"
  fi
}

get_http_status() {
  local url="$1"
  for _ in $(seq 1 20); do
    if code=$(curl -L -sS -o /dev/null -w "%{http_code}" "$url" 2>/dev/null); then
      echo "$code"
      return 0
    fi
    sleep 3
  done
  echo 0
}

get_counts() {
  local mqtt_rows
  local energinet_rows
  local mart_rows

  mqtt_rows="$(${DOCKER_BIN} compose exec -T postgres sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "select count(*) from staging.mqtt_raw"' | tr -d '[:space:]')"
  energinet_rows="$(${DOCKER_BIN} compose exec -T postgres sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "select count(*) from staging.energinet_raw"' | tr -d '[:space:]')"
  mart_rows="$(${DOCKER_BIN} compose exec -T postgres sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "select count(*) from mart.power_price_15min"' | tr -d '[:space:]')"

  echo "mqtt_rows=${mqtt_rows:-ERR}"
  echo "energinet_rows=${energinet_rows:-ERR}"
  echo "mart_rows=${mart_rows:-ERR}"
}

cd "$REPO_ROOT"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S %z')"
OVERALL="PASS"
STEP_RESULTS=()

run_step "Docker preflight" bash "${SCRIPT_DIR}/ensure_docker_ready.sh"
run_step "Linux smoke test" bash "${SCRIPT_DIR}/smoke_test.sh"
run_step "Linux full stack test" bash "${SCRIPT_DIR}/full_stack_test.sh"

GRAFANA_STATUS="$(get_http_status "http://localhost:3000")"
METABASE_STATUS="$(get_http_status "http://localhost:3001")"
if [[ "$GRAFANA_STATUS" != "200" || "$METABASE_STATUS" != "200" ]]; then
  OVERALL="FAIL"
fi

COUNTS_RAW="$(get_counts)"
MQTT_ROWS="$(printf '%s
' "$COUNTS_RAW" | sed -n 's/^mqtt_rows=//p')"
ENERGINET_ROWS="$(printf '%s
' "$COUNTS_RAW" | sed -n 's/^energinet_rows=//p')"
MART_ROWS="$(printf '%s
' "$COUNTS_RAW" | sed -n 's/^mart_rows=//p')"
COMPOSE_STATUS="$("$DOCKER_BIN" compose ps)"

{
  echo "# Parity Report - Linux host"
  echo
  echo "Generated: ${TIMESTAMP}"
  echo
  echo "## Overall"
  echo
  echo "- Status: **${OVERALL}**"
  echo "- Target parity baseline: Lenovo Tiny Ubuntu host"
  echo
  echo "## Step results"
  echo
  echo "| Step | Status | Detail |"
  echo "|---|---|---|"
  for row in "${STEP_RESULTS[@]}"; do
    echo "$row"
  done
  echo
  echo "## Endpoint checks"
  echo
  echo "- Grafana HTTP status: ${GRAFANA_STATUS}"
  echo "- Metabase HTTP status: ${METABASE_STATUS}"
  echo
  echo "## Data checks"
  echo
  echo "- staging.mqtt_raw rows: ${MQTT_ROWS:-ERR}"
  echo "- staging.energinet_raw rows: ${ENERGINET_ROWS:-ERR}"
  echo "- mart.power_price_15min rows: ${MART_ROWS:-ERR}"
  echo
  echo "## Compose status snapshot"
  echo
  echo '```text'
  printf '%s
' "$COMPOSE_STATUS"
  echo '```'
  echo
  echo "## Notes"
  echo
  echo "- This report is intended for final host-level parity on Ubuntu."
  echo "- Compare with docs/testing/parity-report-windows-laptop.md before sign-off."
} > "$REPORT_PATH"

echo "Report written: $REPORT_PATH"

if [[ "$OVERALL" != "PASS" ]]; then
  exit 1
fi

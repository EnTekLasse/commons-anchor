#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCKER_BIN="${DOCKER_BIN:-docker}"
RESTORE_DB="${RESTORE_DB:-dw_restore_drill}"
BACKUP_DIR="${BACKUP_DIR:-${REPO_ROOT}/backups}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="${BACKUP_DIR}/dw_${TIMESTAMP}.dump"

mkdir -p "${BACKUP_DIR}"
cd "${REPO_ROOT}"

echo "[v3] ensure stack is up"
"${DOCKER_BIN}" compose up -d postgres

echo "[v3] dump source database"
"${DOCKER_BIN}" compose exec -T postgres sh -lc '
  pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc
' > "${BACKUP_FILE}"

echo "[v3] dump stored on host"
ls -lh "${BACKUP_FILE}"

echo "[v3] recreate restore target database: ${RESTORE_DB}"
"${DOCKER_BIN}" compose exec -T postgres sh -lc "
  psql -U \"\$POSTGRES_USER\" -d postgres -v ON_ERROR_STOP=1 -c \"DROP DATABASE IF EXISTS ${RESTORE_DB};\"
  psql -U \"\$POSTGRES_USER\" -d postgres -v ON_ERROR_STOP=1 -c \"CREATE DATABASE ${RESTORE_DB} OWNER \\\"\$POSTGRES_USER\\\";\"
"

echo "[v3] restore into ${RESTORE_DB}"
"${DOCKER_BIN}" compose exec -T postgres sh -lc "
  pg_restore -U \"\$POSTGRES_USER\" -d ${RESTORE_DB} --clean --if-exists
" < "${BACKUP_FILE}"

echo "[v3] validate row counts"
SRC_MQTT="$("${DOCKER_BIN}" compose exec -T postgres sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -At -c "SELECT COUNT(*) FROM staging.mqtt_raw;"')"
SRC_RAW="$("${DOCKER_BIN}" compose exec -T postgres sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -At -c "SELECT COUNT(*) FROM dw.power_price_raw;"')"
SRC_DM="$("${DOCKER_BIN}" compose exec -T postgres sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -At -c "SELECT COUNT(*) FROM dm.power_price_hourly;"')"

RST_MQTT="$("${DOCKER_BIN}" compose exec -T postgres sh -lc 'psql -U "$POSTGRES_USER" -d '"${RESTORE_DB}"' -At -c "SELECT COUNT(*) FROM staging.mqtt_raw;"')"
RST_RAW="$("${DOCKER_BIN}" compose exec -T postgres sh -lc 'psql -U "$POSTGRES_USER" -d '"${RESTORE_DB}"' -At -c "SELECT COUNT(*) FROM dw.power_price_raw;"')"
RST_DM="$("${DOCKER_BIN}" compose exec -T postgres sh -lc 'psql -U "$POSTGRES_USER" -d '"${RESTORE_DB}"' -At -c "SELECT COUNT(*) FROM dm.power_price_hourly;"')"

echo "[v3] source counts"
echo "[v3]   staging.mqtt_raw=${SRC_MQTT}"
echo "[v3]   dw.power_price_raw=${SRC_RAW}"
echo "[v3]   dm.power_price_hourly=${SRC_DM}"

echo "[v3] restore counts"
echo "[v3]   staging.mqtt_raw=${RST_MQTT}"
echo "[v3]   dw.power_price_raw=${RST_RAW}"
echo "[v3]   dm.power_price_hourly=${RST_DM}"

if [[ "${SRC_MQTT}" != "${RST_MQTT}" || "${SRC_RAW}" != "${RST_RAW}" || "${SRC_DM}" != "${RST_DM}" ]]; then
  echo "[v3] FAIL: source and restore counts differ" >&2
  exit 1
fi

echo "[v3] PASS: backup/restore drill successful"
echo "[v3] artifacts: ${BACKUP_FILE}, db=${RESTORE_DB}"
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

echo "[v3] dump source database to container tmp"
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
SRC_COUNTS="$("${DOCKER_BIN}" compose exec -T postgres sh -lc '
  psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -At -c "
    SELECT ''staging.mqtt_raw'', COUNT(*) FROM staging.mqtt_raw
    UNION ALL
    SELECT ''dw.power_price_raw'', COUNT(*) FROM dw.power_price_raw
    UNION ALL
    SELECT ''dm.power_price_hourly'', COUNT(*) FROM dm.power_price_hourly
    ORDER BY 1;
  "
')"

RESTORE_COUNTS="$("${DOCKER_BIN}" compose exec -T postgres sh -lc '
  psql -U "$POSTGRES_USER" -d '"${RESTORE_DB}"' -At -c "
    SELECT ''staging.mqtt_raw'', COUNT(*) FROM staging.mqtt_raw
    UNION ALL
    SELECT ''dw.power_price_raw'', COUNT(*) FROM dw.power_price_raw
    UNION ALL
    SELECT ''dm.power_price_hourly'', COUNT(*) FROM dm.power_price_hourly
    ORDER BY 1;
  "
')"

echo "[v3] source counts"
printf '%s\n' "${SRC_COUNTS}"

echo "[v3] restore counts"
printf '%s\n' "${RESTORE_COUNTS}"

if [[ "${SRC_COUNTS}" != "${RESTORE_COUNTS}" ]]; then
  echo "[v3] FAIL: source and restore counts differ" >&2
  exit 1
fi

echo "[v3] PASS: backup/restore drill successful"
echo "[v3] artifacts: ${BACKUP_FILE}, db=${RESTORE_DB}"
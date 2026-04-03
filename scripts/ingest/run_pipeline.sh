#!/usr/bin/env bash
set -euo pipefail

HOST_NAME="${HOST_NAME:-127.0.0.1}"
PORT="${PORT:-5432}"
DATABASE="${DATABASE:-dw}"
USER_NAME="${USER_NAME:-dw_admin}"
INCLUDE_DMI_CLIMATE="${INCLUDE_DMI_CLIMATE:-0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

SECRET_FILE="${REPO_ROOT}/infra/secrets/postgres_password.secret"
if [[ ! -f "${SECRET_FILE}" ]]; then
  echo "Secret file not found: ${SECRET_FILE}" >&2
  exit 1
fi

export POSTGRES_PASSWORD
POSTGRES_PASSWORD="$(tr -d '\n' < "${SECRET_FILE}")"

if [[ "${INCLUDE_DMI_CLIMATE}" == "1" ]]; then
  TOTAL_STEPS=3
else
  TOTAL_STEPS=2
fi

echo "Step 1/${TOTAL_STEPS}: Ingest energidata..."
"${REPO_ROOT}/.venv/bin/python" "${SCRIPT_DIR}/energidataservice_ingest.py" \
  --db-host "${HOST_NAME}" --db-port "${PORT}" --db-name "${DATABASE}" --db-user "${USER_NAME}"

if [[ "${INCLUDE_DMI_CLIMATE}" == "1" ]]; then
  echo "Step 2/${TOTAL_STEPS}: Ingest DMI climate incrementally..."
  "${REPO_ROOT}/.venv/bin/python" "${SCRIPT_DIR}/dmi_climate_ingest.py" \
    --since-latest --db-host "${HOST_NAME}" --db-port "${PORT}" --db-name "${DATABASE}" --db-user "${USER_NAME}"
fi

echo "Step ${TOTAL_STEPS}/${TOTAL_STEPS}: Refresh curated views..."
"${REPO_ROOT}/.venv/bin/python" "${SCRIPT_DIR}/refresh_curated.py" \
  --view all --host "${HOST_NAME}" --port "${PORT}" --db "${DATABASE}" --user "${USER_NAME}" --verbose

echo "Pipeline completed successfully."

#!/usr/bin/env bash
set -euo pipefail

HOST_NAME="${HOST_NAME:-127.0.0.1}"
PORT="${PORT:-5432}"
DATABASE="${DATABASE:-dw}"
USER_NAME="${USER_NAME:-dw_admin}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

SECRET_FILE="${REPO_ROOT}/infra/secrets/postgres_password.secret"
if [[ ! -f "${SECRET_FILE}" ]]; then
  echo "Secret file not found: ${SECRET_FILE}" >&2
  exit 1
fi

export POSTGRES_PASSWORD
POSTGRES_PASSWORD="$(tr -d '\n' < "${SECRET_FILE}")"

echo "Step 1/2: Ingest energidata..."
"${REPO_ROOT}/.venv/bin/python" "${SCRIPT_DIR}/energidataservice_ingest.py" \
  --db-host "${HOST_NAME}" --db-port "${PORT}" --db-name "${DATABASE}" --db-user "${USER_NAME}"

echo "Step 2/2: Refresh curated views..."
"${REPO_ROOT}/.venv/bin/python" "${SCRIPT_DIR}/refresh_curated.py" \
  --view all --host "${HOST_NAME}" --port "${PORT}" --db "${DATABASE}" --user "${USER_NAME}" --verbose

echo "Pipeline completed successfully."

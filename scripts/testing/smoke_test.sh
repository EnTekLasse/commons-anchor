#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCKER_BIN="${DOCKER_BIN:-docker}"

"${SCRIPT_DIR}/ensure_docker_ready.sh"

cd "$REPO_ROOT"

echo "[smoke] compose up core services"
"$DOCKER_BIN" compose up -d postgres grafana mqtt

echo "[smoke] compose ps"
"$DOCKER_BIN" compose ps

echo "[smoke] check Grafana HTTP"
for i in $(seq 1 20); do
  if curl -fsS "http://localhost:3000" >/dev/null 2>&1; then
    echo "[smoke] Grafana HTTP 200"
    echo "[smoke] completed successfully"
    exit 0
  fi
  sleep 3
done

echo "Grafana did not return HTTP 200" >&2
exit 1

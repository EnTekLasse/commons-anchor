#!/usr/bin/env bash
set -euo pipefail

MAX_CHECKS="${MAX_CHECKS:-30}"
SLEEP_SECONDS="${SLEEP_SECONDS:-4}"
DOCKER_BIN="${DOCKER_BIN:-docker}"

docker_ready() {
  "$DOCKER_BIN" version >/dev/null 2>&1
}

if docker_ready; then
  echo "Docker daemon already ready"
  exit 0
fi

if command -v systemctl >/dev/null 2>&1; then
  if systemctl list-unit-files | grep -q '^docker.service'; then
    if command -v sudo >/dev/null 2>&1; then
      sudo systemctl start docker || true
    else
      systemctl start docker || true
    fi
  fi
fi

if docker_ready; then
  echo "Docker daemon ready after service start"
  exit 0
fi

for i in $(seq 1 "$MAX_CHECKS"); do
  sleep "$SLEEP_SECONDS"
  if docker_ready; then
    echo "Docker daemon ready after ${i} checks"
    exit 0
  fi
done

echo "Docker daemon not ready after ${MAX_CHECKS} checks" >&2
exit 1

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCKER_BIN="${DOCKER_BIN:-docker}"
STOP_ENGINE="${STOP_ENGINE:-0}"
REMOVE_VOLUMES="${REMOVE_VOLUMES:-0}"
REMOVE_ORPHANS="${REMOVE_ORPHANS:-0}"
PRUNE_UNUSED="${PRUNE_UNUSED:-0}"

if ! "$DOCKER_BIN" version >/dev/null 2>&1; then
  echo "Docker daemon not running; nothing to stop"
  exit 0
fi

cd "$REPO_ROOT"

echo "[stop] compose down"
down_args=(compose down)
if [[ "$REMOVE_VOLUMES" == "1" ]]; then
  down_args+=( -v )
fi
if [[ "$REMOVE_ORPHANS" == "1" ]]; then
  down_args+=( --remove-orphans )
fi

"$DOCKER_BIN" "${down_args[@]}"

if [[ "$PRUNE_UNUSED" == "1" ]]; then
  echo "[stop] pruning unused Docker resources"
  "$DOCKER_BIN" system prune -f
fi

if [[ "$STOP_ENGINE" == "1" ]] && command -v systemctl >/dev/null 2>&1; then
  if systemctl list-unit-files | grep -q '^docker.service'; then
    echo "[stop] stopping docker service"
    if command -v sudo >/dev/null 2>&1; then
      sudo systemctl stop docker || true
    else
      systemctl stop docker || true
    fi
  fi
fi

echo "[stop] completed successfully"

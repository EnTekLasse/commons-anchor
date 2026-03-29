# Runtime test structure

This project uses a layered test approach for reliable local runs.

## 1) Preflight

Scripts:
- `scripts/testing/ensure_docker_ready.ps1` (Windows)
- `scripts/testing/ensure_docker_ready.sh` (Linux)

Purpose:
- Verify Docker daemon availability before any Docker-dependent checks.
- Attempt Docker Desktop startup and poll until daemon is ready.

## 2) Smoke test

Scripts:
- `scripts/testing/smoke_test.ps1` (Windows)
- `scripts/testing/smoke_test.sh` (Linux)

What it checks:
- Starts core services (`postgres`, `grafana`, `mqtt`).
- Verifies compose status.
- Verifies Grafana HTTP 200.

## 3) Full stack test

Scripts:
- `scripts/testing/full_stack_test.ps1` (Windows)
- `scripts/testing/full_stack_test.sh` (Linux)

What it checks:
- Starts full compose stack.
- Runs job services (`energidata-ingest`, `power-price-transform`).
- Runs local quality gate if project venv python exists.
- Verifies Grafana and Metabase HTTP 200.
- Prints final compose status.

Useful switches:
- `-ColdStart` to reset project volumes, stop Docker Desktop, and then validate from a cold boot.
- `-SeedMqtt` to try an extra automated MQTT publish on Windows when you explicitly want that path exercised.
- `-SkipPreflight` when Docker readiness has already been handled by a parent script.
- `-SkipQualityGate` for faster runtime-only reruns.

## 4) Linux container parity sanity (Windows)

Script:
- `scripts/testing/linux_container_parity.ps1`

What it checks:
- Runs a Linux container and validates runtime identity.
- Verifies Python image availability in Linux container runtime.
- Verifies repository mount into Linux container.
- Verifies compose file can render (`compose config -q`).

## 5) Parity report

Scripts:
- `scripts/testing/generate_parity_report.ps1` (Windows)
- `scripts/testing/generate_parity_report.sh` (Linux)

What it checks:
- Runs Docker preflight once, then reuses it for the remaining parity steps.
- Runs Windows full stack validation and Linux container parity sanity.
- Captures HTTP status for Grafana and Metabase.
- Captures key warehouse row counts.
- Writes a Markdown report under `docs/testing/`.

Useful switch:
- `-SkipQualityGate` for a faster runtime-only parity report.

## 6) Shutdown

Scripts:
- `scripts/testing/stop_stack.ps1` (Windows)
- `scripts/testing/stop_stack.sh` (Linux)

What it does:
- Stops the compose stack cleanly.
- Can remove project volumes for a clean database reset.
- Can remove compose orphans and optionally prune unused Docker resources.
- Optionally lets the host Docker runtime be stopped outside the project scripts.

Useful options:
- Windows: `-RemoveVolumes -RemoveOrphans -PruneUnused -StopDesktop`
- Linux: `REMOVE_VOLUMES=1 REMOVE_ORPHANS=1 PRUNE_UNUSED=1 STOP_ENGINE=1 bash scripts/testing/stop_stack.sh`

## Recommended run order

Windows:
1. `powershell -ExecutionPolicy Bypass -File scripts/testing/smoke_test.ps1`
2. `powershell -ExecutionPolicy Bypass -File scripts/testing/full_stack_test.ps1`
3. `powershell -ExecutionPolicy Bypass -File scripts/testing/full_stack_test.ps1 -ColdStart`
4. `powershell -ExecutionPolicy Bypass -File scripts/testing/linux_container_parity.ps1`
5. `powershell -ExecutionPolicy Bypass -File scripts/testing/generate_parity_report.ps1`
6. `powershell -ExecutionPolicy Bypass -File scripts/testing/generate_parity_report.ps1 -SkipQualityGate` for a faster runtime-only report
7. `powershell -ExecutionPolicy Bypass -File scripts/testing/stop_stack.ps1 -RemoveVolumes -RemoveOrphans -PruneUnused -StopDesktop` for a standalone cold-start reset

Linux:
1. `bash scripts/testing/smoke_test.sh`
2. `bash scripts/testing/full_stack_test.sh`
3. `bash scripts/testing/generate_parity_report.sh`

## Linux-in-Docker note

- Running Linux containers on Windows is useful for partial parity checks.
- It validates container images, compose wiring, app behavior, and many data flows.
- It does not fully validate host-level Linux behavior (systemd units, reboot behavior, disk layout, kernel/network specifics).
- Use this setup as a pre-parity stage, then run the same scripts on Lenovo Tiny Ubuntu for final parity.

## Notes

- On Windows, Docker Desktop warm-up can vary between runs.
- Always run preflight through the provided scripts rather than calling compose directly.
- Cross-platform helper scripts use the same base name with `.ps1` and `.sh` extensions to keep entrypoints aligned across Windows and Linux.
- MQTT validation can stay as a separate/manual check when the authoritative source is a phone or device rather than a purely synthetic test publisher.
- If you choose to test MQTT, prefer a real client such as a phone app, ESP32, or another MQTT publisher, and keep that step outside the default automated gate.

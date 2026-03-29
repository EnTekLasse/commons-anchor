# Lenovo Tiny readiness checklist

Use this checklist before moving from Windows laptop validation to Ubuntu on Lenovo Tiny.

## A) Platform readiness (Ubuntu host)

- Ubuntu host installed and updated.
- Docker Engine and Docker Compose plugin installed.
- User added to docker group (or explicit sudo workflow decided).
- Required ports available and documented (`3000`, `3001`, `5432`, `1883`, `9001`).
- Host time and timezone verified.

## B) Security and access

- SSH access validated.
- WireGuard baseline validated for remote access path.
- Secrets files provisioned on host and not committed.
- Firewall policy documented and applied.

## C) Runtime parity execution

- Run `bash scripts/testing/ensure_docker_ready.sh`.
- Run `bash scripts/testing/smoke_test.sh`.
- Run `bash scripts/testing/full_stack_test.sh`.
- Verify Grafana and Metabase return HTTP 200.
- Verify compose status shows healthy Postgres.

## D) Data parity checks

- Energidata ingest job exits 0.
- Power price transform job exits 0.
- Staging and mart row counts are non-zero.
- MQTT ingest receives at least one valid telemetry message.

## E) Recovery and operations

- Reboot host and verify stack recovery behavior.
- Validate startup procedure after reboot.
- Validate stop/start runbook and rollback runbook.
- Record timing: cold start to healthy stack.

## F) Sign-off criteria

- Two consecutive full-stack runs pass without manual patching.
- No critical errors in container logs.
- Documented differences vs Windows are accepted.
- Ready to promote Lenovo Tiny as primary runtime host.

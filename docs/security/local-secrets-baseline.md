# Local Secrets Baseline (.env + Docker secrets)

This project uses local Docker secret files for passwords and `.env` for non-secret settings.

## Why this baseline
- Fast to run on one machine
- Easy to reproduce on new hardware
- No extra paid services

## Rules
1. Keep real passwords in `infra/secrets/*.secret` only.
2. Treat WireGuard private keys and client configs as secrets.
3. Never commit `infra/secrets/*.secret`, `.env`, or WireGuard key/config material.
4. Keep placeholders and file paths in `.env.example` only.
5. Store real secret values in a password manager as backup.
6. Keep service bind addresses on `127.0.0.1` unless LAN access is explicitly needed.

## What another developer must define locally

Minimum required local files:

- `.env` (copied from `.env.example` and adjusted per machine)
- `infra/secrets/postgres_password.secret`
- `infra/secrets/grafana_admin_password.secret`

Optional but security-critical local files when WireGuard is used:

- WireGuard private key files (for example `*.key`)
- WireGuard client config exports (for example `wg*.conf`)

Configuration contract:

| Item | Tracked in git | Local per developer | Notes |
| --- | --- | --- | --- |
| `.env.example` | Yes | No | Template only, no real secrets |
| `.env` | No | Yes | Non-secret machine settings and secret file paths |
| `infra/secrets/postgres_password.secret` | No | Yes | Real password value |
| `infra/secrets/grafana_admin_password.secret` | No | Yes | Real password value |
| `wg*.conf` (WireGuard client config) | No | Yes | Contains private key, keep in password manager |
| `*.key` (WireGuard private key files) | No | Yes | Never leave working directory |

Password requirements (recommended minimum):

- At least 20 characters
- Randomly generated
- Stored in a password manager
- Not reused across services

Onboarding checklist for a new contributor:

1. Copy `.env.example` to `.env`.
2. Create both `.secret` files with strong local values.
3. Start stack with `docker compose up -d`.
4. Verify services are healthy and login works for Grafana.
5. Confirm git does not show `.env` or `infra/secrets/*.secret` in status.

## Setup on a new machine
1. Copy `.env.example` to `.env`.
2. Create local secret files under `infra/secrets`.
3. Start services with Docker Compose.

Default exposure profile:
- PostgreSQL, MQTT, Grafana and Metabase bind to `127.0.0.1` by default.
- If you need LAN clients (for example ESP32 MQTT), override the specific `*_BIND_ADDRESS` value in `.env`.

PowerShell example:

```powershell
Copy-Item .env.example .env
New-Item -ItemType Directory -Force infra/secrets | Out-Null
Set-Content infra/secrets/postgres_password.secret "<strong-postgres-password>"
Set-Content infra/secrets/grafana_admin_password.secret "<strong-grafana-password>"
```

## Verify .env is ignored

```powershell
git check-ignore -v .env
git check-ignore -v infra/secrets/postgres_password.secret
git status --short
```

Expected result:
- `git check-ignore` shows `.gitignore` rule for `.env`
- `git check-ignore` shows `.gitignore` rule for `infra/secrets/*.secret`
- `git status --short` does not list `.env`

## Rotation procedure (local)
1. Generate a new password.
2. Update `infra/secrets/postgres_password.secret`.
3. Update the running PostgreSQL role password:

```powershell
docker compose exec postgres psql -U dw_admin -d dw -c "ALTER ROLE dw_admin WITH PASSWORD '<new-password>';"
```

4. Restart dependent services:

```powershell
docker compose restart postgres metabase
docker compose restart grafana
```

## Future hardening
When the platform moves beyond local baseline, migrate secrets to Docker secrets or a dedicated secret manager.
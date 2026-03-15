# Local Secrets Baseline (.env + Docker secrets)

This project uses local Docker secret files for passwords and `.env` for non-secret settings.

## Why this baseline
- Fast to run on one machine
- Easy to reproduce on new hardware
- No extra paid services

## Rules
1. Keep real passwords in `infra/secrets/*.secret` only.
2. Never commit `infra/secrets/*.secret` or `.env`.
3. Keep placeholders and file paths in `.env.example` only.
4. Store real secret values in a password manager as backup.
5. Keep service bind addresses on `127.0.0.1` unless LAN access is explicitly needed.

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
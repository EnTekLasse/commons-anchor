# Local Secrets Baseline (.env + gitignore)

This project currently uses local `.env` files as the default secret strategy.

## Why this baseline
- Fast to run on one machine
- Easy to reproduce on new hardware
- No extra paid services

## Rules
1. Keep real secrets only in `.env`.
2. Never commit `.env` to git.
3. Keep placeholders in `.env.example` only.
4. Store real secret values in a password manager as backup.

## Setup on a new machine
1. Copy `.env.example` to `.env`.
2. Fill in secure values for all passwords.
3. Start services with Docker Compose.

PowerShell example:

```powershell
Copy-Item .env.example .env
```

## Verify .env is ignored

```powershell
git check-ignore -v .env
git status --short
```

Expected result:
- `git check-ignore` shows `.gitignore` rule for `.env`
- `git status --short` does not list `.env`

## Rotation procedure (local)
1. Generate a new password.
2. Update `POSTGRES_PASSWORD` and `MB_DB_PASS` in `.env`.
3. Update the running PostgreSQL role password:

```powershell
docker compose exec postgres psql -U dw_admin -d dw -c "ALTER ROLE dw_admin WITH PASSWORD '<new-password>';"
```

4. Restart dependent services:

```powershell
docker compose restart postgres metabase
```

## Future hardening
When the platform moves beyond local baseline, migrate secrets to Docker secrets or a dedicated secret manager.
# Supabase Connection Guide (App + Agent SQL)

Last updated: February 12, 2026

## 1) Two different connection paths

- App runtime connection (Flutter app):
  - uses `SUPABASE_URL` + `SUPABASE_ANON_KEY`
  - loaded via `--dart-define-from-file=.env/supabase.local.json`
- Agent/admin SQL connection (psql):
  - uses Postgres pooler credentials (`PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD`, `PGSSLMODE`)
  - used for migrations, seed SQL, and direct DB checks

These are separate auth systems. App login email is not the Postgres DB username.

## 2) App runtime setup (hosted or local Supabase)

1. Put runtime keys in `.env/supabase.local.json`:
```json
{
  "SUPABASE_URL": "https://<project-ref>.supabase.co",
  "SUPABASE_ANON_KEY": "<anon-key>"
}
```
2. Run app:
```bash
flutter run -d edge --dart-define-from-file=.env/supabase.local.json
```

Note: filename `.env/supabase.local.json` is historical and still used even for hosted Supabase.

## 3) Agent/admin SQL setup (psql over pooler)

Use `.env/supabase.remote.ps1` with:

```powershell
$env:PGHOST = 'aws-1-<region>.pooler.supabase.com'
$env:PGPORT = '6543'
$env:PGDATABASE = 'postgres'
$env:PGUSER = 'postgres.<project_ref>'
$env:PGPASSWORD = '<database_password>'
$env:PGSSLMODE = 'require'
```

Then connect:

```powershell
. .\.env\supabase.remote.ps1
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -h $env:PGHOST -p $env:PGPORT -U $env:PGUSER -d $env:PGDATABASE -c "select now();"
```

Run seed scripts in one transaction (required for scripts that use temp tables with `on commit drop`):

```powershell
. .\.env\supabase.remote.ps1
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -1 -h $env:PGHOST -p $env:PGPORT -U $env:PGUSER -d $env:PGDATABASE -v ON_ERROR_STOP=1 -f docs/supabase_article_word_coverage_seed.sql
```

## 4) Common errors and fixes

- `password authentication failed`:
  - wrong DB password, or wrong DB user format.
- `There is no user '<name>' in the database`:
  - you used dashboard/account username; must use `postgres.<project_ref>`.
- `Circuit breaker open: Too many authentication errors`:
  - pause retries, verify credentials, retry after cooldown.
- `psql is not recognized`:
  - use full executable path, or add PostgreSQL `bin` to PATH.

## 5) Safety rules

- Never commit secrets in `.env/supabase.local.json` or `.env/supabase.remote.ps1`.
- Keep `.env/supabase.local.example.json` as template only.
- Do not use service-role keys in the client app.

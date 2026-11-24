# Deploying the SnapVerify backend to Render with an existing Supabase PostgreSQL database

Target: NestJS backend (`backend/`) on Render, using the **existing** Supabase
PostgreSQL database. Nothing here creates a database, resets schema, or deletes
data. The database name is the PostgreSQL default: `postgres`.

## 1. Connection string (do this first)

Use Supabase's **shared session pooler** connection string. The same single
`DATABASE_URL` is used by the running app and by Prisma CLI commands such as
`npx prisma migrate status`.

```text
postgresql://postgres.<project-ref>:<url-encoded-password>@aws-<region>.pooler.supabase.com:5432/postgres?sslmode=require
```

Store it in `backend/.env` locally and as a Render secret. Never commit it.

- Use the default PostgreSQL database name `postgres`.
- Do **not** use Supabase's direct host `db.<project-ref>.supabase.co`: it is
  IPv6-only (unless the project has the paid IPv4 add-on) and Render has no
  outbound IPv6, which fails as `getaddrinfo ENOTFOUND`.
- Do **not** use transaction mode (port `6543`): it does not support the
  prepared statements Prisma issues.
- URL-encode special characters in the password (`@` → `%40`, `#` → `%23`).

The app strips `sslmode` / `channel_binding` from the URL and enables TLS itself
(`DATABASE_SSL_REJECT_UNAUTHORIZED` defaults to `false`, which managed-provider
certificate chains need).

## 2. Check what the database already contains (read-only)

Run from `backend/` with `DATABASE_URL` set to the pooled URL:

```bash
npx prisma migrate status
```

This only reads `_prisma_migrations`; it changes nothing. Interpret the result:

| Result | Meaning | Action |
|---|---|---|
| "Database schema is up to date" | All migrations applied | No migration needed before deploy |
| "N migrations have not yet been applied" | Partial history | Read §3 before applying |
| `P3005` — database schema is not empty | Tables exist, no migration history | **Do not run `migrate deploy`.** Baseline by hand (§4) |
| Connection error | Wrong URL / IPv6 / password | Re-check §1 |

Also confirm the table list, e.g. in the Supabase SQL editor:

```sql
select table_name from information_schema.tables
where table_schema = 'public' order by 1;
```

## 3. Migrations that touch existing data

Applying the chain to a **fresh empty** database is safe. On a **populated**
database these need a backup first:

- `20260705094816_init` — drops the legacy PascalCase tables
  (`User`, `Organization`, `Device`, `Payment`, …). Safe only because the
  preceding migration created them empty; if your database already has them
  **with data**, `20260705092901_one` aborts first (its `CREATE TABLE` is not
  `IF NOT EXISTS`), so the deploy fails before any `DROP` runs.
- `20260719145312_add_user_business_assignment_and_invitation` — **the risky
  one.** Drops `users.role`, `users.branchId`, `users.organizationId` and
  `devices.organizationId`, `devices.userId`, and `payments.paymentAccountId`
  after copying staff assignments into `user_business_assignments`.
- `20261117000000_email_auth` — sets `email` to `NULL` on duplicate emails,
  keeping the lowest `id`. Back up `users` first if duplicates may exist.
- `20260708082721_update_otp_schema`, `20261116153743_remove_otp_codes` — delete
  OTP rows only; OTPs are short-lived by design.

Take a `pg_dump` of the database before applying anything.

Apply (only after the checks above and a backup):

```bash
npx prisma migrate deploy   # never `migrate reset`, never `db push`
```

## 4. If the schema exists without migration history

Do not delete tables. Create the history by marking the migrations that are
genuinely already reflected in the database, one at a time, oldest first:

```bash
npx prisma migrate resolve --applied 20260705092901_one
```

`migrate resolve` only writes a row to `_prisma_migrations`; it does not run
SQL. Baseline only what you have verified by hand, then re-run
`npx prisma migrate status`.

## 5. Render service

Blueprint: [`render.yaml`](../render.yaml) at the repository root. **Deploy it
as a Blueprint** (Dashboard → New → Blueprint) so the build/start commands and
`rootDir: backend` are applied. A service created manually with Render's
defaults runs `yarn` / `npm start` at the repo root and fails with
`ENOENT … /opt/render/project/src/package.json`.

| Setting | Value |
|---|---|
| Type / runtime | Web Service / Node |
| Root directory | `backend` |
| Build command | `npm ci --include=dev && npx prisma generate && npm run build` |
| Start command | `node dist/main` |
| Health check | `/health` |
| Node | 22 (`NODE_VERSION` in the blueprint / dashboard) |
| Instances | 1 (in-memory rate limiter) |
| Persistent disk | none (uploads are in-memory) |

There is no `preDeployCommand` and `autoDeploy` is off, so a push never runs
migrations against the database. Deploy from the dashboard after applying schema
changes (§3).

## 6. Environment variables to set in the dashboard

Required for boot:

`DATABASE_URL`, `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`,
`JWT_ADMIN_ACCESS_SECRET`, `JWT_ADMIN_REFRESH_SECRET`, `ACCOUNT_HASH_SECRET`,
`ALLOWED_ORIGINS`, `APP_URL`, `QR_PUBLIC_BASE_URL`, `EMAIL_FROM`,
`CHECK_ET_API_KEY`, and `BREVO_API_KEY` (or `SMTP_HOST`, plus `SMTP_USER` /
`SMTP_PASS` when the relay authenticates).

- `DATABASE_URL` is the only database connection variable. Keep the database
  name `postgres` and use the Supabase shared session pooler.
- `JWT_ADMIN_ACCESS_SECRET` and `JWT_ADMIN_REFRESH_SECRET` must be distinct.
- `APP_URL` and `QR_PUBLIC_BASE_URL` must be the **public HTTPS URL of this
  service** (`https://<service>.onrender.com`), not a localhost address. They
  are embedded in staff-invitation links and payment QR codes.
- `ALLOWED_ORIGINS` must include every browser client origin (admin panel,
  custom domain) and the service URL itself.

Provided by the blueprint: `NODE_ENV`, `NODE_VERSION`, `CHECK_ET_BASE_URL`,
`CHECK_ET_TIMEOUT_MS`, `BREVO_SMS_SENDER`.

Optional: `ALLOW_CREDENTIALS`, `SMTP_*`, `DATABASE_SSL_*`, `THROTTLE_TTL_MS`,
`THROTTLE_LIMIT`, `PAYMENT_VERIFY_RATE_LIMIT`, `PAYMENT_VERIFY_IMAGE_RATE_LIMIT`,
`QR_RESOLVE_RATE_LIMIT`.

Secrets must be ≥ 32 characters; `APP_URL`, `QR_PUBLIC_BASE_URL` and
`CHECK_ET_BASE_URL` must be `https://`. Boot fails with a list of the missing
names, never with a secret value.

## 7. Verify after deploy

```bash
curl -sS https://<service>.onrender.com/health
# 200 {"status":"ok","database":"up","uptime":N}
```

`503 {"status":"error","database":"down"}` means the service is up but cannot
reach the database — re-check §1 and the Render logs.

After `/health` returns 200, build the release APK with that origin:

```bash
flutter build apk --release \
  --dart-define=APP_ENV=prod \
  --dart-define=API_BASE_URL=https://<service>.onrender.com
```

-- QR staff invitations: username login + invitation lifecycle statuses.
-- Preserves all existing users, branches, staff assignments, and transactions.

-- 1) Username for staff login. Backfill from email prefix (owners keep email
--    login; username is additive). Collisions are de-duplicated with a
--    deterministic suffix derived from the user id.
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "username" TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS "users_username_key" ON "users"("username");

WITH candidates AS (
  SELECT
    id,
    "createdAt",
    lower(split_part(email, '@', 1)) AS base
  FROM "users"
  WHERE email IS NOT NULL
),
deduped AS (
  SELECT
    id,
    CASE
      WHEN base IS NULL THEN NULL
      WHEN ROW_NUMBER() OVER (PARTITION BY base ORDER BY "createdAt") = 1
        THEN base
      ELSE base || '.' || substr(id, 1, 8)
    END AS username
  FROM candidates
)
UPDATE "users" u
SET "username" = d.username
FROM deduped d
WHERE u.id = d.id AND d.username IS NOT NULL;

-- 2) Invitation lifecycle columns.
ALTER TABLE "invitations" ADD COLUMN IF NOT EXISTS "fullName" TEXT;
ALTER TABLE "invitations" ADD COLUMN IF NOT EXISTS "username" TEXT;
ALTER TABLE "invitations" ADD COLUMN IF NOT EXISTS "usedAt" TIMESTAMPTZ(3);
ALTER TABLE "invitations" ADD COLUMN IF NOT EXISTS "revokedAt" TIMESTAMPTZ(3);

-- 3) Backfill fullName/username on invitations from the legacy email/phone
--    contact where possible (email prefix is the best guess; phone keeps
--    phone as username-equivalent identifier absent other data).
UPDATE "invitations"
SET "fullName" = initcap(split_part(email, '@', 1)),
    "username" = lower(split_part(email, '@', 1))
WHERE "fullName" IS NULL AND email IS NOT NULL;

UPDATE "invitations"
SET "fullName" = 'Staff ' || right(phone, 4),
    "username" = phone
WHERE "fullName" IS NULL AND phone IS NOT NULL;

-- 4) Migrate legacy statuses: consumed invitations → ACTIVATED, stale
--    pending ones → EXPIRED. (Legacy rows never had usedAt; treat invitations
--    whose token was already used — historically deleted — as absent.)
UPDATE "invitations"
SET "status" = 'EXPIRED'
WHERE "status" = 'PENDING' AND "expiresAt" <= now();

CREATE INDEX IF NOT EXISTS "invitations_organization_status_idx"
  ON "invitations"("organizationId", "status");

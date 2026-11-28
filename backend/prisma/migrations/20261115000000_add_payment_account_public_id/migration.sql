-- Add a stable, opaque public identifier used by payment-account QR codes.
--
-- Design notes:
--   * The column is added as NULLABLE first, backfilled for every existing
--     account, then made NOT NULL, so the migration is safe for databases
--     that already contain payment accounts.
--   * Existing account numbers are never read or modified here.
--   * Values are 24 lowercase hex characters (96 bits of randomness from
--     gen_random_uuid()), carrying no information about the account number.
--   * The identifier is immutable: no application code path rewrites it.

ALTER TABLE "payment_accounts" ADD COLUMN IF NOT EXISTS "publicId" TEXT;

UPDATE "payment_accounts"
SET "publicId" = substr(replace(gen_random_uuid()::text, '-', ''), 1, 24)
WHERE "publicId" IS NULL;

ALTER TABLE "payment_accounts" ALTER COLUMN "publicId" SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS "payment_accounts_publicId_key"
  ON "payment_accounts" ("publicId");

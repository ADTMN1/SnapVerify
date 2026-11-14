-- Stage 1: database-level duplicate protection + account-number hash column.
--
-- SAFETY: this migration never deletes or merges rows. The backfill computes
-- normalized references; the unique index is created in a SEPARATE statement
-- so that, if historical duplicates exist after normalization, deployment
-- aborts loudly on that statement with the offending values, and nothing is
-- lost. Before running this migration, run scripts/check-normalized-duplicates.ts
-- (read-only) to see duplicates in advance.
--
-- NORMALIZATION (final review): mirrors src/payment/reference-normalizer.ts
-- EXACTLY — leading/trailing whitespace trim ONLY. Letter case, internal
-- whitespace and separators are PRESERVED because Leul.et has never
-- documented their insignificance; assuming it would merge distinct
-- transactions (e.g. "ft123" vs "FT123", "FT 123" vs "FT123", "AB-C" vs
-- "A-BC"). If the provider later confirms case/whitespace insensitivity,
-- relax BOTH this SQL and the TypeScript normalizer together, then re-run
-- the preflight script.

-- 1. New columns.
ALTER TABLE "payments" ADD COLUMN "normalizedTransactionId" TEXT;
ALTER TABLE "payment_accounts" ADD COLUMN "accountNumberHash" TEXT;

-- 2. Backfill normalized references: trim leading/trailing whitespace only.
--    Mirrors String.prototype.trim() for spaces, tabs and newlines.
--    Empty results stay NULL; NULLs are exempt from the unique index.
UPDATE "payments"
SET "normalizedTransactionId" = NULLIF(
      REGEXP_REPLACE(REGEXP_REPLACE("transactionId", '^\s+', ''), '\s+$', ''),
      '');

-- 3. accountNumberHash is backfilled by scripts/backfill-account-hashes.ts,
--    NOT here: it is a keyed HMAC-SHA-256 (env ACCOUNT_HASH_SECRET) and the
--    secret must never be embedded in a migration file or database history.

-- 4. Unique constraint for duplicate protection.
--    FAILS VISIBLY if the backfill above produced duplicate
--    (organizationId, normalizedTransactionId) pairs.
CREATE UNIQUE INDEX "payments_organizationId_normalizedTransactionId_key"
  ON "payments"("organizationId", "normalizedTransactionId");

-- Add organizationId and role to refresh_tokens for correct multi-org token refresh
-- Existing tokens are invalidated by backfilling empty strings; they will be
-- rejected at runtime because no matching user assignment will be found.

ALTER TABLE "refresh_tokens" ADD COLUMN "organizationId" TEXT NOT NULL DEFAULT '';
ALTER TABLE "refresh_tokens" ADD COLUMN "role" TEXT NOT NULL DEFAULT '';

-- Remove the temporary defaults so future inserts must supply explicit values
ALTER TABLE "refresh_tokens" ALTER COLUMN "organizationId" DROP DEFAULT;
ALTER TABLE "refresh_tokens" ALTER COLUMN "role" DROP DEFAULT;

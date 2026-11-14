-- Add token and expiresAt to invitations table with defaults for existing rows
-- Then alter columns to drop defaults (to match schema.prisma)
-- Also add unique index on token

-- 1. Add columns with defaults for existing data
ALTER TABLE invitations
  ADD COLUMN "token" TEXT NOT NULL DEFAULT (md5(random()::text || clock_timestamp()::text) || md5(random()::text || clock_timestamp()::text));

ALTER TABLE invitations
  ADD COLUMN "expiresAt" TIMESTAMP(3) NOT NULL DEFAULT (NOW() + INTERVAL '7 days');

-- 2. Now add the unique index on token
CREATE UNIQUE INDEX "invitations_token_key" ON invitations("token");

-- 3. Drop the defaults to match Prisma schema (columns are required, no DB default)
ALTER TABLE invitations
  ALTER COLUMN "token" DROP DEFAULT,
  ALTER COLUMN "expiresAt" DROP DEFAULT;

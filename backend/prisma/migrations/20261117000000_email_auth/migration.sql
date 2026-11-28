-- Email-based authentication migration.
-- Preserves all existing users / businesses / payments: phone becomes optional,
-- email gains a unique index, and email OTP storage is introduced.

-- Users: phone optional, email unique, track email verification
ALTER TABLE "users" ALTER COLUMN "phone" DROP NOT NULL;
ALTER TABLE "users" ADD COLUMN "emailVerified" BOOLEAN NOT NULL DEFAULT false;

-- Emails may already exist (nullable column): dedupe before enforcing uniqueness.
-- Keep the lowest id per email as the surviving row.
UPDATE "users" u
SET "email" = NULL
FROM (
  SELECT "email", MIN("id") AS keep_id
  FROM "users"
  WHERE "email" IS NOT NULL
  GROUP BY "email"
  HAVING COUNT(*) > 1
) d
WHERE u."email" = d."email" AND u."id" <> d.keep_id;

CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- Invitations: phone optional (legacy SMS invitations), email for new flows
ALTER TABLE "invitations" ALTER COLUMN "phone" DROP NOT NULL;
ALTER TABLE "invitations" ADD COLUMN "email" TEXT;

-- Email OTP codes (hashed, expiring, single-use)
CREATE TABLE "email_otps" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "purpose" TEXT NOT NULL,
    "otpHash" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "consumedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "email_otps_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "email_otps_email_purpose_idx" ON "email_otps"("email", "purpose");

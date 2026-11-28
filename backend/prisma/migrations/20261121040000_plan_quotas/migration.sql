ALTER TABLE "subscriptions" ADD COLUMN "verificationLimit" INTEGER;

UPDATE "subscriptions"
SET "verificationLimit" = CASE lower("planName")
  WHEN 'free' THEN 20
  WHEN 'free_trial' THEN 20
  WHEN 'starter' THEN 300
  WHEN 'business' THEN 1000
  ELSE NULL
END;

CREATE TABLE "subscription_usage" (
  "id" TEXT NOT NULL,
  "subscriptionId" TEXT NOT NULL,
  "periodStart" TIMESTAMP(3) NOT NULL,
  "count" INTEGER NOT NULL DEFAULT 0,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "subscription_usage_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "subscription_usage_subscriptionId_periodStart_key"
  ON "subscription_usage"("subscriptionId", "periodStart");

ALTER TABLE "subscription_usage"
  ADD CONSTRAINT "subscription_usage_subscriptionId_fkey"
  FOREIGN KEY ("subscriptionId") REFERENCES "subscriptions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "subscription_plans" ADD COLUMN "durationMonths" INTEGER;
ALTER TABLE "subscription_plans" ADD COLUMN "isLifetime" BOOLEAN NOT NULL DEFAULT false;

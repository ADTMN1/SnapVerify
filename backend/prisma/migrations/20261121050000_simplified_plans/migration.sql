UPDATE "subscriptions"
SET "verificationLimit" = CASE
    WHEN lower("planName") IN ('free', 'free_trial') THEN 20
    ELSE NULL
  END,
  "endDate" = CASE
    WHEN lower("planName") IN ('free', 'free_trial') THEN NULL
    ELSE "endDate"
  END;

DELETE FROM "subscription_usage" u
USING "subscriptions" s
WHERE u."subscriptionId" = s.id
  AND s."verificationLimit" IS NULL;

UPDATE "subscription_usage" u
SET "periodStart" = s."startDate"
FROM "subscriptions" s
WHERE u."subscriptionId" = s.id
  AND u."periodStart" <> s."startDate";

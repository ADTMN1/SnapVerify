INSERT INTO "platform_payment_accounts" (
  "id",
  "provider",
  "accountNumber",
  "accountHolderName",
  "isActive",
  "updatedAt"
)
VALUES (
  'platform-subscription-telebirr',
  'TELEBIRR',
  '0986006897',
  'natnael abebaw',
  true,
  NOW()
)
ON CONFLICT ("provider") DO UPDATE
SET
  "accountNumber" = EXCLUDED."accountNumber",
  "accountHolderName" = EXCLUDED."accountHolderName",
  "isActive" = true,
  "updatedAt" = NOW();

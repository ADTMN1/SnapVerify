UPDATE "platform_payment_accounts"
SET "accountHolderName" = 'abebaw', "updatedAt" = NOW()
WHERE "provider" = 'TELEBIRR' AND "id" = 'platform-subscription-telebirr';

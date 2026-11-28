UPDATE "payments"
SET "normalizedTransactionId" = NULL
WHERE "status" <> 'VERIFIED'
  AND "normalizedTransactionId" IS NOT NULL;

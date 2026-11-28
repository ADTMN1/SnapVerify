ALTER TABLE "payments" ADD COLUMN "paymentDate" TIMESTAMP(3);

UPDATE "payments"
SET "paymentDate" = ("rawData"->>'transactionDate')::timestamp
WHERE "rawData" ? 'transactionDate'
  AND "rawData"->>'transactionDate' ~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}';

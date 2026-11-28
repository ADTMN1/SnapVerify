-- Add column recording which verification vendor produced each payment row.
-- Non-destructive: existing rows keep verificationProvider = NULL, meaning
-- they were created by the legacy Veritas integration. No data is rewritten,
-- no tables are truncated, no IDs are reset.
ALTER TABLE "payments" ADD COLUMN "verificationProvider" TEXT;

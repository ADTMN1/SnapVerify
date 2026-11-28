-- Add per-user notification read watermark.
ALTER TABLE "users" ADD COLUMN "notificationsReadAt" TIMESTAMP(3);

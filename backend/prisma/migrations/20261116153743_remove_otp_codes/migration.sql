/*
  Warnings:

  - You are about to drop the `otp_codes` table. If the table is not empty, all the data it contains will be lost.

*/
-- DropTable
DROP TABLE "otp_codes";

-- CreateIndex
CREATE INDEX "payments_organizationId_createdAt_idx" ON "payments"("organizationId", "createdAt");

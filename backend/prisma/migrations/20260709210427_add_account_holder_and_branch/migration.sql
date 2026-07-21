/*
  Warnings:

  - You are about to drop the column `paymentAccountId` on the `payments` table. All the data in the column will be lost.
  - A unique constraint covering the columns `[organizationId,provider,branchId]` on the table `payment_accounts` will be added. If there are existing duplicate values, this will fail.

*/
-- DropForeignKey
ALTER TABLE "payments" DROP CONSTRAINT "payments_paymentAccountId_fkey";

-- DropIndex
DROP INDEX "payment_accounts_organizationId_provider_key";

-- AlterTable
ALTER TABLE "payment_accounts" ADD COLUMN     "accountHolderName" TEXT,
ADD COLUMN     "branchId" TEXT;

-- AlterTable
ALTER TABLE "payments" DROP COLUMN "paymentAccountId";

-- AlterTable
ALTER TABLE "verification_logs" ADD COLUMN     "matchedAccountNumber" TEXT,
ADD COLUMN     "matchedBranchId" TEXT,
ADD COLUMN     "matchedPaymentAccountId" TEXT,
ADD COLUMN     "matchedProvider" "PaymentProvider",
ADD COLUMN     "matchedSuffix" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "payment_accounts_organizationId_provider_branchId_key" ON "payment_accounts"("organizationId", "provider", "branchId");

-- AddForeignKey
ALTER TABLE "payment_accounts" ADD CONSTRAINT "payment_accounts_branchId_fkey" FOREIGN KEY ("branchId") REFERENCES "branches"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "verification_logs" ADD CONSTRAINT "verification_logs_matchedPaymentAccountId_fkey" FOREIGN KEY ("matchedPaymentAccountId") REFERENCES "payment_accounts"("id") ON DELETE SET NULL ON UPDATE CASCADE;

/*
  Warnings:

  - You are about to drop the column `code` on the `otp_codes` table. All the data in the column will be lost.
  - Added the required column `otpHash` to the `otp_codes` table without a default value. This is not possible if the table is not empty.

*/
-- Clear old OTP data (no longer valid)
DELETE FROM "otp_codes";

-- AlterTable
ALTER TABLE "otp_codes" DROP COLUMN "code",
ADD COLUMN     "attempts" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "otpHash" TEXT NOT NULL;

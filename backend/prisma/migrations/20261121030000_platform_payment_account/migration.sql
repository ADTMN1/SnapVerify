CREATE TABLE "platform_payment_accounts" (
    "id" TEXT NOT NULL,
    "provider" "PaymentProvider" NOT NULL,
    "accountNumber" TEXT NOT NULL,
    "accountHolderName" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "platform_payment_accounts_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "platform_payment_accounts_provider_key" ON "platform_payment_accounts"("provider");

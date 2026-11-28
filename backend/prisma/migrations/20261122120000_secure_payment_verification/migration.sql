CREATE TABLE "payment_receipt_usages" (
    "id" TEXT NOT NULL,
    "provider" "PaymentProvider" NOT NULL,
    "normalizedReference" TEXT NOT NULL,
    "source" TEXT NOT NULL,
    "organizationId" TEXT,
    "checkoutId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "payment_receipt_usages_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "payment_receipt_usages_provider_normalizedReference_key"
    ON "payment_receipt_usages"("provider", "normalizedReference");

CREATE UNIQUE INDEX "subscription_checkouts_vendorReference_key"
    ON "subscription_checkouts"("vendorReference");

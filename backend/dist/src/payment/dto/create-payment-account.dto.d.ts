import { PaymentProvider } from '@prisma/client';
export declare class CreatePaymentAccountDto {
    provider: PaymentProvider;
    accountNumber?: string;
    suffix?: string;
    accountHolderName?: string;
    branchId?: string;
}

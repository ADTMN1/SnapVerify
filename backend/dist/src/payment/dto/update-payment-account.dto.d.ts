import { PaymentProvider } from '@prisma/client';
export declare class UpdatePaymentAccountDto {
    provider?: PaymentProvider;
    accountNumber?: string;
    suffix?: string;
    accountHolderName?: string;
    branchId?: string;
    isActive?: boolean;
}

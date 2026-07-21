import { PaymentAccountService } from './payment-account.service';
import { CreatePaymentAccountDto } from './dto/create-payment-account.dto';
import { UpdatePaymentAccountDto } from './dto/update-payment-account.dto';
export declare class PaymentAccountController {
    private paymentAccountService;
    constructor(paymentAccountService: PaymentAccountService);
    create(dto: CreatePaymentAccountDto, req: any): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        organizationId: string;
        branchId: string | null;
        provider: import("@prisma/client").$Enums.PaymentProvider;
        accountNumber: string | null;
        suffix: string | null;
        accountHolderName: string | null;
        isActive: boolean;
    }>;
    findAll(req: any, branchId?: string): Promise<({
        branch: {
            phone: string | null;
            id: string;
            createdAt: Date;
            name: string;
            updatedAt: Date;
            organizationId: string;
            address: string | null;
            latitude: import("@prisma/client-runtime-utils").Decimal | null;
            longitude: import("@prisma/client-runtime-utils").Decimal | null;
        } | null;
    } & {
        id: string;
        createdAt: Date;
        updatedAt: Date;
        organizationId: string;
        branchId: string | null;
        provider: import("@prisma/client").$Enums.PaymentProvider;
        accountNumber: string | null;
        suffix: string | null;
        accountHolderName: string | null;
        isActive: boolean;
    })[]>;
    findOne(provider: string, req: any, branchId?: string): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        organizationId: string;
        branchId: string | null;
        provider: import("@prisma/client").$Enums.PaymentProvider;
        accountNumber: string | null;
        suffix: string | null;
        accountHolderName: string | null;
        isActive: boolean;
    }>;
    update(provider: string, dto: UpdatePaymentAccountDto, req: any, branchId?: string): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        organizationId: string;
        branchId: string | null;
        provider: import("@prisma/client").$Enums.PaymentProvider;
        accountNumber: string | null;
        suffix: string | null;
        accountHolderName: string | null;
        isActive: boolean;
    }>;
    remove(provider: string, req: any, branchId?: string): Promise<{
        message: string;
    }>;
}
